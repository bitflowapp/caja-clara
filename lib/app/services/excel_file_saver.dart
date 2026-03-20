import 'dart:typed_data';

import 'excel_file_saver_io.dart'
    if (dart.library.html) 'excel_file_saver_web.dart';

enum ExcelSaveDisposition { saved, downloaded, cancelled }

class ExcelSaveResult {
  const ExcelSaveResult({
    required this.disposition,
    this.path,
  });

  final ExcelSaveDisposition disposition;
  final String? path;
}

abstract class ExcelFileSaver {
  Future<ExcelSaveResult> save({
    required Uint8List bytes,
    required String suggestedName,
  });
}

ExcelFileSaver createExcelFileSaver() => buildExcelFileSaver();
