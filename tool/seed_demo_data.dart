// Internal developer-only tool. Run with:
//   dart run tool\seed_demo_data.dart
//
// Seeds 20 demo products, a cash opening, and a supplier expense into the
// real Hive storage at %USERPROFILE%\Documents. All operations are idempotent:
// running the tool twice produces the same result as running it once.
//
// Optional flags:
//   --hive-path=<dir>   Override the Hive storage directory.
//   --dry-run           Print what would be seeded without writing anything.

import 'dart:io';
import 'package:hive/hive.dart';
import 'package:b_plus_commerce/app/services/visual_signature_service.dart';
import 'demo_seed_catalog.dart';

const String _boxName = 'b_plus_commerce';
const String _snapshotKey = 'snapshot';

void main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final hivePath = _resolveHivePath(args);

  if (hivePath == null) {
    stderr.writeln('ERROR: Could not determine Hive storage path.');
    stderr.writeln('Set %USERPROFILE% or pass --hive-path=<dir>.');
    exitCode = 1;
    return;
  }

  stdout.writeln('=== Caja Clara — Demo Seed Tool ===');
  stdout.writeln('Hive path : $hivePath');
  stdout.writeln('Dry run   : $dryRun');
  stdout.writeln('');

  Hive.init(hivePath);
  final box = await Hive.openBox<dynamic>(_boxName);

  final rawSnapshot = box.get(_snapshotKey);
  final snapshot = rawSnapshot == null
      ? _emptySnapshot()
      : _deepCastMap(rawSnapshot as Map);

  final seedResult = _seedProducts(snapshot);
  final cashResult = _seedCashOpening(snapshot);
  final expenseResult = _seedExpense(snapshot);
  final imageResult = await _attachColaImage(snapshot);

  stdout.writeln('Products  : ${seedResult.created} created, ${seedResult.skipped} skipped');
  stdout.writeln('Apertura  : ${cashResult.created ? "registrada (\$${_fmt(kDemoCashOpeningPesos)})" : "ya existia hoy — omitida"}');
  stdout.writeln('Gasto     : ${expenseResult.created ? "registrado (\$${_fmt(kDemoExpensePesos)} / $kDemoExpenseCategory)" : "ya existia hoy — omitido"}');
  stdout.writeln('Imagen    : $imageResult');
  stdout.writeln('');

  if (dryRun) {
    stdout.writeln('[DRY RUN] No se escribio nada en disco.');
    await Hive.close();
    return;
  }

  await box.put(_snapshotKey, snapshot);
  await Hive.close();

  stdout.writeln('Listo. Abri Caja Clara para ver los datos de demo.');
  stdout.writeln('Barcode desconocido para demo de escaneo: $kDemoUnknownBarcode');
}

// ---------------------------------------------------------------------------
// Path resolution
// ---------------------------------------------------------------------------

String? _resolveHivePath(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--hive-path=')) {
      return arg.substring('--hive-path='.length).trim();
    }
  }
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.isNotEmpty) {
    return '$userProfile\\Documents';
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return '$home/Documents';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Product seeding
// ---------------------------------------------------------------------------

({int created, int skipped}) _seedProducts(Map<String, dynamic> snapshot) {
  final products = snapshot['products'] as List<dynamic>;

  String normalizeBarcode(String? raw) =>
      (raw ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  final existingBarcodes = <String>{};
  final existingNames = <String>{};
  for (final p in products) {
    final map = _deepCastMap(p as Map);
    final bc = normalizeBarcode(map['barcode'] as String?);
    if (bc.isNotEmpty) existingBarcodes.add(bc);
    existingNames.add(normalizeName(map['name'] as String? ?? ''));
  }

  var created = 0;
  var skipped = 0;
  final now = DateTime.now().toIso8601String();

  for (final seed in kDemoCatalog) {
    final normalizedBarcode = normalizeBarcode(seed.barcode);
    if (normalizedBarcode.isNotEmpty &&
        existingBarcodes.contains(normalizedBarcode)) {
      skipped++;
      continue;
    }
    if (existingNames.contains(normalizeName(seed.name))) {
      skipped++;
      continue;
    }

    final id = _productId(seed);
    final product = <String, dynamic>{
      'id': id,
      'name': seed.name,
      'stockUnits': seed.stockUnits,
      'minStockUnits': seed.minStockUnits,
      'costPesos': 0,
      'pricePesos': seed.pricePesos,
      'category': seed.category,
      'barcode': seed.barcode,
      'imagePath': null,
      'visualSignature': null,
      'isFavorite': seed.isFavorite,
      'soldCount': 0,
      'createdAt': now,
      'updatedAt': now,
    };
    products.add(product);

    if (normalizedBarcode.isNotEmpty) existingBarcodes.add(normalizedBarcode);
    existingNames.add(normalizeName(seed.name));
    created++;
  }

  return (created: created, skipped: skipped);
}

// ---------------------------------------------------------------------------
// Cash opening seeding
// ---------------------------------------------------------------------------

({bool created}) _seedCashOpening(Map<String, dynamic> snapshot) {
  final existing = snapshot['cashOpeningAt'];
  if (existing != null) {
    final dt = DateTime.tryParse(existing.toString());
    if (dt != null && _isToday(dt)) {
      return (created: false);
    }
  }

  final now = DateTime.now();
  snapshot['cashOpeningAt'] = now.toIso8601String();
  snapshot['cashOpeningBalancePesos'] = kDemoCashOpeningPesos;

  final movements = snapshot['movements'] as List<dynamic>;
  movements.insert(0, <String, dynamic>{
    'id': 'demo-seed-cash-open-${now.microsecondsSinceEpoch}',
    'kind': 'adjustment',
    'origin': 'cashOpening',
    'amountPesos': 0,
    'cashImpactOverridePesos': 0,
    'estimatedProfitImpactOverridePesos': 0,
    'createdAt': now.toIso8601String(),
    'title': 'Apertura de caja',
    'subtitle': 'Caja inicial: ${_fmt(kDemoCashOpeningPesos)}',
    'saleKind': null,
    'productId': null,
    'quantityUnits': null,
    'category': null,
    'paymentMethod': null,
    'costOfSalePesos': null,
  });

  return (created: true);
}

// ---------------------------------------------------------------------------
// Expense seeding
// ---------------------------------------------------------------------------

({bool created}) _seedExpense(Map<String, dynamic> snapshot) {
  final movements = snapshot['movements'] as List<dynamic>;
  for (final m in movements) {
    final map = _deepCastMap(m as Map);
    if (map['kind'] == 'expense') {
      final dt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
      if (dt != null && _isToday(dt) && map['title'] == kDemoExpenseConcept) {
        return (created: false);
      }
    }
  }

  final now = DateTime.now();
  movements.insert(0, <String, dynamic>{
    'id': 'demo-seed-expense-${now.microsecondsSinceEpoch}',
    'kind': 'expense',
    'origin': 'expense',
    'amountPesos': kDemoExpensePesos,
    'createdAt': now.toIso8601String(),
    'title': kDemoExpenseConcept,
    'subtitle': kDemoExpenseCategory,
    'category': kDemoExpenseCategory,
    'saleKind': null,
    'productId': null,
    'quantityUnits': null,
    'paymentMethod': null,
    'costOfSalePesos': null,
    'cashImpactOverridePesos': null,
    'estimatedProfitImpactOverridePesos': null,
  });

  return (created: true);
}

// ---------------------------------------------------------------------------
// Coca-Cola image signature
// ---------------------------------------------------------------------------

Future<String> _attachColaImage(Map<String, dynamic> snapshot) async {
  final imageFile = File(kDemoColaImagePath);
  if (!imageFile.existsSync()) {
    return 'archivo no encontrado — omitida ($kDemoColaImagePath)';
  }

  final bytes = await imageFile.readAsBytes();
  final signature = VisualSignatureService.generate(bytes);

  final products = snapshot['products'] as List<dynamic>;
  var imageAttached = false;
  for (var i = 0; i < products.length; i++) {
    final map = _deepCastMap(products[i] as Map);
    final barcode = (map['barcode'] as String? ?? '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (barcode == kDemoColaNormalizedBarcode) {
      map['visualSignature'] = signature;
      products[i] = map;
      imageAttached = true;
      break;
    }
  }

  if (!imageAttached) {
    return 'producto Coca-Cola no encontrado en snapshot — firma omitida';
  }
  return 'firma generada (${signature.substring(0, 12)}...)';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _emptySnapshot() => <String, dynamic>{
      'version': 2,
      'savedAt': DateTime.now().toIso8601String(),
      'products': <dynamic>[],
      'movements': <dynamic>[],
      'dismissedFreeSaleSuggestions': <dynamic>[],
      'cashOpeningAt': null,
      'cashOpeningBalancePesos': null,
      'cashClosingAt': null,
      'cashClosingBalancePesos': null,
    };

String _productId(DemoProductSeed seed) {
  final slug = seed.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'demo-seed-$slug';
}

bool _isToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

String _fmt(int pesos) {
  final s = pesos.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

Map<String, dynamic> _deepCastMap(Map<dynamic, dynamic> raw) {
  return raw.map((k, v) => MapEntry(k.toString(), _deepCastValue(v)));
}

dynamic _deepCastValue(dynamic value) {
  if (value is Map) return _deepCastMap(value);
  if (value is List) return value.map(_deepCastValue).toList();
  return value;
}
