enum MovementKind { sale, expense, adjustment }

enum SaleKind { catalog, free }

enum MovementOrigin {
  sale,
  expense,
  cashOpening,
  cashClosing,
  restore,
  undo,
  adjustment,
}

class Movement {
  const Movement({
    required this.id,
    required this.kind,
    required this.amountPesos,
    required this.createdAt,
    required this.title,
    this.saleKind,
    this.origin,
    this.subtitle,
    this.productId,
    this.quantityUnits,
    this.category,
    this.paymentMethod,
    this.costOfSalePesos,
    this.cashImpactOverridePesos,
    this.estimatedProfitImpactOverridePesos,
  });

  final String id;
  final MovementKind kind;
  final int amountPesos;
  final DateTime createdAt;
  final String title;
  final SaleKind? saleKind;
  final MovementOrigin? origin;
  final String? subtitle;
  final String? productId;
  final int? quantityUnits;
  final String? category;
  final String? paymentMethod;
  final int? costOfSalePesos;
  final int? cashImpactOverridePesos;
  final int? estimatedProfitImpactOverridePesos;

  MovementOrigin get resolvedOrigin {
    if (origin != null) {
      return origin!;
    }
    switch (kind) {
      case MovementKind.sale:
        return MovementOrigin.sale;
      case MovementKind.expense:
        return MovementOrigin.expense;
      case MovementKind.adjustment:
        return MovementOrigin.adjustment;
    }
  }

  SaleKind get resolvedSaleKind {
    if (kind != MovementKind.sale) {
      return SaleKind.catalog;
    }
    if (saleKind != null) {
      return saleKind!;
    }
    return productId == null ? SaleKind.free : SaleKind.catalog;
  }

  bool get isFreeSale =>
      kind == MovementKind.sale && resolvedSaleKind == SaleKind.free;

  String get originLabel {
    switch (resolvedOrigin) {
      case MovementOrigin.sale:
        return 'Venta';
      case MovementOrigin.expense:
        return 'Gasto';
      case MovementOrigin.cashOpening:
        return 'Apertura';
      case MovementOrigin.cashClosing:
        return 'Cierre';
      case MovementOrigin.restore:
        return 'Restauracion';
      case MovementOrigin.undo:
        return 'Deshacer';
      case MovementOrigin.adjustment:
        return 'Ajuste';
    }
  }

  bool get isIncome => cashImpactPesos > 0;
  bool get isNeutral => cashImpactPesos == 0;

  int get cashImpactPesos {
    if (cashImpactOverridePesos != null) {
      return cashImpactOverridePesos!;
    }
    switch (kind) {
      case MovementKind.sale:
        return amountPesos;
      case MovementKind.expense:
        return -amountPesos;
      case MovementKind.adjustment:
        return 0;
    }
  }

  int get estimatedProfitImpactPesos {
    if (estimatedProfitImpactOverridePesos != null) {
      return estimatedProfitImpactOverridePesos!;
    }
    switch (kind) {
      case MovementKind.sale:
        return amountPesos - (costOfSalePesos ?? 0);
      case MovementKind.expense:
        return -amountPesos;
      case MovementKind.adjustment:
        return 0;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'origin': resolvedOrigin.name,
        'amountPesos': amountPesos,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'saleKind': kind == MovementKind.sale ? resolvedSaleKind.name : null,
        'subtitle': subtitle,
        'productId': productId,
        'quantityUnits': quantityUnits,
        'category': category,
        'paymentMethod': paymentMethod,
        'costOfSalePesos': costOfSalePesos,
        'cashImpactOverridePesos': cashImpactOverridePesos,
        'estimatedProfitImpactOverridePesos':
            estimatedProfitImpactOverridePesos,
      };

  static Movement fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] as String?) ?? MovementKind.sale.name;
    final kind = MovementKind.values.firstWhere(
      (value) => value.name == kindRaw,
      orElse: () => MovementKind.sale,
    );
    final saleKindRaw = json['saleKind'] as String?;
    final originRaw = json['origin'] as String?;
    final createdAtRaw = json['createdAt'] as String?;

    return Movement(
      id: (json['id'] as String?) ?? '',
      kind: kind,
      origin: _readOrigin(originRaw, kind),
      amountPesos: (json['amountPesos'] as num?)?.toInt() ??
          (json['amountCents'] as num?)?.toInt() ??
          0,
      createdAt: createdAtRaw == null
          ? DateTime.now()
          : DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      title: (json['title'] as String?) ?? '',
      saleKind: _readSaleKind(saleKindRaw, kind, json['productId'] as String?),
      subtitle: json['subtitle'] as String?,
      productId: json['productId'] as String?,
      quantityUnits: (json['quantityUnits'] as num?)?.toInt(),
      category: json['category'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      costOfSalePesos: (json['costOfSalePesos'] as num?)?.toInt(),
      cashImpactOverridePesos:
          (json['cashImpactOverridePesos'] as num?)?.toInt(),
      estimatedProfitImpactOverridePesos:
          (json['estimatedProfitImpactOverridePesos'] as num?)?.toInt(),
    );
  }

  static SaleKind? _readSaleKind(
    String? raw,
    MovementKind kind,
    String? productId,
  ) {
    if (kind != MovementKind.sale) {
      return null;
    }
    if (raw != null) {
      for (final value in SaleKind.values) {
        if (value.name == raw) {
          return value;
        }
      }
    }
    return productId == null ? SaleKind.free : SaleKind.catalog;
  }

  static MovementOrigin _readOrigin(String? raw, MovementKind kind) {
    if (raw != null) {
      for (final value in MovementOrigin.values) {
        if (value.name == raw) {
          return value;
        }
      }
    }

    switch (kind) {
      case MovementKind.sale:
        return MovementOrigin.sale;
      case MovementKind.expense:
        return MovementOrigin.expense;
      case MovementKind.adjustment:
        return MovementOrigin.adjustment;
    }
  }
}
