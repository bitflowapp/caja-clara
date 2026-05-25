class Product {
  static const Object _sentinel = Object();

  const Product({
    required this.id,
    required this.name,
    required this.stockUnits,
    required this.minStockUnits,
    required this.costPesos,
    required this.pricePesos,
    this.category,
    this.barcode,
    this.imagePath,
    this.visualSignature,
    this.isFavorite = false,
    this.soldCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : _createdAt = createdAt,
       _updatedAt = updatedAt;

  final String id;
  final String name;
  final int stockUnits;
  final int minStockUnits;
  final int costPesos;
  final int pricePesos;
  final String? category;
  final String? barcode;
  final String? imagePath;
  final String? visualSignature;
  final bool isFavorite;
  final int soldCount;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  int get salePrice => pricePesos;
  DateTime get createdAt =>
      _createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get updatedAt =>
      _updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  bool get isLowStock => stockUnits <= minStockUnits;
  bool get hasPrice => pricePesos > 0;
  bool get hasBarcode => (barcode ?? '').trim().isNotEmpty;
  bool get needsCatalogAttention => !hasPrice || !hasBarcode;
  bool get isSellable => hasPrice && stockUnits > 0;

  Product copyWith({
    String? id,
    String? name,
    int? stockUnits,
    int? minStockUnits,
    int? costPesos,
    int? pricePesos,
    Object? category = _sentinel,
    Object? barcode = _sentinel,
    Object? imagePath = _sentinel,
    Object? visualSignature = _sentinel,
    bool? isFavorite,
    int? soldCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      stockUnits: stockUnits ?? this.stockUnits,
      minStockUnits: minStockUnits ?? this.minStockUnits,
      costPesos: costPesos ?? this.costPesos,
      pricePesos: pricePesos ?? this.pricePesos,
      category: identical(category, _sentinel)
          ? this.category
          : category as String?,
      barcode: identical(barcode, _sentinel)
          ? this.barcode
          : barcode as String?,
      imagePath: identical(imagePath, _sentinel)
          ? this.imagePath
          : imagePath as String?,
      visualSignature: identical(visualSignature, _sentinel)
          ? this.visualSignature
          : visualSignature as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      soldCount: soldCount ?? this.soldCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'stockUnits': stockUnits,
    'minStockUnits': minStockUnits,
    'costPesos': costPesos,
    'pricePesos': pricePesos,
    'category': category,
    'barcode': barcode,
    'imagePath': imagePath,
    'visualSignature': visualSignature,
    'isFavorite': isFavorite,
    'soldCount': soldCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Product fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      stockUnits: (json['stockUnits'] as num?)?.toInt() ?? 0,
      minStockUnits: (json['minStockUnits'] as num?)?.toInt() ?? 0,
      costPesos:
          (json['costPesos'] as num?)?.toInt() ??
          (json['costCents'] as num?)?.toInt() ??
          0,
      pricePesos:
          (json['pricePesos'] as num?)?.toInt() ??
          (json['priceCents'] as num?)?.toInt() ??
          0,
      category: json['category'] as String?,
      barcode: json['barcode'] as String?,
      imagePath: json['imagePath'] as String?,
      visualSignature: json['visualSignature'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      soldCount: (json['soldCount'] as num?)?.toInt() ?? 0,
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: _readDateTime(json['updatedAt']),
    );
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}
