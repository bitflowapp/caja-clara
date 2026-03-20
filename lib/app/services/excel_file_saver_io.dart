import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'excel_file_saver.dart';

class IoExcelFileSaver implements ExcelFileSaver {
  static const XTypeGroup _excelTypeGroup = XTypeGroup(
    label: 'Excel',
    extensions: <String>['xlsx'],
  );

  @override
  Future<ExcelSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      confirmButtonText: 'Guardar',
      acceptedTypeGroups: const <XTypeGroup>[_excelTypeGroup],
    );

    if (location == null) {
      return const ExcelSaveResult(
        disposition: ExcelSaveDisposition.cancelled,
      );
    }

    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);

    return ExcelSaveResult(
      disposition: ExcelSaveDisposition.saved,
      path: file.path,
    );
  }
}

ExcelFileSaver buildExcelFileSaver() => IoExcelFileSaver();
