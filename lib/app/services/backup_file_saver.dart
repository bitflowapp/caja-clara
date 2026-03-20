import 'dart:typed_data';

import 'backup_file_saver_io.dart'
    if (dart.library.html) 'backup_file_saver_web.dart';

enum BackupSaveDisposition { saved, downloaded, cancelled }

class BackupSaveResult {
  const BackupSaveResult({
    required this.disposition,
    this.path,
  });

  final BackupSaveDisposition disposition;
  final String? path;
}

abstract class BackupFileSaver {
  Future<BackupSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
  });
}

BackupFileSaver createBackupFileSaver() => buildBackupFileSaver();
