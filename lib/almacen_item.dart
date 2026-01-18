// lib/almacen_item.dart
class AlmacenItem {
  String id;
  String nombre;
  int stock;
  String notas;

  /// ✅ Umbral por item (si stock <= minStock => BAJO)
  int minStock;

  /// ✅ Para stats/futuro
  String createdAtIso;

  AlmacenItem({
    required this.id,
    required this.nombre,
    this.stock = 0,
    this.notas = '',
    this.minStock = 5,
    String? createdAtIso,
  }) : createdAtIso = createdAtIso ?? DateTime.now().toIso8601String();

  bool get isLow => stock <= minStock;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'stock': stock,
        'notas': notas,
        'minStock': minStock,
        'createdAtIso': createdAtIso,
      };

  factory AlmacenItem.fromJson(Map<String, dynamic> json) => AlmacenItem(
        id: (json['id'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        stock: _parseInt(json['stock'], fallback: 0),
        notas: (json['notas'] ?? '').toString(),
        minStock: _parseInt(json['minStock'], fallback: 5),
        createdAtIso: (json['createdAtIso'] ?? '').toString().trim().isEmpty
            ? DateTime.now().toIso8601String()
            : (json['createdAtIso'] ?? '').toString(),
      );

  static int _parseInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse((v ?? '').toString()) ?? fallback;
  }
}