import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/visual_signature_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/demo_seed_catalog.dart';

void main() {
  group('demo catalog data integrity', () {
    test('contains exactly 20 products', () {
      expect(kDemoCatalog, hasLength(20));
    });

    test('all products have valid name, category, and positive price', () {
      for (final seed in kDemoCatalog) {
        expect(seed.name.trim(), isNotEmpty,
            reason: 'name must not be blank');
        expect(seed.category.trim(), isNotEmpty,
            reason: '${seed.name}: category must not be blank');
        expect(seed.pricePesos, greaterThan(0),
            reason: '${seed.name}: pricePesos must be > 0');
        expect(seed.stockUnits, greaterThanOrEqualTo(0),
            reason: '${seed.name}: stockUnits must be >= 0');
        expect(seed.minStockUnits, greaterThanOrEqualTo(0),
            reason: '${seed.name}: minStockUnits must be >= 0');
      }
    });

    test('all barcodes are unique among seeds that have one', () {
      final barcodes = kDemoCatalog
          .where((s) => s.barcode != null)
          .map((s) => s.barcode!)
          .toList();
      expect(barcodes.toSet().length, barcodes.length,
          reason: 'duplicate barcodes in catalog');
    });

    test('Coca-Cola entry has expected properties', () {
      final cola =
          kDemoCatalog.firstWhere((s) => s.name == 'Coca-Cola 2.25 L');
      expect(cola.barcode, kDemoColaNormalizedBarcode);
      expect(cola.isFavorite, isTrue);
      expect(cola.pricePesos, 3500);
      expect(cola.stockUnits, 24);
    });
  });

  group('demo seeding into store', () {
    test('creates 20 products in an empty store', () async {
      final store = CommerceStore.emptyForTest();
      final created = await _applyCatalogToStore(store);
      expect(created, 20);
      expect(store.products.length, 20);
    });

    test('seeding is idempotent — second pass creates nothing', () async {
      final store = CommerceStore.emptyForTest();
      await _applyCatalogToStore(store);
      final secondPass = await _applyCatalogToStore(store);
      expect(secondPass, 0);
      expect(store.products.length, 20);
    });

    test('seeded products have correct price, category, and stock', () async {
      final store = CommerceStore.emptyForTest();
      await _applyCatalogToStore(store);

      for (final seed in kDemoCatalog) {
        final product = seed.barcode != null
            ? store.productByBarcode(seed.barcode!)
            : store.productByNormalizedName(seed.name);
        expect(product, isNotNull, reason: '${seed.name} not found');
        expect(product!.pricePesos, seed.pricePesos,
            reason: '${seed.name}: wrong price');
        expect(product.category, seed.category,
            reason: '${seed.name}: wrong category');
        expect(product.stockUnits, seed.stockUnits,
            reason: '${seed.name}: wrong stock');
        expect(product.isFavorite, seed.isFavorite,
            reason: '${seed.name}: wrong favorite flag');
      }
    });

    test('exactly 4 products are favorites', () async {
      final store = CommerceStore.emptyForTest();
      await _applyCatalogToStore(store);
      final favorites = store.products.where((p) => p.isFavorite).toList();
      // Coca-Cola, Agua mineral, Alfajor Jorgito, Cigarrillos Marlboro
      expect(favorites, hasLength(4));
    });
  });

  group('visual signature format', () {
    test('identical signatures compare at 100% confidence', () {
      const sig = 'v1:0102030405060708090a0b0c0d0e0f10';
      expect(VisualSignatureService.compare(sig, sig), 1.0);
    });

    test('two identical byte sequences produce a 100% confidence match', () {
      const wellFormed = 'v1:0102030405060708090a0b0c0d0e0f10';
      final confidence = VisualSignatureService.compare(wellFormed, wellFormed);
      expect(confidence, 1.0);
    });
  });
}

// ---------------------------------------------------------------------------
// Helper — applies the catalog to a test store, returns count of products added
// ---------------------------------------------------------------------------

Future<int> _applyCatalogToStore(CommerceStore store) async {
  var created = 0;
  for (final seed in kDemoCatalog) {
    if (seed.barcode != null &&
        store.productByBarcode(seed.barcode!) != null) {
      continue;
    }
    if (store.productByNormalizedName(seed.name) != null) continue;

    final slug = seed.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final id = 'demo-seed-$slug';

    await store.addProduct(
      Product(
        id: id,
        name: seed.name,
        stockUnits: seed.stockUnits,
        minStockUnits: seed.minStockUnits,
        costPesos: 0,
        pricePesos: seed.pricePesos,
        category: seed.category,
        barcode: seed.barcode,
        isFavorite: seed.isFavorite,
      ),
    );
    created++;
  }
  return created;
}
