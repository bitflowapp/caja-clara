import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/product_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductCatalogService', () {
    test('finds product by normalized barcode', () async {
      final store = CommerceStore.emptyForTest();
      final service = ProductCatalogService(store);
      await service.saveProduct(
        const Product(
          id: 'p-water',
          name: 'Agua mineral',
          stockUnits: 8,
          minStockUnits: 1,
          costPesos: 400,
          pricePesos: 900,
          barcode: '779-001',
        ),
      );

      expect(service.findByBarcode('779 001')?.name, 'Agua mineral');
    });

    test('searches by name without requiring exact casing', () async {
      final store = CommerceStore.emptyForTest();
      final service = ProductCatalogService(store);
      await service.saveProduct(
        const Product(
          id: 'p-alfajor',
          name: 'Alfajor triple chocolate',
          category: 'Golosinas',
          stockUnits: 10,
          minStockUnits: 2,
          costPesos: 350,
          pricePesos: 900,
        ),
      );

      final results = service.searchByName('TRIPLE');

      expect(results, hasLength(1));
      expect(results.single.id, 'p-alfajor');
    });

    test('creates and updates a product through the store', () async {
      final store = CommerceStore.emptyForTest();
      final service = ProductCatalogService(store);
      const product = Product(
        id: 'p-soda',
        name: 'Gaseosa lima',
        stockUnits: 5,
        minStockUnits: 1,
        costPesos: 700,
        pricePesos: 1300,
      );

      await service.saveProduct(product);
      await service.updateProduct(product.copyWith(pricePesos: 1500));

      expect(store.productById('p-soda')?.pricePesos, 1500);
      expect(
        store.productById('p-soda')?.updatedAt.millisecondsSinceEpoch,
        isPositive,
      );
    });

    test('returns frequent products by sold count', () async {
      final store = CommerceStore.emptyForTest();
      final service = ProductCatalogService(store);
      await service.saveProduct(
        const Product(
          id: 'p-candy',
          name: 'Caramelo',
          stockUnits: 10,
          minStockUnits: 1,
          costPesos: 50,
          pricePesos: 100,
          soldCount: 2,
        ),
      );
      await service.saveProduct(
        const Product(
          id: 'p-cig',
          name: 'Cigarrillos',
          stockUnits: 10,
          minStockUnits: 1,
          costPesos: 1200,
          pricePesos: 1800,
          soldCount: 8,
        ),
      );

      final frequent = service.getFrequentProducts();

      expect(frequent.map((product) => product.id), ['p-cig', 'p-candy']);
    });
  });
}
