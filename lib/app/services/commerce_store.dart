import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/movement.dart';
import '../models/product.dart';
import 'commerce_persistence.dart';
import 'starter_templates.dart';

class CommerceStore extends ChangeNotifier {
  static const int freeSaleSuggestionThreshold = 3;

  CommerceStore._(this._persistence, {required bool persistenceEnabled})
    : _persistenceEnabled = persistenceEnabled;

  static Future<CommerceStore> loadOrSeed() async {
    await Hive.initFlutter();
    final store = CommerceStore._(
      CommercePersistence(),
      persistenceEnabled: true,
    );
    await store._load();
    return store;
  }

  @visibleForTesting
  static CommerceStore seededForTest() {
    final store = CommerceStore._(
      CommercePersistence(),
      persistenceEnabled: false,
    );
    store._seedDemoData();
    store._ready = true;
    return store;
  }

  @visibleForTesting
  static CommerceStore emptyForTest() {
    final store = CommerceStore._(
      CommercePersistence(),
      persistenceEnabled: false,
    );
    store._seedEmptyState();
    store._ready = true;
    return store;
  }

  @visibleForTesting
  static CommerceStore withPersistenceForTest(
    CommercePersistence persistence, {
    bool seedDemoData = false,
  }) {
    final store = CommerceStore._(persistence, persistenceEnabled: true);
    if (seedDemoData) {
      store._seedDemoData();
    } else {
      store._seedEmptyState();
    }
    store._ready = true;
    return store;
  }

  final CommercePersistence _persistence;
  final bool _persistenceEnabled;
  final List<Product> _products = <Product>[];
  final List<Movement> _movements = <Movement>[];
  final Set<String> _dismissedFreeSaleSuggestions = <String>{};

  bool _ready = false;
  bool _saving = false;
  String? _lastError;
  DateTime? _cashOpeningAt;
  int? _cashOpeningBalancePesos;
  DateTime? _cashClosingAt;
  int? _cashClosingBalancePesos;

  bool get isReady => _ready;
  bool get isSaving => _saving;
  String? get lastError => _lastError;
  bool get hasProducts => _products.isNotEmpty;
  bool get hasMovements => _movements.isNotEmpty;
  bool get isEmptyState => _products.isEmpty && _movements.isEmpty;

  UnmodifiableListView<Product> get products => UnmodifiableListView(_products);
  UnmodifiableListView<Movement> get movements =>
      UnmodifiableListView(_movements);

  Movement? get lastMovement => _movements.isEmpty ? null : _movements.first;
  bool get canUndoLastMovement =>
      _movements.isNotEmpty &&
      _movements.first.resolvedOrigin != MovementOrigin.restore;

  bool get hasCashOpeningToday =>
      _cashOpeningAt != null && _isSameDay(_cashOpeningAt!, DateTime.now());

  int? get todayOpeningCashPesos =>
      hasCashOpeningToday ? _cashOpeningBalancePesos : null;

  bool get hasCashClosingToday =>
      _cashClosingAt != null && _isSameDay(_cashClosingAt!, DateTime.now());

  int? get todayClosingCashPesos =>
      hasCashClosingToday ? _cashClosingBalancePesos : null;

  int? get todayExpectedCashPesos {
    final opening = todayOpeningCashPesos;
    if (opening == null) {
      return null;
    }
    return opening + todaySalesPesos - todayExpensesPesos;
  }

  int? get todayClosingDifferencePesos {
    final closing = todayClosingCashPesos;
    final expected = todayExpectedCashPesos;
    if (closing == null || expected == null) {
      return null;
    }
    return closing - expected;
  }

  int? get currentDifferenceFromOpeningPesos {
    final opening = todayOpeningCashPesos;
    if (opening == null) {
      return null;
    }
    return cashBalancePesos - opening;
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  Product? productByBarcode(String barcode) {
    final normalized = normalizeBarcode(barcode);
    if (normalized == null) {
      return null;
    }
    for (final product in _products) {
      if (product.barcode == normalized) {
        return product;
      }
    }
    return null;
  }

  Product? productByNormalizedName(String name, {String? excludingProductId}) {
    final normalized = normalizeProductName(name);
    if (normalized == null) {
      return null;
    }
    for (final product in _products) {
      if (excludingProductId != null && product.id == excludingProductId) {
        continue;
      }
      if (normalizeProductName(product.name) == normalized) {
        return product;
      }
    }
    return null;
  }

  static String? normalizeBarcode(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw
        .trim()
        .replaceAll(RegExp(r'[\s\-_]+'), '')
        .toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }

  static bool barcodeMatchesQuery(String? barcode, String rawQuery) {
    final normalizedBarcode = normalizeBarcode(barcode);
    if (normalizedBarcode == null) {
      return false;
    }
    final normalizedQuery = normalizeBarcode(rawQuery);
    if (normalizedQuery == null) {
      return false;
    }
    return normalizedBarcode.contains(normalizedQuery);
  }

  static String? normalizeProductName(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  List<Product> get lowStockProducts =>
      _products.where((product) => product.isLowStock).toList(growable: false);

  List<FreeSaleSuggestion> get freeSaleSuggestions {
    final grouped = <String, _FreeSaleAggregate>{};

    for (final movement in _movements) {
      if (!movement.isFreeSale) {
        continue;
      }
      final description = movement.subtitle ?? movement.title;
      final normalized = normalizeProductName(description);
      if (normalized == null ||
          _dismissedFreeSaleSuggestions.contains(normalized)) {
        continue;
      }
      if (productByNormalizedName(description) != null) {
        continue;
      }

      final aggregate = grouped.putIfAbsent(
        normalized,
        () => _FreeSaleAggregate(
          normalizedDescription: normalized,
          displayDescription: description.trim(),
        ),
      );
      aggregate.count += 1;
      aggregate.totalRevenuePesos += movement.amountPesos;
      if (aggregate.latestSoldAt == null ||
          movement.createdAt.isAfter(aggregate.latestSoldAt!)) {
        aggregate.latestSoldAt = movement.createdAt;
        aggregate.displayDescription = description.trim();
        final quantity = movement.quantityUnits ?? 0;
        aggregate.latestUnitPricePesos = quantity > 0
            ? movement.amountPesos ~/ quantity
            : null;
      }
    }

    return grouped.values
        .where((item) => item.count >= freeSaleSuggestionThreshold)
        .map(
          (item) => FreeSaleSuggestion(
            normalizedDescription: item.normalizedDescription,
            displayDescription: item.displayDescription,
            repeatCount: item.count,
            latestSoldAt: item.latestSoldAt ?? DateTime.now(),
            totalRevenuePesos: item.totalRevenuePesos,
            latestUnitPricePesos: item.latestUnitPricePesos,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) {
        final byCount = b.repeatCount.compareTo(a.repeatCount);
        if (byCount != 0) {
          return byCount;
        }
        return b.latestSoldAt.compareTo(a.latestSoldAt);
      });
  }

  List<Movement> recentMovements([int limit = 8]) =>
      _movements.take(limit).toList(growable: false);

  int get cashBalancePesos => _movements.fold<int>(
    0,
    (sum, movement) => sum + movement.cashImpactPesos,
  );

  int get todaySalesPesos => _sumToday(
    (movement) => movement.kind == MovementKind.sale ? movement.amountPesos : 0,
  );

  int get todayExpensesPesos => _sumToday(
    (movement) =>
        movement.kind == MovementKind.expense ? movement.amountPesos : 0,
  );

  int get todayEstimatedProfitPesos =>
      _sumToday((movement) => movement.estimatedProfitImpactPesos);

  int get todaySalesCount => _movements
      .where(_isTodayMovement)
      .where((movement) => movement.kind == MovementKind.sale)
      .length;

  int get todayMovementCount => _movements.where(_isTodayMovement).length;

  int get totalStockUnits =>
      _products.fold<int>(0, (sum, product) => sum + product.stockUnits);

  int get sellableProductsCount => _products
      .where((product) => product.pricePesos > 0 && product.stockUnits > 0)
      .length;

  int get productsWithBarcodeCount =>
      _products.where((product) => (product.barcode ?? '').isNotEmpty).length;

  int get estimatedInventoryCostPesos => _products.fold<int>(
    0,
    (sum, product) => sum + (product.costPesos * product.stockUnits),
  );

  String? get lastSalePaymentMethod {
    for (final movement in _movements) {
      if (movement.kind != MovementKind.sale) {
        continue;
      }
      final paymentMethod = movement.paymentMethod?.trim();
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        return paymentMethod;
      }
    }
    return null;
  }

  int get lowStockCount => lowStockProducts.length;

  String? saleReadinessMessage(String productId, {required int quantityUnits}) {
    final product = productById(productId);
    if (product == null) {
      return 'El producto ya no esta disponible.';
    }
    if (quantityUnits <= 0) {
      return 'Ingresa una cantidad mayor a 0.';
    }
    if (product.pricePesos <= 0) {
      return 'Define un precio antes de vender este producto.';
    }
    if (product.stockUnits < quantityUnits) {
      return 'No hay stock suficiente. Stock actual: ${product.stockUnits}.';
    }
    return null;
  }

  String? freeSaleReadinessMessage({
    required String description,
    required int quantityUnits,
    required int unitPricePesos,
  }) {
    if (description.trim().isEmpty) {
      return 'Escribe una descripcion para la venta.';
    }
    if (quantityUnits <= 0) {
      return 'Ingresa una cantidad mayor a 0.';
    }
    if (unitPricePesos <= 0) {
      return 'Ingresa un precio unitario mayor a 0.';
    }
    return null;
  }

  int _sumToday(int Function(Movement movement) selector) {
    return _movements
        .where(_isTodayMovement)
        .fold<int>(0, (sum, movement) => sum + selector(movement));
  }

  bool _isTodayMovement(Movement movement) {
    return _isSameDay(movement.createdAt, DateTime.now());
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _load() async {
    try {
      final snapshot = await _persistence.load();
      if (snapshot == null) {
        _seedEmptyState();
        await _persist();
      } else {
        _applySnapshot(_parseSnapshot(snapshot));
      }
      _ready = true;
      notifyListeners();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('CommerceStore load failed: $error');
        debugPrintStack(stackTrace: stack);
      }
      _seedEmptyState();
      _ready = true;
      _lastError =
          'No se pudo abrir el almacenamiento. La app quedo lista para cargar tus datos.';
      notifyListeners();
    }
  }

  void _seedEmptyState() {
    _products.clear();
    _movements.clear();
    _cashOpeningAt = null;
    _cashOpeningBalancePesos = null;
    _cashClosingAt = null;
    _cashClosingBalancePesos = null;
  }

  void _seedDemoData() {
    final now = DateTime.now();
    _products
      ..clear()
      ..addAll(<Product>[
        const Product(
          id: 'p-1',
          name: 'Yerba premium',
          stockUnits: 8,
          minStockUnits: 10,
          costPesos: 2650,
          pricePesos: 4100,
          category: 'Almacen',
          barcode: '7791234500011',
        ),
        const Product(
          id: 'p-2',
          name: 'Papel higienico x4',
          stockUnits: 14,
          minStockUnits: 8,
          costPesos: 2200,
          pricePesos: 3600,
          category: 'Limpieza',
          barcode: '7791234500028',
        ),
        const Product(
          id: 'p-3',
          name: 'Cafe molido',
          stockUnits: 5,
          minStockUnits: 7,
          costPesos: 4300,
          pricePesos: 6800,
          category: 'Bebidas',
          barcode: '7791234500035',
        ),
        const Product(
          id: 'p-4',
          name: 'Galletitas de manteca',
          stockUnits: 22,
          minStockUnits: 12,
          costPesos: 950,
          pricePesos: 1750,
          category: 'Almacen',
          barcode: '7791234500042',
        ),
        const Product(
          id: 'p-5',
          name: 'Aceite 900 ml',
          stockUnits: 6,
          minStockUnits: 8,
          costPesos: 5200,
          pricePesos: 8400,
          category: 'Almacen',
          barcode: '7791234500059',
        ),
      ]);

    _movements
      ..clear()
      ..addAll(<Movement>[
        Movement(
          id: 'm-1',
          kind: MovementKind.sale,
          origin: MovementOrigin.sale,
          amountPesos: 12300,
          costOfSalePesos: 7190,
          createdAt: now.subtract(const Duration(minutes: 18)),
          title: 'Venta',
          subtitle: 'Yerba premium + cafe',
          quantityUnits: 3,
          paymentMethod: 'Efectivo',
          productId: 'p-1',
        ),
        Movement(
          id: 'm-2',
          kind: MovementKind.expense,
          origin: MovementOrigin.expense,
          amountPesos: 4500,
          createdAt: now.subtract(const Duration(hours: 2, minutes: 12)),
          title: 'Gasto',
          subtitle: 'Reposicion de bolsas',
          category: 'Insumos',
        ),
        Movement(
          id: 'm-3',
          kind: MovementKind.sale,
          origin: MovementOrigin.sale,
          amountPesos: 8800,
          costOfSalePesos: 4600,
          createdAt: now.subtract(const Duration(hours: 5, minutes: 5)),
          title: 'Venta',
          subtitle: 'Papel higienico x4',
          quantityUnits: 2,
          paymentMethod: 'Transferencia',
          productId: 'p-2',
        ),
        Movement(
          id: 'm-4',
          kind: MovementKind.sale,
          origin: MovementOrigin.sale,
          amountPesos: 11500,
          costOfSalePesos: 7260,
          createdAt: now.subtract(const Duration(days: 1, hours: 1)),
          title: 'Venta',
          subtitle: 'Cafe molido + galletitas',
          quantityUnits: 2,
          paymentMethod: 'Debito',
          productId: 'p-3',
        ),
      ])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _cashOpeningAt = null;
    _cashOpeningBalancePesos = null;
    _cashClosingAt = null;
    _cashClosingBalancePesos = null;
  }

  Future<StarterTemplateApplyResult> applyArgentinianKioskTemplate() async {
    final existingProducts = List<Product>.of(_products, growable: false);
    final existingKeys = existingProducts
        .map(_starterTemplateKeyForProduct)
        .toSet();
    final pendingProducts = <Product>[];
    var skippedCount = 0;

    for (final seed in argentinianKioskTemplateProducts) {
      final key = _starterTemplateKey(seed.name, seed.category);
      if (existingKeys.contains(key)) {
        skippedCount += 1;
        continue;
      }

      final product = _validateProduct(
        Product(
          id: _buildId('product'),
          name: seed.name,
          stockUnits: seed.stockUnits,
          minStockUnits: seed.minStockUnits,
          costPesos: seed.costPesos,
          pricePesos: seed.pricePesos,
          category: seed.category,
        ),
        againstProducts: <Product>[...existingProducts, ...pendingProducts],
      );

      pendingProducts.add(product);
      existingKeys.add(key);
    }

    if (pendingProducts.isNotEmpty) {
      await _runPersistedMutation(() {
        _products.addAll(pendingProducts);
        _sortProducts();
      });
    }

    return StarterTemplateApplyResult(
      templateName: argentinianKioskTemplateName,
      totalCount: argentinianKioskTemplateProducts.length,
      addedCount: pendingProducts.length,
      skippedCount: skippedCount,
    );
  }

  Future<void> loadDemoData({bool overwrite = false}) async {
    if (!overwrite && !isEmptyState) {
      throw StateError(
        'La demo comercial solo se puede cargar sobre una app vacia.',
      );
    }

    await _runPersistedMutation(_seedDemoData);
  }

  Future<void> addProduct(Product product) async {
    final sanitized = _validateProduct(product);
    await _runPersistedMutation(() {
      final index = _products.indexWhere((item) => item.id == sanitized.id);
      if (index == -1) {
        _products.add(sanitized);
      } else {
        _products[index] = sanitized;
      }
      _sortProducts();
    });
  }

  Future<void> addStockToProduct({
    required String productId,
    required int quantityUnits,
    String? note,
    DateTime? createdAt,
  }) async {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) {
      throw StateError('No se encontro el producto.');
    }
    if (quantityUnits <= 0) {
      throw StateError('Ingresa una cantidad mayor a 0.');
    }

    final product = _products[index];
    await _runPersistedMutation(() {
      _products[index] = product.copyWith(
        stockUnits: product.stockUnits + quantityUnits,
      );
      _movements.insert(
        0,
        Movement(
          id: _buildId('stock'),
          kind: MovementKind.adjustment,
          origin: MovementOrigin.adjustment,
          amountPesos: 0,
          cashImpactOverridePesos: 0,
          estimatedProfitImpactOverridePesos: 0,
          createdAt: createdAt ?? DateTime.now(),
          title: 'Ingreso de stock',
          subtitle: note == null || note.trim().isEmpty
              ? '${product.name} / +$quantityUnits u.'
              : '${product.name} / +$quantityUnits u. / ${note.trim()}',
          productId: product.id,
          quantityUnits: quantityUnits,
        ),
      );
      _sortProducts();
    });
  }

  Future<void> removeProduct(String productId) async {
    final productExists = _products.any((product) => product.id == productId);
    if (!productExists) {
      throw StateError('No se encontro el producto.');
    }
    if (_movements.any((movement) => movement.productId == productId)) {
      throw StateError(
        'No se puede borrar un producto con movimientos registrados.',
      );
    }
    await _runPersistedMutation(() {
      _products.removeWhere((product) => product.id == productId);
    });
  }

  Future<void> dismissFreeSaleSuggestion(String normalizedDescription) async {
    final normalized = normalizeProductName(normalizedDescription);
    if (normalized == null ||
        _dismissedFreeSaleSuggestions.contains(normalized)) {
      return;
    }
    await _runPersistedMutation(() {
      _dismissedFreeSaleSuggestions.add(normalized);
    });
  }

  Future<void> recordSale({
    required String productId,
    required int quantityUnits,
    required String paymentMethod,
    DateTime? createdAt,
  }) async {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) {
      throw StateError('No se encontro el producto.');
    }
    if (quantityUnits <= 0) {
      throw StateError('Ingresa una cantidad mayor a 0.');
    }

    final product = _products[index];
    final readinessMessage = saleReadinessMessage(
      product.id,
      quantityUnits: quantityUnits,
    );
    if (readinessMessage != null) {
      throw StateError(readinessMessage);
    }

    final revenue = product.pricePesos * quantityUnits;
    final cost = product.costPesos * quantityUnits;
    final timestamp = createdAt ?? DateTime.now();
    await _runPersistedMutation(() {
      _products[index] = product.copyWith(
        stockUnits: product.stockUnits - quantityUnits,
      );
      _movements.insert(
        0,
        Movement(
          id: _buildId('sale'),
          kind: MovementKind.sale,
          origin: MovementOrigin.sale,
          amountPesos: revenue,
          costOfSalePesos: cost,
          createdAt: timestamp,
          title: 'Venta',
          subtitle: product.name,
          productId: product.id,
          quantityUnits: quantityUnits,
          paymentMethod: paymentMethod.trim().isEmpty
              ? 'Sin dato'
              : paymentMethod,
        ),
      );
      _sortProducts();
    });
  }

  Future<void> recordFreeSale({
    required String description,
    required int quantityUnits,
    required int unitPricePesos,
    required String paymentMethod,
    DateTime? createdAt,
  }) async {
    final cleanDescription = description.trim();
    final readinessMessage = freeSaleReadinessMessage(
      description: cleanDescription,
      quantityUnits: quantityUnits,
      unitPricePesos: unitPricePesos,
    );
    if (readinessMessage != null) {
      throw StateError(readinessMessage);
    }

    final revenue = unitPricePesos * quantityUnits;
    await _runPersistedMutation(() {
      _movements.insert(
        0,
        Movement(
          id: _buildId('sale-free'),
          kind: MovementKind.sale,
          saleKind: SaleKind.free,
          origin: MovementOrigin.sale,
          amountPesos: revenue,
          costOfSalePesos: 0,
          createdAt: createdAt ?? DateTime.now(),
          title: 'Venta libre',
          subtitle: cleanDescription,
          quantityUnits: quantityUnits,
          paymentMethod: paymentMethod.trim().isEmpty
              ? 'Sin dato'
              : paymentMethod,
        ),
      );
    });
  }

  Future<void> recordExpense({
    required String concept,
    required int amountPesos,
    required String category,
    DateTime? createdAt,
  }) async {
    final cleanConcept = concept.trim();
    final cleanCategory = category.trim().isEmpty ? 'General' : category.trim();

    if (cleanConcept.isEmpty) {
      throw StateError('Escribe un concepto.');
    }
    if (amountPesos <= 0) {
      throw StateError('Ingresa un monto mayor a 0.');
    }

    await _runPersistedMutation(() {
      _movements.insert(
        0,
        Movement(
          id: _buildId('expense'),
          kind: MovementKind.expense,
          origin: MovementOrigin.expense,
          amountPesos: amountPesos,
          createdAt: createdAt ?? DateTime.now(),
          title: cleanConcept,
          subtitle: cleanCategory,
          category: cleanCategory,
        ),
      );
    });
  }

  Future<void> registerCashOpening({
    required int openingBalancePesos,
    DateTime? createdAt,
    bool overwrite = false,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    if (openingBalancePesos < 0) {
      throw StateError('La apertura no puede ser negativa.');
    }
    if (hasCashOpeningToday && !overwrite) {
      throw StateError('Ya hay una apertura de caja registrada hoy.');
    }

    await _runPersistedMutation(() {
      _removeAdjustmentForDay(MovementOrigin.cashOpening, timestamp);
      _removeAdjustmentForDay(MovementOrigin.cashClosing, timestamp);

      _cashOpeningAt = timestamp;
      _cashOpeningBalancePesos = openingBalancePesos;
      _cashClosingAt = null;
      _cashClosingBalancePesos = null;

      _movements.insert(
        0,
        Movement(
          id: _buildId('cash-open'),
          kind: MovementKind.adjustment,
          origin: MovementOrigin.cashOpening,
          amountPesos: 0,
          cashImpactOverridePesos: 0,
          estimatedProfitImpactOverridePesos: 0,
          createdAt: timestamp,
          title: 'Apertura de caja',
          subtitle: 'Caja inicial: $openingBalancePesos',
        ),
      );
    });
  }

  Future<void> registerCashClosing({
    required int closingBalancePesos,
    DateTime? createdAt,
    bool overwrite = false,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    if (!hasCashOpeningToday) {
      throw StateError('Registra primero una apertura de caja.');
    }
    if (closingBalancePesos < 0) {
      throw StateError('El cierre no puede ser negativo.');
    }
    if (hasCashClosingToday && !overwrite) {
      throw StateError('Ya hay un cierre de caja registrado hoy.');
    }

    await _runPersistedMutation(() {
      _removeAdjustmentForDay(MovementOrigin.cashClosing, timestamp);

      _cashClosingAt = timestamp;
      _cashClosingBalancePesos = closingBalancePesos;

      _movements.insert(
        0,
        Movement(
          id: _buildId('cash-close'),
          kind: MovementKind.adjustment,
          origin: MovementOrigin.cashClosing,
          amountPesos: 0,
          cashImpactOverridePesos: 0,
          estimatedProfitImpactOverridePesos: 0,
          createdAt: timestamp,
          title: 'Cierre de caja',
          subtitle: 'Caja contada: $closingBalancePesos',
        ),
      );
    });
  }

  Future<void> undoLastMovement() async {
    if (_movements.isEmpty) {
      throw StateError('No hay movimientos para deshacer.');
    }

    final movement = _movements.first;
    if (movement.resolvedOrigin == MovementOrigin.restore) {
      throw StateError('No se puede deshacer una restauracion de backup.');
    }

    await _runPersistedMutation(() {
      if (movement.kind == MovementKind.sale) {
        final productId = movement.productId;
        final quantity = movement.quantityUnits ?? 0;
        if (movement.resolvedSaleKind == SaleKind.free) {
          _movements.removeAt(0);
          return;
        }
        if (productId == null || quantity <= 0) {
          throw StateError('La venta no se puede deshacer de forma segura.');
        }
        final index = _products.indexWhere(
          (product) => product.id == productId,
        );
        if (index == -1) {
          throw StateError(
            'No se puede deshacer la venta porque falta el producto original.',
          );
        }
        final product = _products[index];
        _products[index] = product.copyWith(
          stockUnits: product.stockUnits + quantity,
        );
        _sortProducts();
      } else if (movement.kind == MovementKind.adjustment) {
        final productId = movement.productId;
        final quantity = movement.quantityUnits ?? 0;
        if (productId != null && quantity > 0) {
          final index = _products.indexWhere(
            (product) => product.id == productId,
          );
          if (index == -1) {
            throw StateError(
              'No se puede deshacer el ajuste porque falta el producto original.',
            );
          }
          final product = _products[index];
          if (product.stockUnits < quantity) {
            throw StateError(
              'No se puede deshacer el ajuste porque el stock actual es menor al agregado.',
            );
          }
          _products[index] = product.copyWith(
            stockUnits: product.stockUnits - quantity,
          );
          _sortProducts();
        }
        _revertAdjustmentMetadata(movement);
      }

      _movements.removeAt(0);
    });
  }

  Map<String, dynamic> buildSnapshot({DateTime? generatedAt}) {
    return <String, dynamic>{
      'version': 2,
      'savedAt': (generatedAt ?? DateTime.now()).toIso8601String(),
      'products': _products.map((product) => product.toJson()).toList(),
      'movements': _movements.map((movement) => movement.toJson()).toList(),
      'dismissedFreeSaleSuggestions': _dismissedFreeSaleSuggestions.toList(),
      'cashOpeningAt': _cashOpeningAt?.toIso8601String(),
      'cashOpeningBalancePesos': _cashOpeningBalancePesos,
      'cashClosingAt': _cashClosingAt?.toIso8601String(),
      'cashClosingBalancePesos': _cashClosingBalancePesos,
    };
  }

  Future<void> restoreSnapshot(Map<String, dynamic> snapshot) async {
    final parsed = _parseSnapshot(snapshot);
    await _runPersistedMutation(() {
      _applySnapshot(parsed);
      _movements.insert(
        0,
        Movement(
          id: _buildId('restore'),
          kind: MovementKind.adjustment,
          origin: MovementOrigin.restore,
          amountPesos: 0,
          cashImpactOverridePesos: 0,
          estimatedProfitImpactOverridePesos: 0,
          createdAt: DateTime.now(),
          title: 'Restauracion de backup',
          subtitle: 'Estado restaurado correctamente',
        ),
      );
    });
  }

  Future<void> ensureReady() async {
    if (!_ready) {
      await _load();
    }
  }

  Future<void> retrySave() async {
    await _persist();
  }

  _SnapshotData _parseSnapshot(Map<String, dynamic> snapshot) {
    final products = _readProducts(snapshot['products']);
    final movements = _readMovements(snapshot['movements']);

    final productIds = <String>{};
    final productBarcodes = <String>{};
    final validatedProducts = <Product>[];
    for (final product in products) {
      final valid = _validateProduct(
        product,
        allowZeroPrice: true,
        allowZeroCost: true,
        againstProducts: validatedProducts,
      );
      if (!productIds.add(valid.id)) {
        throw StateError('Hay productos duplicados en el backup.');
      }
      final barcode = valid.barcode;
      if (barcode != null && !productBarcodes.add(barcode)) {
        throw StateError('Hay codigos de barras duplicados en el backup.');
      }
      validatedProducts.add(valid);
    }

    for (final movement in movements) {
      _validateMovement(movement, productIds);
    }

    movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _SnapshotData(
      products: validatedProducts,
      movements: movements,
      dismissedFreeSaleSuggestions: _readStringSet(
        snapshot['dismissedFreeSaleSuggestions'],
      ),
      cashOpeningAt: _readDate(snapshot['cashOpeningAt']),
      cashOpeningBalancePesos: (snapshot['cashOpeningBalancePesos'] as num?)
          ?.toInt(),
      cashClosingAt: _readDate(snapshot['cashClosingAt']),
      cashClosingBalancePesos: (snapshot['cashClosingBalancePesos'] as num?)
          ?.toInt(),
    )..validateCashState();
  }

  List<Product> _readProducts(dynamic value) {
    if (value is! List) {
      return <Product>[];
    }
    return value
        .whereType<Map>()
        .map((raw) => Product.fromJson(raw.cast<String, dynamic>()))
        .toList(growable: false);
  }

  List<Movement> _readMovements(dynamic value) {
    if (value is! List) {
      return <Movement>[];
    }
    return value
        .whereType<Map>()
        .map((raw) => Movement.fromJson(raw.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Set<String> _readStringSet(dynamic value) {
    if (value is! List) {
      return <String>{};
    }
    return value
        .whereType<String>()
        .map(normalizeProductName)
        .whereType<String>()
        .toSet();
  }

  Product _validateProduct(
    Product product, {
    bool allowZeroPrice = true,
    bool allowZeroCost = true,
    Iterable<Product>? againstProducts,
  }) {
    final normalizedBarcode = normalizeBarcode(product.barcode);
    if (product.id.trim().isEmpty) {
      throw StateError('El producto necesita un id valido.');
    }
    if (product.name.trim().isEmpty) {
      throw StateError('El producto necesita un nombre.');
    }
    if (product.stockUnits < 0) {
      throw StateError('El stock no puede ser negativo.');
    }
    if (product.minStockUnits < 0) {
      throw StateError('El stock minimo no puede ser negativo.');
    }
    if (product.costPesos < 0 || (!allowZeroCost && product.costPesos == 0)) {
      throw StateError('El costo debe ser mayor a 0.');
    }
    if (product.pricePesos < 0 ||
        (!allowZeroPrice && product.pricePesos == 0)) {
      throw StateError('El precio debe ser mayor a 0.');
    }
    for (final existing in againstProducts ?? _products) {
      if (normalizedBarcode != null &&
          existing.id != product.id &&
          existing.barcode == normalizedBarcode) {
        throw StateError(
          'Ese codigo de barras ya esta asignado a otro producto.',
        );
      }
    }
    return product.copyWith(
      name: product.name.trim(),
      category: product.category?.trim().isEmpty == true
          ? null
          : product.category?.trim(),
      barcode: normalizedBarcode,
    );
  }

  void _validateMovement(Movement movement, Set<String> productIds) {
    if (movement.amountPesos < 0) {
      throw StateError('Hay un movimiento con importe invalido.');
    }
    if (movement.title.trim().isEmpty) {
      throw StateError('Hay un movimiento sin titulo.');
    }
    if (movement.kind == MovementKind.sale) {
      if ((movement.quantityUnits ?? 0) <= 0) {
        throw StateError('Hay una venta con cantidad invalida.');
      }
      if (movement.resolvedSaleKind == SaleKind.catalog) {
        final productId = movement.productId;
        if (productId == null || !productIds.contains(productId)) {
          throw StateError('Hay una venta asociada a un producto inexistente.');
        }
      } else if ((movement.subtitle ?? '').trim().isEmpty) {
        throw StateError('Hay una venta libre sin descripcion.');
      }
    }
    if (movement.kind == MovementKind.expense &&
        movement.title.trim().isEmpty) {
      throw StateError('Hay un gasto sin concepto.');
    }
  }

  DateTime? _readDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  void _applySnapshot(_SnapshotData snapshot) {
    _products
      ..clear()
      ..addAll(snapshot.products);
    _movements
      ..clear()
      ..addAll(snapshot.movements);
    _dismissedFreeSaleSuggestions
      ..clear()
      ..addAll(snapshot.dismissedFreeSaleSuggestions);
    _cashOpeningAt = snapshot.cashOpeningAt;
    _cashOpeningBalancePesos = snapshot.cashOpeningBalancePesos;
    _cashClosingAt = snapshot.cashClosingAt;
    _cashClosingBalancePesos = snapshot.cashClosingBalancePesos;
    _sortProducts();
  }

  void _removeAdjustmentForDay(MovementOrigin origin, DateTime day) {
    _movements.removeWhere(
      (movement) =>
          movement.resolvedOrigin == origin &&
          _isSameDay(movement.createdAt, day),
    );
  }

  void _revertAdjustmentMetadata(Movement movement) {
    switch (movement.resolvedOrigin) {
      case MovementOrigin.cashOpening:
        _cashOpeningAt = null;
        _cashOpeningBalancePesos = null;
        _cashClosingAt = null;
        _cashClosingBalancePesos = null;
      case MovementOrigin.cashClosing:
        _cashClosingAt = null;
        _cashClosingBalancePesos = null;
      case MovementOrigin.sale:
      case MovementOrigin.expense:
      case MovementOrigin.restore:
      case MovementOrigin.undo:
      case MovementOrigin.adjustment:
        break;
    }
  }

  Future<void> _persist() async {
    if (!_persistenceEnabled) return;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      await _persistence.save(buildSnapshot());
    } catch (error) {
      _lastError = 'No se pudo guardar el cambio.';
      if (kDebugMode) {
        debugPrint('CommerceStore save failed: $error');
      }
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _runPersistedMutation(VoidCallback mutation) async {
    final previousState = _captureState();
    mutation();
    try {
      await _persist();
    } catch (_) {
      _restoreState(previousState);
      notifyListeners();
      rethrow;
    }
  }

  _MutableStoreState _captureState() {
    return _MutableStoreState(
      products: List<Product>.of(_products, growable: false),
      movements: List<Movement>.of(_movements, growable: false),
      dismissedFreeSaleSuggestions: Set<String>.of(
        _dismissedFreeSaleSuggestions,
      ),
      cashOpeningAt: _cashOpeningAt,
      cashOpeningBalancePesos: _cashOpeningBalancePesos,
      cashClosingAt: _cashClosingAt,
      cashClosingBalancePesos: _cashClosingBalancePesos,
    );
  }

  void _restoreState(_MutableStoreState state) {
    _products
      ..clear()
      ..addAll(state.products);
    _movements
      ..clear()
      ..addAll(state.movements);
    _dismissedFreeSaleSuggestions
      ..clear()
      ..addAll(state.dismissedFreeSaleSuggestions);
    _cashOpeningAt = state.cashOpeningAt;
    _cashOpeningBalancePesos = state.cashOpeningBalancePesos;
    _cashClosingAt = state.cashClosingAt;
    _cashClosingBalancePesos = state.cashClosingBalancePesos;
    _sortProducts();
  }

  void _sortProducts() {
    _products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  String _starterTemplateKeyForProduct(Product product) {
    return _starterTemplateKey(product.name, product.category ?? '');
  }

  String _starterTemplateKey(String name, String category) {
    final normalizedName = name.trim().toLowerCase();
    final normalizedCategory = category.trim().toLowerCase();
    return '$normalizedCategory::$normalizedName';
  }

  String _buildId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$now';
  }
}

class StarterTemplateApplyResult {
  const StarterTemplateApplyResult({
    required this.templateName,
    required this.totalCount,
    required this.addedCount,
    required this.skippedCount,
  });

  final String templateName;
  final int totalCount;
  final int addedCount;
  final int skippedCount;

  bool get addedAny => addedCount > 0;
  bool get fullySkipped => addedCount == 0 && skippedCount == totalCount;
}

class _MutableStoreState {
  const _MutableStoreState({
    required this.products,
    required this.movements,
    required this.dismissedFreeSaleSuggestions,
    required this.cashOpeningAt,
    required this.cashOpeningBalancePesos,
    required this.cashClosingAt,
    required this.cashClosingBalancePesos,
  });

  final List<Product> products;
  final List<Movement> movements;
  final Set<String> dismissedFreeSaleSuggestions;
  final DateTime? cashOpeningAt;
  final int? cashOpeningBalancePesos;
  final DateTime? cashClosingAt;
  final int? cashClosingBalancePesos;
}

class _SnapshotData {
  _SnapshotData({
    required this.products,
    required this.movements,
    required this.dismissedFreeSaleSuggestions,
    required this.cashOpeningAt,
    required this.cashOpeningBalancePesos,
    required this.cashClosingAt,
    required this.cashClosingBalancePesos,
  });

  final List<Product> products;
  final List<Movement> movements;
  final Set<String> dismissedFreeSaleSuggestions;
  final DateTime? cashOpeningAt;
  final int? cashOpeningBalancePesos;
  final DateTime? cashClosingAt;
  final int? cashClosingBalancePesos;

  void validateCashState() {
    if (cashOpeningBalancePesos != null && cashOpeningBalancePesos! < 0) {
      throw StateError('La apertura del backup es invalida.');
    }
    if (cashClosingBalancePesos != null && cashClosingBalancePesos! < 0) {
      throw StateError('El cierre del backup es invalido.');
    }
  }
}

class FreeSaleSuggestion {
  const FreeSaleSuggestion({
    required this.normalizedDescription,
    required this.displayDescription,
    required this.repeatCount,
    required this.latestSoldAt,
    required this.totalRevenuePesos,
    this.latestUnitPricePesos,
  });

  final String normalizedDescription;
  final String displayDescription;
  final int repeatCount;
  final DateTime latestSoldAt;
  final int totalRevenuePesos;
  final int? latestUnitPricePesos;
}

class _FreeSaleAggregate {
  _FreeSaleAggregate({
    required this.normalizedDescription,
    required this.displayDescription,
  });

  final String normalizedDescription;
  String displayDescription;
  int count = 0;
  int totalRevenuePesos = 0;
  int? latestUnitPricePesos;
  DateTime? latestSoldAt;
}
