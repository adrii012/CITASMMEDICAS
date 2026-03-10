/**
 * Cloud Functions programadas:
 * - Revisa citas de las próximas 24h
 * - Envía WhatsApp por Twilio
 * - Envía push notification por FCM
 * - Marca la cita como reminderSent24h=true
 * - Recibe respuestas de WhatsApp: 1 confirmar / 2 reagendar / 3 cancelar
 */

const {setGlobalOptions} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const twilio = require("twilio");

setGlobalOptions({maxInstances: 10});

admin.initializeApp();
const db = admin.firestore();

// Secrets para Twilio
const TWILIO_ACCOUNT_SID = defineSecret("TWILIO_ACCOUNT_SID");
const TWILIO_AUTH_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const TWILIO_WHATSAPP_FROM = defineSecret("TWILIO_WHATSAPP_FROM");

// Tu plantilla Quick Reply aprobada en Twilio
const QUICK_REPLY_CONTENT_SID = "HXc1f223458dc87e47dac60ee468f46660";

/**
 * Normaliza teléfonos mexicanos para comparar bien:
 * - 8443188668
 * - 528443188668
 * - 5218443188668
 * - +52 1 8443188668
 * Todos terminan como: 528443188668
 * @param {string} raw
 * @return {string|null}
 */
function normalizePhone(raw) {
  let digits = String(raw || "").replace(/\D/g, "").trim();
  if (!digits) return null;

  if (digits.startsWith("00")) {
    digits = digits.slice(2);
  }

  // Twilio/WhatsApp a veces manda 521 + número móvil MX
  if (digits.startsWith("521") && digits.length === 13) {
    digits = `52${digits.slice(3)}`;
  }

  // Si viene en nacional MX (10 dígitos)
  if (digits.length === 10) {
    digits = `52${digits}`;
  }

  // Si vino como 52 + 10 dígitos queda en 12
  if (digits.length < 12) return null;

  return digits;
}

/**
 * Formatea una fecha en español de México.
 * @param {Date} date
 * @return {string}
 */
function formatDateEsMx(date) {
  return new Intl.DateTimeFormat("es-MX", {
    timeZone: "America/Mexico_City",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);
}

/**
 * Formatea una hora en español de México.
 * @param {Date} date
 * @return {string}
 */
function formatTimeEsMx(date) {
  return new Intl.DateTimeFormat("es-MX", {
    timeZone: "America/Mexico_City",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  }).format(date);
}

/**
 * Genera un código corto para la cita.
 * @param {string} docId
 * @return {string}
 */
function buildAppointmentCode(docId) {
  return String(docId || "")
      .replace(/[^a-zA-Z0-9]/g, "")
      .toUpperCase()
      .slice(-6);
}

/**
 * Obtiene o crea el código de cita.
 * @param {FirebaseFirestore.QueryDocumentSnapshot} apptDoc
 * @param {Object} appt
 * @return {Promise<string>}
 */
async function ensureAppointmentCode(apptDoc, appt) {
  let appointmentCode = String(appt.appointmentCode || "")
      .trim()
      .toUpperCase();

  if (!appointmentCode) {
    appointmentCode = buildAppointmentCode(apptDoc.id);
    await apptDoc.ref.update({
      appointmentCode,
    });
  }

  return appointmentCode;
}

/**
 * Obtiene el teléfono crudo de una cita.
 * Soporta appointments y citas.
 * @param {Object} appt
 * @return {string}
 */
function getPhoneFromAppt(appt) {
  return String(
      appt.phone ||
      appt.telefono ||
      "",
  );
}

/**
 * Obtiene el nombre del paciente.
 * Soporta appointments y citas.
 * @param {Object} appt
 * @return {string}
 */
function getPatientNameFromAppt(appt) {
  return String(
      appt.patientName ||
      appt.paciente ||
      "Paciente",
  );
}

/**
 * Obtiene el status/estado de la cita.
 * Soporta appointments y citas.
 * @param {Object} appt
 * @return {string}
 */
function getStatusFromAppt(appt) {
  return String(
      appt.status ||
      appt.estado ||
      "",
  ).trim().toLowerCase();
}

/**
 * Obtiene la fecha/hora de inicio.
 * Soporta startAt y fechaHora.
 * @param {Object} appt
 * @return {Date|null}
 */
function getStartAtFromAppt(appt) {
  if (
    appt.startAt &&
    typeof appt.startAt.toDate === "function"
  ) {
    return appt.startAt.toDate();
  }

  if (
    appt.fechaHora &&
    typeof appt.fechaHora.toDate === "function"
  ) {
    return appt.fechaHora.toDate();
  }

  return null;
}

exports.send24hReminders = onSchedule(
    {
      schedule: "every 60 minutes",
      timeZone: "America/Mexico_City",
      secrets: [
        TWILIO_ACCOUNT_SID,
        TWILIO_AUTH_TOKEN,
        TWILIO_WHATSAPP_FROM,
      ],
    },
    async () => {
      const now = new Date();
      const from = new Date(now.getTime() + 23 * 60 * 60 * 1000);
      const to = new Date(now.getTime() + 25 * 60 * 60 * 1000);

      logger.info("Buscando citas para recordar", {
        from: from.toISOString(),
        to: to.toISOString(),
      });

      const twilioClient = twilio(
          TWILIO_ACCOUNT_SID.value(),
          TWILIO_AUTH_TOKEN.value(),
      );
      const waFrom = TWILIO_WHATSAPP_FROM.value();

      const clinicsSnap = await db.collection("clinics").get();

      for (const clinicDoc of clinicsSnap.docs) {
        const clinicId = clinicDoc.id;
        const clinicData = clinicDoc.data() || {};
        const clinicName = String(clinicData.name || "Clínica");

        const doctorName = String(
            clinicData.doctorName || "Doctor",
        );

        const clinicAddress = String(
            clinicData.address || "Av. Principal 123, Col. Centro",
        );

        const clinicReference = String(
            clinicData.references ||
            clinicData.reference ||
            clinicData.referencia ||
            clinicData.locationReference ||
            "Sin referencia",
        );

        const doctorPhone = String(
            clinicData.doctorPhone || "+52 5551234567",
        );

        const mapsLink = String(
            clinicData.mapsLinks ||
            clinicData.mapsLink ||
            "https://maps.google.com/?q=Av+Principal+123+Col.+Centro",
        );

        let appointmentsSnap = await db
            .collection("clinics")
            .doc(clinicId)
            .collection("appointments")
            .where(
                "startAt",
                ">=",
                admin.firestore.Timestamp.fromDate(from),
            )
            .where(
                "startAt",
                "<",
                admin.firestore.Timestamp.fromDate(to),
            )
            .where("status", "==", "pendiente")
            .where("reminderSent24h", "==", false)
            .get();

        if (appointmentsSnap.empty) {
          appointmentsSnap = await db
              .collection("clinics")
              .doc(clinicId)
              .collection("citas")
              .where(
                  "fechaHora",
                  ">=",
                  admin.firestore.Timestamp.fromDate(from),
              )
              .where(
                  "fechaHora",
                  "<",
                  admin.firestore.Timestamp.fromDate(to),
              )
              .get();
        }

        if (appointmentsSnap.empty) continue;

        const usersSnap = await db
            .collection("clinics")
            .doc(clinicId)
            .collection("users")
            .get();

        const allTokens = [];
        for (const userDoc of usersSnap.docs) {
          const userData = userDoc.data() || {};
          if (Array.isArray(userData.fcmTokens)) {
            for (const token of userData.fcmTokens) {
              if (
                typeof token === "string" &&
                token.trim()
              ) {
                allTokens.push(token.trim());
              }
            }
          }
        }

        const uniqueTokens = [...new Set(allTokens)];

        for (const apptDoc of appointmentsSnap.docs) {
          const appt = apptDoc.data() || {};
          const startAt = getStartAtFromAppt(appt);

          if (!startAt) continue;

          const status = getStatusFromAppt(appt);
          const reminderSent24h =
            appt.reminderSent24h === true;

          if (status && status !== "pendiente") continue;
          if (reminderSent24h) continue;

          const appointmentCode =
            await ensureAppointmentCode(apptDoc, appt);

          const patientName =
            getPatientNameFromAppt(appt);

          const rawPhone =
            getPhoneFromAppt(appt);

          const phone =
            normalizePhone(rawPhone);

          if (!phone) continue;

          const fecha =
            formatDateEsMx(startAt);

          const hora =
            formatTimeEsMx(startAt);

          const waBody =
            `Hola ${patientName} 👋\n\n` +
            `Te recordamos tu cita médica.\n\n` +
            `📅 Fecha: ${fecha}\n` +
            `🕒 Hora: ${hora}\n` +
            `🏥 Clínica: ${clinicName}\n` +
            `👨‍⚕️ Doctor: ${doctorName}\n\n` +
            `🆔 Código de cita: ${appointmentCode}\n\n` +
            `📍 Ubicación del consultorio:\n` +
            `${clinicAddress}\n\n` +
            `📌 Referencia:\n` +
            `${clinicReference}\n\n` +
            `🗺 Ver ubicación en Google Maps:\n` +
            `${mapsLink}\n\n` +
            `📞 Contacto del doctor:\n` +
            `${doctorPhone}\n\n` +
            `Responde con una opción:\n` +
            `1 = Confirmar cita\n` +
            `2 = Reagendar cita\n` +
            `3 = Cancelar cita\n\n` +
            `Si tienes más de una cita, responde con tu código:\n` +
            `1 ${appointmentCode}\n` +
            `2 ${appointmentCode}\n` +
            `3 ${appointmentCode}`;

          const waLocationBody =
            `📍 Ubicación de tu cita\n\n` +
            `🏥 ${clinicName}\n` +
            `👨‍⚕️ ${doctorName}\n\n` +
            `📍 Dirección:\n${clinicAddress}\n\n` +
            `📌 Referencia:\n${clinicReference}\n\n` +
            `🗺️ Google Maps:\n${mapsLink}\n\n` +
            `📞 Doctor:\n${doctorPhone}\n\n` +
            `🆔 Código de cita: ${appointmentCode}`;

          let whatsappSent = false;
          let pushSent = false;

          try {
            if (phone) {
              await twilioClient.messages.create({
                from: waFrom,
                to: `whatsapp:+${phone}`,
                contentSid: QUICK_REPLY_CONTENT_SID,
                contentVariables: JSON.stringify({
                  "1": patientName,
                  "2": fecha,
                  "3": hora,
                  "4": clinicName,
                  "5": clinicAddress,
                  "6": clinicReference,
                  "7": doctorPhone,
                }),
              });

              await twilioClient.messages.create({
                from: waFrom,
                to: `whatsapp:+${phone}`,
                body: waLocationBody,
              });

              whatsappSent = true;
            }
          } catch (e) {
            logger.error("Error enviando WhatsApp", {
              clinicId,
              appointmentId: apptDoc.id,
              error: String(e),
              fallbackBody: waBody,
            });
          }

          try {
            if (uniqueTokens.length > 0) {
              const resp =
                await admin
                    .messaging()
                    .sendEachForMulticast({
                      tokens: uniqueTokens.slice(0, 500),
                      notification: {
                        title: "Recordatorio de cita",
                        body:
                          `${patientName} mañana ` +
                          `a las ${hora}`,
                      },
                      data: {
                        clinicId,
                        appointmentId: apptDoc.id,
                        appointmentCode,
                        type: "appointment_reminder_24h",
                      },
                    });

              pushSent = resp.successCount > 0;
            }
          } catch (e) {
            logger.error("Error enviando push", {
              clinicId,
              appointmentId: apptDoc.id,
              error: String(e),
            });
          }

          await apptDoc.ref.update({
            reminderSent24h: true,
            reminderSent24hAt:
              admin.firestore.FieldValue.serverTimestamp(),
            reminderSent24hWhatsApp: whatsappSent,
            reminderSent24hPush: pushSent,
            appointmentCode,
          });
        }
      }

      logger.info("Proceso de recordatorios 24h terminado");
    },
);

/**
 * Recibe respuestas entrantes de WhatsApp desde Twilio.
 * Soporta:
 * 1
 * 2
 * 3
 * CONFIRMAR
 * REAGENDAR
 * CANCELAR
 * 1 CODIGO
 * 2 CODIGO
 * 3 CODIGO
 */
exports.whatsappReply = onRequest(async (req, res) => {
  try {
    const incomingBody =
      String(req.body.Body || "").trim();

    const from =
      String(req.body.From || "").trim();

    const phoneDigits =
      normalizePhone(
          from.replace("whatsapp:", ""),
      );

    logger.info("DEBUG incoming whatsapp", {
      from,
      incomingBody,
      phoneDigits,
      buttonPayload: req.body.ButtonPayload || "",
      buttonText: req.body.ButtonText || "",
    });

    let responseText = "";

    if (!phoneDigits) {
      responseText =
        "No se pudo identificar tu número. Intenta nuevamente.";

      res.set("Content-Type", "text/xml");
      res.status(200).send(`
<Response>
  <Message>${responseText}</Message>
</Response>`);
      return;
    }

    const rawAction =
      String(
          req.body.ButtonPayload ||
          req.body.ButtonText ||
          incomingBody,
      ).trim();

    const bodyNormalized = rawAction
        .replace(/\s+/g, " ")
        .trim()
        .toUpperCase();

    const parts = bodyNormalized.split(" ");
    const action = parts[0] || "";
    const codeFromMessage = parts[1] || "";

    const now = new Date();
    const next2Days =
      new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);

    const clinicsSnap =
      await db.collection("clinics").get();

    let foundAppointmentRef = null;
    let foundAppointmentData = null;
    let foundClinicId = null;
    let foundClinicName = "Clínica";

    for (const clinicDoc of clinicsSnap.docs) {
      const clinicId = clinicDoc.id;
      const clinicData = clinicDoc.data() || {};
      const clinicName = String(clinicData.name || "Clínica");

      let appointmentsSnap = await db
          .collection("clinics")
          .doc(clinicId)
          .collection("appointments")
          .where(
              "startAt",
              ">=",
              admin.firestore.Timestamp.fromDate(now),
          )
          .where(
              "startAt",
              "<=",
              admin.firestore.Timestamp.fromDate(next2Days),
          )
          .get();

      if (appointmentsSnap.empty) {
        appointmentsSnap = await db
            .collection("clinics")
            .doc(clinicId)
            .collection("citas")
            .where(
                "fechaHora",
                ">=",
                admin.firestore.Timestamp.fromDate(now),
            )
            .where(
                "fechaHora",
                "<=",
                admin.firestore.Timestamp.fromDate(next2Days),
            )
            .get();
      }

      for (const apptDoc of appointmentsSnap.docs) {
        const appt = apptDoc.data() || {};
        const apptPhone =
          normalizePhone(getPhoneFromAppt(appt));

        const apptStatus =
          getStatusFromAppt(appt);

        const startAtDebug =
          getStartAtFromAppt(appt);

        logger.info("DEBUG comparing appointment", {
          appointmentId: apptDoc.id,
          rawPhone: getPhoneFromAppt(appt),
          apptPhone,
          phoneDigits,
          apptStatus,
          startAt: startAtDebug ?
            startAtDebug.toISOString() :
            null,
          clinicId,
        });

        const validStatus =
          apptStatus === "pendiente" ||
          apptStatus === "confirmada" ||
          apptStatus === "";

        if (
          !apptPhone ||
          apptPhone !== phoneDigits ||
          !validStatus
        ) {
          continue;
        }

        const appointmentCode =
          await ensureAppointmentCode(apptDoc, appt);

        logger.info("DEBUG candidate matched basic filters", {
          appointmentId: apptDoc.id,
          appointmentCode,
          codeFromMessage,
        });

        if (codeFromMessage) {
          if (appointmentCode === codeFromMessage) {
            foundAppointmentRef = apptDoc.ref;
            foundAppointmentData = {
              ...appt,
              appointmentCode,
            };
            foundClinicId = clinicId;
            foundClinicName = clinicName;
            break;
          }
        } else {
          foundAppointmentRef = apptDoc.ref;
          foundAppointmentData = {
            ...appt,
            appointmentCode,
          };
          foundClinicId = clinicId;
          foundClinicName = clinicName;
          break;
        }
      }

      if (foundAppointmentRef) break;
    }

    if (!foundAppointmentRef || !foundAppointmentData) {
      responseText =
        "No encontramos una cita pendiente asociada a este número.\n" +
        "Si necesitas ayuda, comunícate con la clínica.";

      res.set("Content-Type", "text/xml");
      res.status(200).send(`
<Response>
  <Message>${responseText}</Message>
</Response>`);
      return;
    }

    const startAt =
      getStartAtFromAppt(foundAppointmentData);

    const fecha =
      startAt ? formatDateEsMx(startAt) : "";

    const hora =
      startAt ? formatTimeEsMx(startAt) : "";

    const patientName =
      getPatientNameFromAppt(foundAppointmentData);

    const appointmentCode = String(
        foundAppointmentData.appointmentCode || "",
    ).toUpperCase();

    if (
      action === "1" ||
      action === "CONFIRMAR" ||
      action === "CONFIRMADA" ||
      action === "CONFIRMAR_CITA"
    ) {
      await foundAppointmentRef.update({
        status: "confirmada",
        estado: "confirmada",
        confirmedAt:
          admin.firestore.FieldValue.serverTimestamp(),
        confirmationChannel: "whatsapp",
        appointmentCode,
      });

      responseText =
        `✅ Hola ${patientName}, tu cita ha sido confirmada.\n\n` +
        `🆔 Código: ${appointmentCode}\n` +
        `📅 ${fecha}\n` +
        `🕒 ${hora}\n` +
        `🏥 ${foundClinicName}\n\n` +
        `Te esperamos.`;
    } else if (
      action === "2" ||
      action === "REAGENDAR" ||
      action === "REAGENDAR_CITA"
    ) {
      await foundAppointmentRef.update({
        status: "reagendar_solicitado",
        estado: "reagendar_solicitado",
        rescheduleRequestedAt:
          admin.firestore.FieldValue.serverTimestamp(),
        rescheduleChannel: "whatsapp",
        appointmentCode,
      });

      responseText =
        `📅 Hola ${patientName}, recibimos tu solicitud ` +
        `para reagendar tu cita.\n\n` +
        `🆔 Código: ${appointmentCode}\n` +
        `La clínica se pondrá en contacto contigo ` +
        `para darte una nueva fecha.`;
    } else if (
      action === "3" ||
      action === "CANCELAR" ||
      action === "CANCELAR_CITA"
    ) {
      await foundAppointmentRef.update({
        status: "cancelada",
        estado: "cancelada",
        canceledAt:
          admin.firestore.FieldValue.serverTimestamp(),
        canceledBy: "paciente_whatsapp",
        appointmentCode,
      });

      responseText =
        `❌ Hola ${patientName}, tu cita ha sido ` +
        `cancelada correctamente.\n\n` +
        `🆔 Código: ${appointmentCode}\n` +
        `Si deseas una nueva cita, puedes volver ` +
        `a agendar con la clínica.`;
    } else {
      responseText =
        `Por favor responde con una opción válida.\n\n` +
        `Opciones rápidas:\n` +
        `1 = Confirmar\n` +
        `2 = Reagendar\n` +
        `3 = Cancelar\n\n` +
        `También puedes usar los botones del mensaje.\n\n` +
        `Si tienes más de una cita, usa tu código:\n` +
        `1 ${appointmentCode}\n` +
        `2 ${appointmentCode}\n` +
        `3 ${appointmentCode}`;
    }

    logger.info("Respuesta procesada", {
      clinicId: foundClinicId,
      phone: phoneDigits,
      option: incomingBody,
      normalizedAction: action,
      appointmentCode,
    });

    res.set("Content-Type", "text/xml");
    res.status(200).send(`
<Response>
  <Message>${responseText}</Message>
</Response>`);
  } catch (e) {
    logger.error("Error en whatsappReply", {
      error: String(e),
    });

    const errorMsg =
      "Ocurrió un error procesando tu respuesta. " +
      "Intenta nuevamente.";

    res.set("Content-Type", "text/xml");
    res.status(200).send(`
<Response>
  <Message>${errorMsg}</Message>
</Response>`);
  }
});
