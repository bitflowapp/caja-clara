import 'package:flutter/foundation.dart';

/// Tipo de problema al acceder al almacenamiento local del store.
enum StoreAccessIssue {
  /// Otra ventana de Caja Clara tiene tomado el almacenamiento.
  anotherInstance,

  /// Windows no dio permiso sobre el archivo.
  permissionDenied,

  /// Bloqueo temporal: lo más probable es que se resuelva reintentando.
  temporary,

  /// Causa desconocida.
  unknown,
}

/// Error de acceso al almacenamiento, ya clasificado y con mensaje humano.
///
/// Nunca expone texto técnico crudo (`PathAccessException`, errno, rutas) en
/// pantalla: para eso está [userMessage].
class StoreAccessException implements Exception {
  StoreAccessException(this.issue, this.cause);

  /// Clasifica un error crudo de almacenamiento y lo envuelve.
  factory StoreAccessException.from(Object error) {
    if (error is StoreAccessException) {
      return error;
    }
    return StoreAccessException(classifyStorageError(error), error);
  }

  final StoreAccessIssue issue;
  final Object cause;

  /// Mensaje pensado para un comerciante, sin jerga técnica.
  String get userMessage {
    switch (issue) {
      case StoreAccessIssue.anotherInstance:
        return 'Caja Clara ya está abierta en otra ventana. '
            'Cerrá la otra ventana y tocá Reintentar.';
      case StoreAccessIssue.permissionDenied:
        return 'Windows no dio permiso para guardar en esta carpeta. '
            'Revisá los permisos de la carpeta y tocá Reintentar.';
      case StoreAccessIssue.temporary:
      case StoreAccessIssue.unknown:
        return 'No pudimos guardar este cambio. Tocá Reintentar. '
            'Tus datos anteriores siguen seguros.';
    }
  }

  @override
  String toString() => 'StoreAccessException($issue)';
}

/// Clasifica un error de almacenamiento crudo en un [StoreAccessIssue].
///
/// Reconoce los bloqueos típicos de Windows (ERROR_LOCK_VIOLATION = errno 33,
/// ERROR_SHARING_VIOLATION) y los errores de permisos (errno 5/13).
StoreAccessIssue classifyStorageError(Object error) {
  if (error is StoreAccessException) {
    return error.issue;
  }
  final text = error.toString().toLowerCase();

  // Archivo tomado por otro proceso / otra instancia de la app.
  const lockHints = <String>[
    'lock failed',
    'errno = 33',
    'errno=33',
    'lock violation',
    'tiene bloqueada',
    'being used by another process',
    'lo está usando otro proceso',
    'usado por otro proceso',
    'siendo utilizado por otro proceso',
    'sharing violation',
  ];
  for (final hint in lockHints) {
    if (text.contains(hint)) {
      return StoreAccessIssue.anotherInstance;
    }
  }

  // Permisos insuficientes sobre el archivo o la carpeta.
  const permissionHints = <String>[
    'access is denied',
    'access denied',
    'permission denied',
    'no tiene acceso',
    'acceso denegado',
    'errno = 5',
    'errno = 13',
  ];
  for (final hint in permissionHints) {
    if (text.contains(hint)) {
      return StoreAccessIssue.permissionDenied;
    }
  }

  return StoreAccessIssue.unknown;
}

/// Backoff por defecto entre reintentos (corto: Windows suele liberar rápido).
const List<Duration> kStorageRetryBackoff = <Duration>[
  Duration(milliseconds: 120),
  Duration(milliseconds: 280),
  Duration(milliseconds: 600),
];

/// Ejecuta [action] reintentando con backoff corto ante bloqueos temporales.
///
/// - Un lock que se libera entre intentos (lock viejo/stale, bloqueo temporal
///   de Windows) se resuelve solo: el reintento termina funcionando.
/// - Un lock que sigue tomado hasta el final se reporta como
///   [StoreAccessIssue.anotherInstance].
/// - Un error de permisos no se reintenta (no tiene sentido) y se reporta de
///   inmediato.
Future<T> runWithStorageRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 4,
  List<Duration> backoff = kStorageRetryBackoff,
}) async {
  assert(maxAttempts >= 1);
  Object lastError = StateError('runWithStorageRetry: sin intentos');

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      final issue = classifyStorageError(error);

      // Los permisos no se arreglan reintentando.
      if (issue == StoreAccessIssue.permissionDenied) {
        throw StoreAccessException(issue, error);
      }

      final isLastAttempt = attempt == maxAttempts - 1;
      if (isLastAttempt) {
        // Si quedó tomado hasta el final, hay otra instancia activa.
        // Un error desconocido se reporta como temporal (reintentable).
        throw StoreAccessException(
          issue == StoreAccessIssue.unknown
              ? StoreAccessIssue.temporary
              : issue,
          error,
        );
      }

      if (kDebugMode) {
        debugPrint('Storage retry ${attempt + 1}/$maxAttempts ($issue)');
      }
      final waitFor = attempt < backoff.length
          ? backoff[attempt]
          : backoff.isEmpty
          ? Duration.zero
          : backoff.last;
      await Future<void>.delayed(waitFor);
    }
  }

  // Inalcanzable: el bucle siempre retorna o lanza. Defensivo.
  throw StoreAccessException(StoreAccessIssue.unknown, lastError);
}
