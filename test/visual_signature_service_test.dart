import 'dart:typed_data';

import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/visual_signature_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VisualSignatureService', () {
    test('generates a deterministic local signature', () {
      final bytes = Uint8List.fromList(<int>[0, 1, 2, 240, 241, 242]);

      final first = VisualSignatureService.generate(bytes);
      final second = VisualSignatureService.generate(bytes);

      expect(first, second);
      expect(first, startsWith('v1:'));
    });

    test('returns high-confidence suggestion for matching signature', () {
      final signature = VisualSignatureService.generate(
        Uint8List.fromList(List<int>.filled(32, 12)),
      );
      final product = Product(
        id: 'p-photo',
        name: 'Galletitas',
        stockUnits: 4,
        minStockUnits: 1,
        costPesos: 600,
        pricePesos: 1200,
        visualSignature: signature,
      );

      final match = VisualSignatureService.bestMatch(signature, <Product>[
        product,
      ]);

      expect(match, isNotNull);
      expect(match!.product.id, 'p-photo');
      expect(match.isHighConfidence, isTrue);
    });

    test('does not return low-confidence visual match', () {
      final storedSignature = VisualSignatureService.generate(
        Uint8List.fromList(List<int>.filled(32, 0)),
      );
      final querySignature = VisualSignatureService.generate(
        Uint8List.fromList(List<int>.filled(32, 255)),
      );
      final product = Product(
        id: 'p-other',
        name: 'Lavandina',
        stockUnits: 4,
        minStockUnits: 1,
        costPesos: 700,
        pricePesos: 1300,
        visualSignature: storedSignature,
      );

      final match = VisualSignatureService.bestMatch(querySignature, <Product>[
        product,
      ]);

      expect(match, isNull);
    });
  });
}
