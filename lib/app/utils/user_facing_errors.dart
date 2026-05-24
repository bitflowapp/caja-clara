import '../services/store_lock.dart';

String userFacingErrorMessage(
  Object error, {
  String fallback = 'No se pudo completar la accion.',
}) {
  if (error is StoreAccessException) {
    return error.userMessage;
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return fallback;
  }

  final storageIssue = classifyStorageError(error);
  if (storageIssue != StoreAccessIssue.unknown) {
    return StoreAccessException(storageIssue, error).userMessage;
  }

  const prefixes = <String>['Bad state: ', 'FormatException: ', 'Exception: '];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) {
      final message = raw.substring(prefix.length).trim();
      return message.isEmpty ? fallback : message;
    }
  }

  final lower = raw.toLowerCase();
  if (lower.contains('access denied') || lower.contains('permission denied')) {
    return 'No hay permiso para completar la accion.';
  }
  if (lower.contains('no such file') || lower.contains('file not found')) {
    return 'No se encontro el archivo o la carpeta elegida.';
  }
  if (lower.contains('user canceled') || lower.contains('cancelled')) {
    return 'La accion fue cancelada.';
  }

  return raw;
}
