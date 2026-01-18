// lib/almacen_store.dart
import 'package:flutter/material.dart';
import 'almacen_item.dart';

class AlmacenStore {
  static final List<AlmacenItem> items = [];

  /// ✅ contador global (badge/botón)
  static final ValueNotifier<int> lowStockCount = ValueNotifier<int>(0);

  static void recomputeLowStock() {
    lowStockCount.value = items.where((x) => x.isLow).length;
  }

  static void clear() {
    items.clear();
    recomputeLowStock();
  }

  static AlmacenItem? porId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final it in items) {
      if (it.id == id) return it;
    }
    return null;
  }

  static void add(AlmacenItem item) {
    items.add(item);
    recomputeLowStock();
  }

  static void eliminar(String id) {
    items.removeWhere((x) => x.id == id);
    recomputeLowStock();
  }

  static void ajustarStock(String id, int delta) {
    final it = porId(id);
    if (it == null) return;
    final nuevo = it.stock + delta;
    it.stock = nuevo < 0 ? 0 : nuevo;
    recomputeLowStock();
  }

  /// ✅ si luego ocupas editar mínimo desde UI
  static void setMinStock(String id, int value) {
    final it = porId(id);
    if (it == null) return;
    it.minStock = value < 0 ? 0 : value;
    recomputeLowStock();
  }

  /// ✅ set stock directo
  static void setStock(String id, int value) {
    final it = porId(id);
    if (it == null) return;
    it.stock = value < 0 ? 0 : value;
    recomputeLowStock();
  }
}