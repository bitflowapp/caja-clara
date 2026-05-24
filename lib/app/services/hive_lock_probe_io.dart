import 'dart:io';

import 'store_lock.dart';

Future<void> assertHiveLockAvailable({
  required String boxName,
  required String? hivePath,
}) async {
  final basePath = hivePath?.trim();
  if (basePath == null || basePath.isEmpty) {
    return;
  }

  RandomAccessFile? raf;
  try {
    final lockFile = File(_joinPath(basePath, '${boxName.toLowerCase()}.lock'));
    if (!lockFile.parent.existsSync()) {
      lockFile.parent.createSync(recursive: true);
    }
    raf = lockFile.openSync(mode: FileMode.append);
    raf.lockSync(FileLock.exclusive);
    raf.unlockSync();
  } catch (error) {
    throw StoreAccessException(classifyStorageError(error), error);
  } finally {
    try {
      raf?.closeSync();
    } catch (_) {
      // Best-effort cleanup for a short-lived lock probe.
    }
  }
}

String _joinPath(String directory, String fileName) {
  final separator = Platform.pathSeparator;
  final cleanDirectory = directory.endsWith(separator)
      ? directory.substring(0, directory.length - separator.length)
      : directory;
  return '$cleanDirectory$separator$fileName';
}
