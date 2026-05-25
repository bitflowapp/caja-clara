import 'dart:io';

// Internal developer-only helper. This file is not imported by production UI.
// Keep this algorithm in sync with LicenseService.generateActivationCode.
const String _activationSalt = 'CajaClaraWindows2026';

void main(List<String> args) {
  if (args.length != 1 || args.first == '-h' || args.first == '--help') {
    stderr.writeln(
      'Usage: dart run tool/generate_activation_code.dart <installation-id>',
    );
    exitCode = 64;
    return;
  }

  final installationId = formatInstallationId(args.single);
  final activationCode = generateActivationCode(installationId);

  stdout.writeln('Installation ID: $installationId');
  stdout.writeln('Activation code: $activationCode');
}

String generateActivationCode(String installationId) {
  final normalizedId = normalizeInstallationId(installationId);
  final hash = _fnv1a32('$normalizedId|$_activationSalt');
  final encoded = hash.toRadixString(36).toUpperCase().padLeft(8, '0');
  final compact = encoded.substring(encoded.length - 8);
  return 'CCW-${compact.substring(0, 4)}-${compact.substring(4, 8)}';
}

String formatInstallationId(String raw) {
  final normalized = normalizeInstallationId(raw);
  if (normalized.length < 11) {
    return raw.trim().isEmpty ? 'CCW-PEND-0000' : raw.trim().toUpperCase();
  }
  final body = normalized.startsWith('CCW')
      ? normalized.substring(3)
      : normalized;
  final padded = body.padRight(12, '0');
  return 'CCW-${padded.substring(0, 4)}-${padded.substring(4, 8)}-${padded.substring(8, 12)}';
}

String normalizeInstallationId(String? raw) {
  final normalized = (raw ?? '').toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]'),
    '',
  );
  if (normalized.startsWith('CCW')) {
    return normalized;
  }
  return normalized.isEmpty ? '' : 'CCW$normalized';
}

int _fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
