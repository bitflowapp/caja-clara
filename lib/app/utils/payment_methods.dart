const String defaultSalePaymentMethod = 'Efectivo';
const String unknownPaymentMethod = 'Sin definir';

const List<String> supportedSalePaymentMethods = <String>[
  defaultSalePaymentMethod,
  'Transferencia',
  'Mercado Pago',
  'Debito',
  'Credito',
  'Cuenta corriente',
];

String normalizeStoredPaymentMethod(
  String? raw, {
  String fallback = unknownPaymentMethod,
}) {
  final canonical = _canonicalPaymentMethod(raw);
  return canonical ?? fallback;
}

String resolveSalePaymentMethodSelection(String? raw) {
  return _canonicalPaymentMethod(raw) ?? defaultSalePaymentMethod;
}

List<String> salePaymentMethodOptions({String? selectedValue}) {
  final options = List<String>.of(supportedSalePaymentMethods, growable: true);
  final normalizedSelected = displayPaymentMethodLabel(
    selectedValue,
    fallback: '',
  );
  if (normalizedSelected.isNotEmpty && !options.contains(normalizedSelected)) {
    options.add(normalizedSelected);
  }
  return options;
}

String displayPaymentMethodLabel(
  String? raw, {
  String fallback = unknownPaymentMethod,
}) {
  final canonical = _canonicalPaymentMethod(raw);
  if (canonical != null) {
    return canonical;
  }
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String? _canonicalPaymentMethod(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final normalized = _normalizePaymentKey(trimmed);
  return switch (normalized) {
    'efectivo' => 'Efectivo',
    'transferencia' => 'Transferencia',
    'mercado pago' || 'mercadopago' => 'Mercado Pago',
    'debito' => 'Debito',
    'credito' => 'Credito',
    'cuenta corriente' || 'cuentacorriente' || 'fiado' => 'Cuenta corriente',
    _ => trimmed,
  };
}

String _normalizePaymentKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'\s+'), ' ');
}
