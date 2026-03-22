import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'excel_file_saver.dart';

class WebExcelFileSaver implements ExcelFileSaver {
  @override
  Future<ExcelSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    final blob = web.Blob(
      <web.BlobPart>[bytes.toJS].toJS,
      web.BlobPropertyBag(
        type:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = suggestedName
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    Timer(const Duration(seconds: 1), () {
      anchor.remove();
      web.URL.revokeObjectURL(url);
    });

    return const ExcelSaveResult(disposition: ExcelSaveDisposition.downloaded);
  }
}

ExcelFileSaver buildExcelFileSaver() => WebExcelFileSaver();
