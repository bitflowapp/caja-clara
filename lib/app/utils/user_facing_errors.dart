import '../services/store_lock.dart';

/// Convierte cualquier error en un mensaje claro para un usuario no técnico.
///
/// Nunca deja pasar texto técnico crudo (`PathAccessException`, errno, rutas
/// de archivos) a la pantalla.
String userFacingErrorMessage(
  Object error, {
  String fallback = 'No se pudo completar la acción.',
}) {
  // Errores de almacenamiento ya clasificados (lock, permisos, etc.).
  if (error is StoreAccessException) {
    return error.userMessage;
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return fallback;
  }

  final lower = raw.toLowerCase();

  // Bloqueo de archivo / otra instancia abierta: nunca mostrar el crudo.
  if (lower.contains('pathaccessexception') ||
      lower.contains('lock failed') ||
      lower.contains('errno = 33') ||
      lower.contains('lock violation') ||
      lower.contains('tiene bloqueada') ||
      lower.contains('sharing violation') ||
      lower.contains('being used by another process')) {
    return StoreAccessException(
      classifyStorageError(error),
      error,
    ).userMessage;
  }

  const prefixes = <String>['Bad state: ', 'FormatException: ', 'Exception: '];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) {
      final message = raw.substring(prefix.length).trim();
      return message.isEmpty ? fallback : message;
    }
  }

  if (lower.contains('access denied') ||
      lower.contains('permission denied') ||
      lower.contains('acceso denegado') ||
      lower.contains('no tiene acceso')) {
    return 'No hay permiso para completar la acción.';
  }
  if (lower.contains('no such file') || lower.contains('file not found')) {
    return 'No se encontró el archivo o la carpeta elegida.';
  }
  if (lower.contains('user canceled') || lower.contains('cancelled')) {
    return 'La acción fue cancelada.';
  }

  return raw;
}
