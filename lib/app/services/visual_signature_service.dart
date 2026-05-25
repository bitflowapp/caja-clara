import 'dart:typed_data';

import '../models/product.dart';

class VisualProductMatch {
  const VisualProductMatch({
    required this.product,
    required this.confidence,
    required this.distance,
  });

  final Product product;
  final double confidence;
  final int distance;

  bool get isHighConfidence =>
      confidence >= VisualSignatureService.highConfidenceThreshold;
}

class VisualSignatureService {
  const VisualSignatureService._();

  static const int binCount = 16;
  static const int maxBinValue = 255;
  static const double highConfidenceThreshold = 0.92;

  static String generate(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }

    final bins = List<int>.filled(binCount, 0);
    for (final byte in bytes) {
      bins[byte >> 4] += 1;
    }

    final maxCount = bins.reduce((a, b) => a > b ? a : b);
    final normalized = bins
        .map((count) => ((count / maxCount) * maxBinValue).round())
        .toList(growable: false);

    return 'v1:${normalized.map(_toHexByte).join()}';
  }

  static VisualProductMatch? bestMatch(
    String signature,
    Iterable<Product> products, {
    double minConfidence = highConfidenceThreshold,
  }) {
    VisualProductMatch? best;
    for (final product in products) {
      final storedSignature = product.visualSignature;
      if (storedSignature == null || storedSignature.trim().isEmpty) {
        continue;
      }
      final confidence = compare(signature, storedSignature);
      final distance = distanceBetween(signature, storedSignature);
      if (best == null || confidence > best.confidence) {
        best = VisualProductMatch(
          product: product,
          confidence: confidence,
          distance: distance,
        );
      }
    }

    if (best == null || best.confidence < minConfidence) {
      return null;
    }
    return best;
  }

  static double compare(String left, String right) {
    final distance = distanceBetween(left, right);
    if (distance == _maxDistance) {
      return 0;
    }
    final confidence = 1 - (distance / _maxDistance);
    return confidence.clamp(0, 1).toDouble();
  }

  static int distanceBetween(String left, String right) {
    final leftBins = _parse(left);
    final rightBins = _parse(right);
    if (leftBins == null || rightBins == null) {
      return _maxDistance;
    }

    var distance = 0;
    for (var index = 0; index < binCount; index += 1) {
      distance += (leftBins[index] - rightBins[index]).abs();
    }
    return distance;
  }

  static const int _maxDistance = binCount * maxBinValue;

  static List<int>? _parse(String signature) {
    final value = signature.trim();
    if (!value.startsWith('v1:')) {
      return null;
    }
    final payload = value.substring(3);
    if (payload.length != binCount * 2) {
      return null;
    }

    final bins = <int>[];
    for (var index = 0; index < payload.length; index += 2) {
      final parsed = int.tryParse(
        payload.substring(index, index + 2),
        radix: 16,
      );
      if (parsed == null) {
        return null;
      }
      bins.add(parsed);
    }
    return bins;
  }

  static String _toHexByte(int value) {
    final clamped = value.clamp(0, maxBinValue);
    return clamped.toRadixString(16).padLeft(2, '0');
  }
}
