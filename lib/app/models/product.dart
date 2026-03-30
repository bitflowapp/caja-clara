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
  });

  final String id;
  final String name;
  final int stockUnits;
  final int minStockUnits;
  final int costPesos;
  final int pricePesos;
  final String? category;
  final String? barcode;

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
    );
  }
}
