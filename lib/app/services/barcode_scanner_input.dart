import 'commerce_store.dart';

class BarcodeScannerInput {
  const BarcodeScannerInput._();

  static String? parseSubmitted(String rawInput) {
    return CommerceStore.normalizeBarcode(rawInput);
  }
}

class UsbBarcodeScannerBuffer {
  UsbBarcodeScannerBuffer({
    this.maxInterKeyDelay = const Duration(milliseconds: 90),
  });

  final Duration maxInterKeyDelay;
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastInputAt;

  void addCharacter(String character, {DateTime? at}) {
    if (character.isEmpty) {
      return;
    }
    final timestamp = at ?? DateTime.now();
    final previous = _lastInputAt;
    if (previous != null && timestamp.difference(previous) > maxInterKeyDelay) {
      clear();
    }
    _lastInputAt = timestamp;
    _buffer.write(character);
  }

  String? submit() {
    final parsed = BarcodeScannerInput.parseSubmitted(_buffer.toString());
    clear();
    return parsed;
  }

  void clear() {
    _buffer.clear();
    _lastInputAt = null;
  }
}
