import 'dart:convert';

import 'package:b_plus_commerce/app/services/barcode_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenFoodFactsBarcodeLookupService', () {
    test('maps external product data into assisted autofill', () async {
      final service = OpenFoodFactsBarcodeLookupService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/product/3274080005003.json');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 1,
              'product': <String, dynamic>{
                'product_name': 'Eau De Source',
                'brands': 'Cristaline',
                'categories': 'Boissons,Eaux',
                'categories_tags': <String>['en:beverages', 'en:waters'],
              },
            }),
            200,
          );
        }),
        baseUrl: 'https://world.openfoodfacts.org',
        timeout: const Duration(seconds: 1),
        userAgent: 'CajaClara/0.1',
      );

      final result = await service.lookup('3274080005003');

      expect(result.status, BarcodeLookupStatus.found);
      expect(result.match?.name, 'Eau De Source');
      expect(result.match?.brand, 'Cristaline');
      expect(result.match?.suggestedCategory, 'Bebidas');
      expect(result.match?.seededName, 'Cristaline Eau De Source');
    });

    test('falls back cleanly when provider has no match', () async {
      final service = OpenFoodFactsBarcodeLookupService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 0,
              'status_verbose': 'product not found',
            }),
            200,
          );
        }),
        baseUrl: 'https://world.openfoodfacts.org',
        timeout: const Duration(seconds: 1),
        userAgent: 'CajaClara/0.1',
      );

      final result = await service.lookup('0000000000000');

      expect(result.status, BarcodeLookupStatus.notFound);
      expect(result.match, isNull);
      expect(result.message, contains('Puedes cargarlo manualmente'));
    });

    test(
      'reports external failures without blocking manual fallback',
      () async {
        final service = OpenFoodFactsBarcodeLookupService(
          client: MockClient((request) async {
            throw Exception('network down');
          }),
          baseUrl: 'https://world.openfoodfacts.org',
          timeout: const Duration(seconds: 1),
          userAgent: 'CajaClara/0.1',
        );

        final result = await service.lookup('7791234500011');

        expect(result.status, BarcodeLookupStatus.failed);
        expect(result.match, isNull);
        expect(result.message, contains('alta manual'));
      },
    );
  });

  test('disabled lookup service keeps flow honest', () async {
    const service = DisabledBarcodeLookupService();

    final result = await service.lookup('7791234500011');

    expect(result.status, BarcodeLookupStatus.disabled);
    expect(result.message, contains('no esta activo'));
  });
}
