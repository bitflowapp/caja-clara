const String defaultSalePaymentMethod = 'Efectivo';
const String unknownPaymentMethod = 'Sin dato';

const List<String> supportedSalePaymentMethods = <String>[
  defaultSalePaymentMethod,
  'Debito',
  'Transferencia',
];

String normalizeStoredPaymentMethod(
  String? raw, {
  String fallback = unknownPaymentMethod,
}) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String resolveSalePaymentMethodSelection(String? raw) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? defaultSalePaymentMethod : trimmed;
}

List<String> salePaymentMethodOptions({String? selectedValue}) {
  final options = List<String>.of(supportedSalePaymentMethods, growable: true);
  final normalizedSelected = (selectedValue ?? '').trim();
  if (normalizedSelected.isNotEmpty && !options.contains(normalizedSelected)) {
    options.add(normalizedSelected);
  }
  return options;
}
