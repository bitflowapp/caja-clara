import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'backup_file_saver.dart';
import 'commerce_store.dart';

class BackupExportResult {
  const BackupExportResult({
    required this.disposition,
    required this.fileName,
    this.path,
  });

  final BackupSaveDisposition disposition;
  final String fileName;
  final String? path;

  bool get saved => disposition == BackupSaveDisposition.saved;
  bool get downloaded => disposition == BackupSaveDisposition.downloaded;
}

class BackupImportData {
  const BackupImportData({
    required this.snapshot,
    required this.fileName,
  });

  final Map<String, dynamic> snapshot;
  final String fileName;
}

class BackupService {
  BackupService({BackupFileSaver? fileSaver})
      : _fileSaver = fileSaver ?? createBackupFileSaver();

  final BackupFileSaver _fileSaver;

  static const XTypeGroup _jsonTypeGroup = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json'],
  );

  Future<BackupExportResult> exportBackup(
    CommerceStore store, {
    DateTime? now,
  }) async {
    final exportAt = now ?? DateTime.now();
    final fileName = buildSuggestedFileName(exportAt);
    final bytes = buildBackupBytes(store, generatedAt: exportAt);
    final saveResult = await _fileSaver.save(
      bytes: bytes,
      suggestedName: fileName,
    );

    return BackupExportResult(
      disposition: saveResult.disposition,
      fileName: fileName,
      path: saveResult.path,
    );
  }

  Future<BackupImportData?> pickBackupToImport() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_jsonTypeGroup],
      confirmButtonText: 'Abrir backup',
    );
    if (file == null) {
      return null;
    }

    final content = await file.readAsString();
    final snapshot = parseBackupJson(content);

    return BackupImportData(
      snapshot: snapshot,
      fileName: file.name,
    );
  }

  @visibleForTesting
  Uint8List buildBackupBytes(
    CommerceStore store, {
    required DateTime generatedAt,
  }) {
    final json = buildBackupJson(store, generatedAt: generatedAt);
    return Uint8List.fromList(utf8.encode(json));
  }

  @visibleForTesting
  String buildBackupJson(
    CommerceStore store, {
    required DateTime generatedAt,
  }) {
    final snapshot = <String, dynamic>{
      'backupGeneratedAt': generatedAt.toIso8601String(),
      ...store.buildSnapshot(generatedAt: generatedAt),
    };
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  @visibleForTesting
  Map<String, dynamic> parseBackupJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('El archivo no contiene un backup valido.');
    }
    return decoded.cast<String, dynamic>();
  }

  @visibleForTesting
  String buildSuggestedFileName(DateTime generatedAt) {
    final suffix = DateFormat('yyyy-MM-dd_HH-mm').format(generatedAt);
    return 'caja_clara_backup_$suffix.json';
  }
}
