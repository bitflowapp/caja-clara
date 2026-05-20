import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'store_lock.dart';

/// Persistencia local del store sobre Hive.
///
/// Toda apertura/lectura/escritura pasa por [runWithStorageRetry], de modo que
/// un bloqueo temporal de Windows o un lock viejo que se libera se resuelven
/// solos, y un lock que sigue tomado se reporta como [StoreAccessException].
class CommercePersistence {
  static const String _boxName = 'b_plus_commerce';
  static const String _snapshotKey = 'snapshot';

  Future<Map<String, dynamic>?> load() async {
    return runWithStorageRetry<Map<String, dynamic>?>(() async {
      final box = await _openBox();
      final raw = box.get(_snapshotKey);
      if (raw is Map) {
        return raw.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }
      return null;
    });
  }

  Future<void> save(Map<String, dynamic> json) async {
    await runWithStorageRetry<void>(() async {
      final box = await _openBox();
      await box.put(_snapshotKey, json);
      await box.flush();
    });
  }

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return Hive.openBox<dynamic>(_boxName);
  }
}
