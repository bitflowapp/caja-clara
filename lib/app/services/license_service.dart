import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum LicenseStatus { trialActive, trialExpired, active }

enum LockedFeature {
  sales,
  expenses,
  catalog,
  stock,
  cash,
  restore,
  templates,
  demoData,
}

abstract class LicensePersistence {
  Future<Map<String, dynamic>?> load();

  Future<void> save(Map<String, dynamic> json);
}

class HiveLicensePersistence implements LicensePersistence {
  static const String _boxName = 'caja_clara_license';
  static const String _snapshotKey = 'state';

  @override
  Future<Map<String, dynamic>?> load() async {
    final box = await _openBox();
    final raw = box.get(_snapshotKey);
    if (raw is! Map) {
      return null;
    }
    return raw.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  @override
  Future<void> save(Map<String, dynamic> json) async {
    final box = await _openBox();
    await box.put(_snapshotKey, json);
  }

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return Hive.openBox<dynamic>(_boxName);
  }
}

class LicenseRestrictionException implements Exception {
  const LicenseRestrictionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LicenseService extends ChangeNotifier {
  LicenseService._(this._persistence, this._clock, this._enforceRestrictions);

  static const int trialDurationDays = 30;
  static const String salesEmail = String.fromEnvironment(
    'CAJA_CLARA_SALES_EMAIL',
  );
  static const String salesWhatsApp = String.fromEnvironment(
    'CAJA_CLARA_SALES_WHATSAPP',
  );
  static const String _activationSalt = 'CajaClaraWindows2026';

  static final LicenseService _fallbackInstance = LicenseService._fallback();

  final LicensePersistence _persistence;
  final DateTime Function() _clock;
  final bool _enforceRestrictions;

  bool _ready = false;
  String _installationId = '';
  DateTime? _trialStartedAt;
  String? _activationCode;
  DateTime? _activatedAt;

  static bool get _defaultEnforceRestrictions =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<LicenseService> loadOrCreate({
    LicensePersistence? persistence,
    DateTime Function()? clock,
    bool? enforceRestrictions,
  }) async {
    final service = LicenseService._(
      persistence ?? HiveLicensePersistence(),
      clock ?? DateTime.now,
      enforceRestrictions ?? _defaultEnforceRestrictions,
    );
    try {
      await service._load();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('LicenseService load failed: $error');
        debugPrintStack(stackTrace: stack);
      }
      service
        .._ready = true
        .._installationId = formatInstallationId(
          service._generateInstallationId(),
        )
        .._trialStartedAt = service._clock().toUtc()
        .._activationCode = null
        .._activatedAt = null;
    }
    return service;
  }

  @visibleForTesting
  factory LicenseService.forTest({
    LicensePersistence? persistence,
    DateTime Function()? clock,
    String? installationId,
    DateTime? trialStartedAt,
    String? activationCode,
    DateTime? activatedAt,
    bool enforceRestrictions = true,
  }) {
    final service = LicenseService._(
      persistence ?? _MemoryLicensePersistence(),
      clock ?? DateTime.now,
      enforceRestrictions,
    );
    service
      .._ready = true
      .._installationId = formatInstallationId(
        installationId ?? service._generateInstallationId(),
      )
      .._trialStartedAt = (trialStartedAt ?? service._clock()).toUtc()
      .._activationCode = service._readActivationCode(activationCode)
      .._activatedAt = activatedAt?.toUtc();
    return service;
  }

  LicenseService._fallback()
    : _persistence = _MemoryLicensePersistence(),
      _clock = DateTime.now,
      _enforceRestrictions = false {
    _ready = true;
    _installationId = 'CCW-DEMO-READ';
    _trialStartedAt = DateTime.now().toUtc();
    _activationCode = generateActivationCode(_installationId);
    _activatedAt = DateTime.now().toUtc();
  }

  bool get isReady => _ready;
  bool get shouldEnforceRestrictions => _enforceRestrictions;
  bool get shouldShowLicenseUi => _enforceRestrictions;
  String get installationId => _installationId;
  DateTime get trialStartedAt => _trialStartedAt ?? _clock().toUtc();
  DateTime get trialEndsAt =>
      trialStartedAt.add(const Duration(days: trialDurationDays));
  String? get activationCode => _activationCode;
  DateTime? get activatedAt => _activatedAt;
  bool get hasSalesEmail => salesEmail.trim().isNotEmpty;
  bool get hasSalesWhatsApp => salesWhatsApp.trim().isNotEmpty;

  LicenseStatus get status {
    if (!_enforceRestrictions) {
      return LicenseStatus.active;
    }
    if (isActivated) {
      return LicenseStatus.active;
    }
    if (!trialEndsAt.isAfter(_clock())) {
      return LicenseStatus.trialExpired;
    }
    return LicenseStatus.trialActive;
  }

  bool get isActivated =>
      _activationCode != null && validateActivationCode(_activationCode!);

  bool get isTrialActive => status == LicenseStatus.trialActive;
  bool get isTrialExpired => status == LicenseStatus.trialExpired;
  bool get isReadOnlyMode => _enforceRestrictions && isTrialExpired;

  int get trialDaysRemaining {
    if (!isTrialActive) {
      return 0;
    }
    final remainingMs = trialEndsAt.difference(_clock()).inMilliseconds;
    final days = (remainingMs / Duration.millisecondsPerDay).ceil();
    return days <= 0 ? 0 : days;
  }

  String get statusHeadline {
    switch (status) {
      case LicenseStatus.active:
        return 'Caja Clara Windows activa';
      case LicenseStatus.trialActive:
        return 'Prueba activa de Caja Clara Windows';
      case LicenseStatus.trialExpired:
        return 'Caja Clara Windows en modo solo lectura';
    }
  }

  String get statusDescription {
    switch (status) {
      case LicenseStatus.active:
        return 'La instalacion de Windows quedo activa para operar normalmente. La version web queda como demo o adicional, no como reemplazo de esta app local.';
      case LicenseStatus.trialActive:
        return 'Te quedan $trialDaysRemaining ${trialDaysRemaining == 1 ? 'dia' : 'dias'} de prueba. Puedes seguir operando normal y activar despues sin perder datos.';
      case LicenseStatus.trialExpired:
        return 'La prueba vencio. Puedes seguir viendo datos, exportando y haciendo backup, pero las funciones operativas quedan bloqueadas hasta activar.';
    }
  }

  String get positioningMessage {
    return 'Windows es el producto principal para operar todos los dias. GitHub Pages queda como demo, landing o adicional comercial.';
  }

  bool canUse(LockedFeature feature) {
    return !_enforceRestrictions || status != LicenseStatus.trialExpired;
  }

  String blockingMessage(LockedFeature feature) {
    final featureLabel = switch (feature) {
      LockedFeature.sales => 'registrar ventas',
      LockedFeature.expenses => 'registrar gastos',
      LockedFeature.catalog => 'agregar o editar productos',
      LockedFeature.stock => 'ajustar stock',
      LockedFeature.cash => 'gestionar caja',
      LockedFeature.restore => 'restaurar datos',
      LockedFeature.templates => 'cargar catalogo base',
      LockedFeature.demoData => 'cargar la demo comercial',
    };

    return 'La prueba de Caja Clara Windows vencio. Puedes seguir consultando tus datos, pero para $featureLabel necesitas activar la licencia.';
  }

  Future<void> activate(String rawCode) async {
    final normalized = normalizeActivationCode(rawCode);
    if (normalized.isEmpty) {
      throw StateError('Ingresa un codigo de activacion.');
    }
    if (!validateActivationCode(normalized)) {
      throw StateError(
        'El codigo de activacion no corresponde a esta instalacion.',
      );
    }

    _activationCode = formatActivationCode(normalized);
    _activatedAt = _clock().toUtc();
    await _persist();
    notifyListeners();
  }

  Future<void> _load() async {
    final snapshot = await _persistence.load();
    _installationId = formatInstallationId(
      snapshot?['installationId'] as String? ?? _generateInstallationId(),
    );
    _trialStartedAt =
        _readDate(snapshot?['trialStartedAt'])?.toUtc() ?? _clock().toUtc();
    _activationCode = _readActivationCode(snapshot?['activationCode']);
    _activatedAt = _readDate(snapshot?['activatedAt'])?.toUtc();
    _ready = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() {
    return _persistence.save(<String, dynamic>{
      'installationId': _installationId,
      'trialStartedAt': trialStartedAt.toUtc().toIso8601String(),
      'activationCode': _activationCode,
      'activatedAt': _activatedAt?.toUtc().toIso8601String(),
    });
  }

  String _generateInstallationId() {
    final random = Random.secure();
    final segments = List<String>.generate(3, (_) {
      final value = StringBuffer();
      for (var index = 0; index < 4; index++) {
        value.write(_alphaNumeric[random.nextInt(_alphaNumeric.length)]);
      }
      return value.toString();
    });
    return 'CCW-${segments.join('-')}';
  }

  static String formatInstallationId(String raw) {
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

  static String normalizeInstallationId(String? raw) {
    final normalized = (raw ?? '').toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (normalized.startsWith('CCW')) {
      return normalized;
    }
    return normalized.isEmpty ? '' : 'CCW$normalized';
  }

  static String generateActivationCode(String installationId) {
    final normalizedId = normalizeInstallationId(installationId);
    final hash = _fnv1a32('$normalizedId|$_activationSalt');
    final encoded = hash.toRadixString(36).toUpperCase().padLeft(8, '0');
    final compact = encoded.substring(encoded.length - 8);
    return 'CCW-${compact.substring(0, 4)}-${compact.substring(4, 8)}';
  }

  static String normalizeActivationCode(String? raw) {
    return (raw ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String formatActivationCode(String raw) {
    final normalized = normalizeActivationCode(raw);
    if (normalized.length < 11) {
      return raw.trim().toUpperCase();
    }
    final body = normalized.startsWith('CCW')
        ? normalized.substring(3)
        : normalized;
    final padded = body.padRight(8, '0');
    return 'CCW-${padded.substring(0, 4)}-${padded.substring(4, 8)}';
  }

  bool validateActivationCode(String rawCode) {
    final expected = normalizeActivationCode(
      generateActivationCode(_installationId),
    );
    return normalizeActivationCode(rawCode) == expected;
  }

  static LicenseService fallback() => _fallbackInstance;

  static int _fnv1a32(String input) {
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  DateTime? _readDate(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String? _readActivationCode(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    final normalized = formatActivationCode(raw);
    return validateActivationCode(normalized) ? normalized : null;
  }
}

class _MemoryLicensePersistence implements LicensePersistence {
  Map<String, dynamic>? _snapshot;

  @override
  Future<Map<String, dynamic>?> load() async => _snapshot;

  @override
  Future<void> save(Map<String, dynamic> json) async {
    _snapshot = Map<String, dynamic>.from(json);
  }
}

const String _alphaNumeric = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
