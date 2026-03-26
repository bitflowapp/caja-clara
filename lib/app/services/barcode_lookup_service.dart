import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'commerce_store.dart';

enum BarcodeLookupStatus { found, notFound, disabled, failed }

class BarcodeLookupMatch {
  const BarcodeLookupMatch({
    required this.barcode,
    required this.name,
    required this.sourceLabel,
    this.brand,
    this.suggestedCategory,
    this.imageUrl,
  });

  final String barcode;
  final String name;
  final String sourceLabel;
  final String? brand;
  final String? suggestedCategory;
  final String? imageUrl;

  String get seededName {
    final cleanName = name.trim();
    final cleanBrand = brand?.trim();
    if (cleanBrand == null || cleanBrand.isEmpty) {
      return cleanName;
    }
    final normalizedName = CommerceStore.normalizeProductName(cleanName);
    final normalizedBrand = CommerceStore.normalizeProductName(cleanBrand);
    if (normalizedName == null ||
        normalizedBrand == null ||
        normalizedName.contains(normalizedBrand)) {
      return cleanName;
    }
    return '$cleanBrand $cleanName';
  }
}

class BarcodeLookupResult {
  const BarcodeLookupResult._({required this.status, this.match, this.message});

  const BarcodeLookupResult.found(BarcodeLookupMatch match)
    : this._(status: BarcodeLookupStatus.found, match: match);

  const BarcodeLookupResult.notFound({String? message})
    : this._(status: BarcodeLookupStatus.notFound, message: message);

  const BarcodeLookupResult.disabled({String? message})
    : this._(status: BarcodeLookupStatus.disabled, message: message);

  const BarcodeLookupResult.failed({String? message})
    : this._(status: BarcodeLookupStatus.failed, message: message);

  final BarcodeLookupStatus status;
  final BarcodeLookupMatch? match;
  final String? message;

  bool get hasMatch => match != null;
}

abstract class BarcodeLookupService {
  const BarcodeLookupService();

  static const String _provider = String.fromEnvironment(
    'CAJA_CLARA_BARCODE_LOOKUP_PROVIDER',
    defaultValue: 'open_food_facts',
  );
  static const String _baseUrl = String.fromEnvironment(
    'CAJA_CLARA_BARCODE_LOOKUP_BASE_URL',
    defaultValue: 'https://world.openfoodfacts.org',
  );
  static const String _userAgent = String.fromEnvironment(
    'CAJA_CLARA_BARCODE_LOOKUP_USER_AGENT',
    defaultValue: 'CajaClara/0.1',
  );
  static const int _timeoutMs = int.fromEnvironment(
    'CAJA_CLARA_BARCODE_LOOKUP_TIMEOUT_MS',
    defaultValue: 2500,
  );

  factory BarcodeLookupService.fromEnvironment({http.Client? client}) {
    switch (_provider.trim().toLowerCase()) {
      case 'disabled':
      case 'local_only':
      case 'local-only':
        return const DisabledBarcodeLookupService();
      case 'open_food_facts':
      case 'openfoodfacts':
      case 'open-food-facts':
      default:
        return OpenFoodFactsBarcodeLookupService(
          client: client ?? http.Client(),
          baseUrl: _baseUrl,
          timeout: Duration(milliseconds: _timeoutMs),
          userAgent: _userAgent,
        );
    }
  }

  String get providerLabel;
  bool get isEnabled;

  Future<BarcodeLookupResult> lookup(String normalizedBarcode);
}

class DisabledBarcodeLookupService extends BarcodeLookupService {
  const DisabledBarcodeLookupService();

  @override
  String get providerLabel => 'Lookup externo desactivado';

  @override
  bool get isEnabled => false;

  @override
  Future<BarcodeLookupResult> lookup(String normalizedBarcode) async {
    return const BarcodeLookupResult.disabled(
      message:
          'El catalogo externo no esta activo en esta build. Puedes cargar el producto manualmente sin perder el codigo.',
    );
  }
}

class OpenFoodFactsBarcodeLookupService extends BarcodeLookupService {
  OpenFoodFactsBarcodeLookupService({
    required http.Client client,
    required this.baseUrl,
    required this.timeout,
    required this.userAgent,
  }) : _client = client;

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  final String userAgent;

  @override
  String get providerLabel => 'Open Food Facts';

  @override
  bool get isEnabled => true;

  @override
  Future<BarcodeLookupResult> lookup(String normalizedBarcode) async {
    final barcode = CommerceStore.normalizeBarcode(normalizedBarcode);
    if (barcode == null) {
      return const BarcodeLookupResult.notFound(
        message: 'Ingresa un codigo valido para buscar datos.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/v2/product/$barcode.json').replace(
      queryParameters: const <String, String>{
        'fields':
            'code,product_name,brands,categories,categories_tags,image_front_small_url',
      },
    );

    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode == 404) {
        return const BarcodeLookupResult.notFound(
          message:
              'No encontramos ese codigo en el catalogo externo. Puedes cargarlo manualmente.',
        );
      }
      if (response.statusCode == 429) {
        return const BarcodeLookupResult.failed(
          message:
              'El catalogo externo esta saturado ahora mismo. Puedes seguir con alta manual.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const BarcodeLookupResult.failed(
          message:
              'No pudimos consultar el catalogo externo ahora. Puedes seguir con alta manual.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const BarcodeLookupResult.failed(
          message:
              'La respuesta del catalogo externo no fue valida. Puedes seguir con alta manual.',
        );
      }

      final status = (decoded['status'] as num?)?.toInt() ?? 0;
      if (status != 1) {
        return const BarcodeLookupResult.notFound(
          message:
              'No encontramos ese codigo en el catalogo externo. Puedes cargarlo manualmente.',
        );
      }

      final product = (decoded['product'] as Map?)?.cast<String, dynamic>();
      if (product == null) {
        return const BarcodeLookupResult.notFound(
          message:
              'No encontramos datos confiables para este codigo. Puedes cargarlo manualmente.',
        );
      }

      final name = _cleanValue(product['product_name'] as String?);
      if (name == null) {
        return const BarcodeLookupResult.notFound(
          message:
              'El catalogo externo no devolvio un nombre confiable. Puedes cargarlo manualmente.',
        );
      }

      final brand = _firstCsvValue(product['brands'] as String?);
      final rawCategories = _cleanValue(product['categories'] as String?);
      final categoryTags =
          (product['categories_tags'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false);
      final suggestedCategory = _suggestCategory(
        categoryTags,
        rawCategories: rawCategories,
      );

      return BarcodeLookupResult.found(
        BarcodeLookupMatch(
          barcode: barcode,
          name: name,
          sourceLabel: providerLabel,
          brand: brand,
          suggestedCategory: suggestedCategory,
          imageUrl: _cleanValue(product['image_front_small_url'] as String?),
        ),
      );
    } on TimeoutException {
      return const BarcodeLookupResult.failed(
        message:
            'El catalogo externo tardo demasiado. Puedes seguir con alta manual.',
      );
    } catch (_) {
      return const BarcodeLookupResult.failed(
        message:
            'No pudimos consultar el catalogo externo ahora. Puedes seguir con alta manual.',
      );
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Accept': 'application/json'};
    final normalizedUserAgent = userAgent.trim();
    if (!kIsWeb && normalizedUserAgent.isNotEmpty) {
      headers['User-Agent'] = normalizedUserAgent;
    }
    return headers;
  }
}

String? _cleanValue(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _firstCsvValue(String? raw) {
  final value = _cleanValue(raw);
  if (value == null) {
    return null;
  }
  final parts = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return null;
  }
  return parts.first;
}

String? _suggestCategory(List<String> categoryTags, {String? rawCategories}) {
  final normalizedTags = categoryTags
      .map((tag) => tag.toLowerCase().trim())
      .toList(growable: false);
  final normalizedRaw = rawCategories?.toLowerCase() ?? '';

  bool matchesAny(Iterable<String> needles) {
    for (final needle in needles) {
      if (normalizedTags.any((tag) => tag.contains(needle)) ||
          normalizedRaw.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  if (matchesAny(<String>[
    'beverage',
    'drink',
    'water',
    'juice',
    'soda',
    'tea',
    'coffee',
    'boisson',
    'bebida',
  ])) {
    return 'Bebidas';
  }
  if (matchesAny(<String>[
    'cleaning',
    'detergent',
    'household',
    'laundry',
    'cleaner',
    'limpieza',
  ])) {
    return 'Limpieza';
  }
  if (matchesAny(<String>[
    'personal-care',
    'toothpaste',
    'shampoo',
    'deodorant',
    'cosmetic',
    'hygiene',
    'higiene',
  ])) {
    return 'Higiene';
  }
  if (matchesAny(<String>['pet', 'dog-food', 'cat-food', 'mascota'])) {
    return 'Mascotas';
  }
  if (matchesAny(<String>[
    'snack',
    'cookie',
    'biscuit',
    'chocolate',
    'candy',
    'sweet',
    'cereal',
    'rice',
    'pasta',
    'oil',
    'bread',
    'yogurt',
    'cheese',
    'sauce',
    'meal',
    'frozen',
    'aliment',
    'food',
    'almacen',
  ])) {
    return 'Almacen';
  }

  return null;
}
