import 'package:b_plus_commerce/app/services/barcode_scanner_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarcodeScannerInput', () {
    test('normalizes keyboard-wedge submitted barcode', () {
      expect(BarcodeScannerInput.parseSubmitted(' 779-001  '), '779001');
      expect(BarcodeScannerInput.parseSubmitted('abc 123'), 'ABC123');
    });

    test('returns null for empty submissions', () {
      expect(BarcodeScannerInput.parseSubmitted('   '), isNull);
    });
  });

  group('UsbBarcodeScannerBuffer', () {
    test('captures fast input ending with submit', () {
      final buffer = UsbBarcodeScannerBuffer();
      final start = DateTime(2026);

      buffer
        ..addCharacter('7', at: start)
        ..addCharacter('7', at: start.add(const Duration(milliseconds: 20)))
        ..addCharacter('9', at: start.add(const Duration(milliseconds: 40)));

      expect(buffer.submit(), '779');
    });

    test('clears stale slow input before continuing', () {
      final buffer = UsbBarcodeScannerBuffer();
      final start = DateTime(2026);

      buffer
        ..addCharacter('1', at: start)
        ..addCharacter('2', at: start.add(const Duration(milliseconds: 200)))
        ..addCharacter('3', at: start.add(const Duration(milliseconds: 220)));

      expect(buffer.submit(), '23');
    });
  });
}
