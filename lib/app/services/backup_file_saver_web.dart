import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'backup_file_saver.dart';

class WebBackupFileSaver implements BackupFileSaver {
  @override
  Future<BackupSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    final blob = web.Blob(
      <web.BlobPart>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = suggestedName
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);

    return const BackupSaveResult(
      disposition: BackupSaveDisposition.downloaded,
    );
  }
}

BackupFileSaver buildBackupFileSaver() => WebBackupFileSaver();
