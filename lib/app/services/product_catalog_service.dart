import '../models/product.dart';
import 'commerce_store.dart';
import 'visual_signature_service.dart';

class ProductCatalogService {
  const ProductCatalogService(this._store);

  final CommerceStore _store;

  Product? findByBarcode(String barcode) => _store.productByBarcode(barcode);

  List<Product> searchByName(String query, {int limit = 20}) {
    final normalizedQuery = CommerceStore.normalizeProductName(query);
    if (normalizedQuery == null) {
      return <Product>[];
    }

    final exact = _store.productByNormalizedName(query);
    final results = <Product>[];
    if (exact != null) {
      results.add(exact);
    }

    for (final product in _store.products) {
      if (results.any((item) => item.id == product.id)) {
        continue;
      }
      final normalizedName = CommerceStore.normalizeProductName(product.name);
      if (normalizedName != null && normalizedName.contains(normalizedQuery)) {
        results.add(product);
      }
      if (results.length >= limit) {
        break;
      }
    }

    return results.take(limit).toList(growable: false);
  }

  Future<void> saveProduct(Product product) => _store.addProduct(product);

  Future<void> updateProduct(Product product) => _store.addProduct(product);

  List<Product> getFavorites({int limit = 12}) {
    final products = _store.products
        .where((product) => product.isFavorite)
        .toList(growable: false);
    products.sort(_sortQuickProducts);
    return products.take(limit).toList(growable: false);
  }

  List<Product> getFrequentProducts({int limit = 12}) {
    final products = _store.products
        .where((product) => product.soldCount > 0)
        .toList(growable: false);
    products.sort(_sortQuickProducts);
    return products.take(limit).toList(growable: false);
  }

  VisualProductMatch? bestVisualMatch(
    String signature, {
    double minConfidence = VisualSignatureService.highConfidenceThreshold,
  }) {
    return VisualSignatureService.bestMatch(
      signature,
      _store.products,
      minConfidence: minConfidence,
    );
  }

  static int _sortQuickProducts(Product left, Product right) {
    final bySales = right.soldCount.compareTo(left.soldCount);
    if (bySales != 0) {
      return bySales;
    }
    if (left.isFavorite != right.isFavorite) {
      return left.isFavorite ? -1 : 1;
    }
    return left.name.compareTo(right.name);
  }
}
