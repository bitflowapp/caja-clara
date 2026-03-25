import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommerceStore barcode flow', () {
    test('allows creating a product with barcode and looking it up', () async {
      final store = CommerceStore.seededForTest();
      final product = Product(
        id: 'p-barcode',
        name: 'Arroz largo fino',
        stockUnits: 9,
        minStockUnits: 4,
        costPesos: 1800,
        pricePesos: 2900,
        category: 'Almacen',
        barcode: '7790000001111',
      );

      await store.addProduct(product);

      final found = store.productByBarcode('7790000001111');
      expect(found, isNotNull);
      expect(found!.id, 'p-barcode');
    });

    test('rejects duplicate barcode in different products', () async {
      final store = CommerceStore.seededForTest();

      await expectLater(
        store.addProduct(
          const Product(
            id: 'p-duplicate',
            name: 'Producto duplicado',
            stockUnits: 3,
            minStockUnits: 1,
            costPesos: 1000,
            pricePesos: 1500,
            barcode: '7791234500011',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('normalizes alphanumeric barcode lookups consistently', () async {
      final store = CommerceStore.emptyForTest();

      await store.addProduct(
        const Product(
          id: 'p-alpha',
          name: 'Cable de datos',
          stockUnits: 4,
          minStockUnits: 1,
          costPesos: 2100,
          pricePesos: 3900,
          barcode: ' abC123 ',
        ),
      );

      expect(store.productByBarcode('ABC123')?.id, 'p-alpha');
      expect(store.productByBarcode('abc123')?.id, 'p-alpha');
      expect(store.productByBarcode('  aBc123  ')?.barcode, 'ABC123');
    });

    test('returns null when barcode does not exist', () {
      final store = CommerceStore.seededForTest();

      expect(store.productByBarcode('0000000000000'), isNull);
    });

    test('records sale using looked-up barcode product', () async {
      final store = CommerceStore.seededForTest();
      final product = store.productByBarcode('7791234500028')!;
      final initialStock = product.stockUnits;
      final initialCash = store.cashBalancePesos;

      await store.recordSale(
        productId: product.id,
        quantityUnits: 2,
        paymentMethod: 'Efectivo',
      );

      expect(
        store.productByBarcode('7791234500028')!.stockUnits,
        initialStock - 2,
      );
      expect(store.cashBalancePesos, initialCash + (product.pricePesos * 2));
    });

    test('adds stock using looked-up barcode product', () async {
      final store = CommerceStore.seededForTest();
      final product = store.productByBarcode('7791234500035')!;
      final initialStock = product.stockUnits;
      final initialMovements = store.movements.length;

      await store.addStockToProduct(
        productId: product.id,
        quantityUnits: 5,
        note: 'Barcode',
      );

      expect(
        store.productByBarcode('7791234500035')!.stockUnits,
        initialStock + 5,
      );
      expect(store.movements.length, initialMovements + 1);
      expect(store.movements.first.title, 'Ingreso de stock');
    });
  });
}
