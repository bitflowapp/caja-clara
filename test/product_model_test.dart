import 'package:b_plus_commerce/app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product catalog helpers', () {
    test('exposes the expected catalog state flags', () {
      const complete = Product(
        id: 'complete',
        name: 'Agua mineral 500 ml',
        stockUnits: 4,
        minStockUnits: 1,
        costPesos: 500,
        pricePesos: 900,
        barcode: '7790000000001',
      );

      const incomplete = Product(
        id: 'incomplete',
        name: 'Producto pendiente',
        stockUnits: 0,
        minStockUnits: 1,
        costPesos: 100,
        pricePesos: 0,
      );

      expect(complete.hasPrice, isTrue);
      expect(complete.hasBarcode, isTrue);
      expect(complete.needsCatalogAttention, isFalse);
      expect(complete.isSellable, isTrue);
      expect(complete.isLowStock, isFalse);

      expect(incomplete.hasPrice, isFalse);
      expect(incomplete.hasBarcode, isFalse);
      expect(incomplete.needsCatalogAttention, isTrue);
      expect(incomplete.isSellable, isFalse);
      expect(incomplete.isLowStock, isTrue);
    });
  });
}
