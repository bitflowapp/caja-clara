import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'backup_file_saver.dart';

class IoBackupFileSaver implements BackupFileSaver {
  static const XTypeGroup _jsonTypeGroup = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json'],
  );

  @override
  Future<BackupSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      confirmButtonText: 'Guardar',
      acceptedTypeGroups: const <XTypeGroup>[_jsonTypeGroup],
    );

    if (location == null) {
      return const BackupSaveResult(
        disposition: BackupSaveDisposition.cancelled,
      );
    }

    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);

    return BackupSaveResult(
      disposition: BackupSaveDisposition.saved,
      path: file.path,
    );
  }
}

BackupFileSaver buildBackupFileSaver() => IoBackupFileSaver();
