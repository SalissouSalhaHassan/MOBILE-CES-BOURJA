import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineStoreManager {
  static const String boxStudents = 'students_cache';
  static const String boxStudentFees = 'student_fees_cache';
  static const String boxFeePayments = 'fee_payments_cache';
  static const String boxStudentResults = 'student_results_cache';
  static const String boxClassSubjects = 'class_subjects_cache';
  static const String boxSchoolSessions = 'school_sessions_cache';
  static const String boxAcademicPeriods = 'academic_periods_cache';
  static const String boxAttendance = 'attendance_cache';

  final List<String> _boxes = [
    boxStudents,
    boxStudentFees,
    boxFeePayments,
    boxStudentResults,
    boxClassSubjects,
    boxSchoolSessions,
    boxAcademicPeriods,
    boxAttendance,
  ];

  /// Get raw Hive box by name safely
  Box getBox(String boxName) {
    return Hive.box(boxName);
  }

  /// Initialize all boxes
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      
      for (var boxName in _boxes) {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox(boxName);
        }
      }
      debugPrint("✅ OfflineStoreManager: All Hive boxes initialized successfully.");
    } catch (e) {
      debugPrint("❌ OfflineStoreManager Initialization Error: $e");
    }
  }

  /// Save raw JSON data list for a specific key in a box
  Future<void> saveDataList({
    required String boxName,
    required String key,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      final box = Hive.box(boxName);
      // Clean maps to ensure they are compatible with Hive (deep convert keys if necessary)
      final cleanData = data.map((item) => _cleanMap(item)).toList();
      await box.put(key, cleanData);
      debugPrint("💾 Cache Saved -> Box: $boxName, Key: $key, Count: ${data.length}");
    } catch (e) {
      debugPrint("❌ Error saving data list in box $boxName: $e");
    }
  }

  /// Save raw JSON data map for a specific key in a box
  Future<void> saveMap({
    required String boxName,
    required String key,
    required Map<String, dynamic> data,
  }) async {
    try {
      final box = Hive.box(boxName);
      final cleanData = _cleanMap(data);
      await box.put(key, cleanData);
      debugPrint("💾 Cache Map Saved -> Box: $boxName, Key: $key");
    } catch (e) {
      debugPrint("❌ Error saving map in box $boxName: $e");
    }
  }

  /// Get cached data map for a specific key
  Map<String, dynamic>? getMap({
    required String boxName,
    required String key,
  }) {
    try {
      if (!Hive.isBoxOpen(boxName)) return null;
      final box = Hive.box(boxName);
      final rawData = box.get(key);
      if (rawData == null) return null;
      if (rawData is Map) {
        return _cleanMap(rawData);
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error reading map from box $boxName: $e");
      return null;
    }
  }

  /// Get cached data list for a specific key
  List<Map<String, dynamic>> getDataList({
    required String boxName,
    required String key,
  }) {
    try {
      if (!Hive.isBoxOpen(boxName)) return [];
      final box = Hive.box(boxName);
      final rawData = box.get(key);
      if (rawData == null) return [];

      if (rawData is List) {
        return rawData.map((item) {
          if (item is Map) {
            return _cleanMap(item);
          }
          return <String, dynamic>{};
        }).where((element) => element.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ Error reading data list from box $boxName: $e");
      return [];
    }
  }

  /// Merge delta updates into existing cached list by matching 'id'
  Future<void> mergeDeltaList({
    required String boxName,
    required String key,
    required List<Map<String, dynamic>> updatedItems,
  }) async {
    if (updatedItems.isEmpty) return;
    try {
      final currentList = getDataList(boxName: boxName, key: key);
      final Map<dynamic, Map<String, dynamic>> mapById = {};

      for (final item in currentList) {
        final id = item['id']?.toString();
        if (id != null) {
          mapById[id] = item;
        }
      }

      // Upsert updated/new records
      for (final item in updatedItems) {
        final id = item['id']?.toString();
        if (id != null) {
          mapById[id] = item;
        } else {
          currentList.add(item);
        }
      }

      final mergedList = mapById.values.toList();
      await saveDataList(boxName: boxName, key: key, data: mergedList);
      debugPrint("🔄 Delta Merged -> Box: $boxName, Key: $key, Added/Updated: ${updatedItems.length}, Total: ${mergedList.length}");
    } catch (e) {
      debugPrint("❌ Error merging delta list in box $boxName: $e");
    }
  }

  /// Remove deleted items from cached list by IDs
  Future<void> deleteItemsByIds({
    required String boxName,
    required String key,
    required List<dynamic> deletedIds,
  }) async {
    if (deletedIds.isEmpty) return;
    try {
      final currentList = getDataList(boxName: boxName, key: key);
      final idSet = deletedIds.map((e) => e.toString()).toSet();

      final filtered = currentList.where((item) {
        final itemId = item['id']?.toString();
        return itemId == null || !idSet.contains(itemId);
      }).toList();

      await saveDataList(boxName: boxName, key: key, data: filtered);
      debugPrint("🗑️ Delta Deleted -> Box: $boxName, Key: $key, Removed: ${currentList.length - filtered.length}");
    } catch (e) {
      debugPrint("❌ Error deleting items by IDs in box $boxName: $e");
    }
  }

  /// Clear a specific cache box
  Future<void> clearBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
      }
    } catch (e) {
      debugPrint("❌ Error clearing box $boxName: $e");
    }
  }

  /// Clear all cached data boxes (used when switching servers)
  Future<void> clearAllData() async {
    for (var boxName in _boxes) {
      await clearBox(boxName);
    }
    debugPrint("🧹 All offline cache boxes cleared successfully.");
  }

  /// Prune old synced history entries older than [maxAge] to optimize device storage
  Future<void> pruneOldSyncedPayments({Duration maxAge = const Duration(days: 45)}) async {
    try {
      if (!Hive.isBoxOpen(boxFeePayments)) return;
      final box = Hive.box(boxFeePayments);
      final cutoff = DateTime.now().subtract(maxAge);

      for (var key in box.keys) {
        final val = box.get(key);
        if (val is List && val.isNotEmpty) {
          final pruned = val.where((item) {
            if (item is! Map) return true;
            // Always keep pending unsynced payments
            if (item['is_pending_sync'] == true) return true;
            final dateStr = item['date_paid']?.toString();
            if (dateStr == null) return true;
            final parsedDate = DateTime.tryParse(dateStr);
            if (parsedDate == null) return true;
            return parsedDate.isAfter(cutoff);
          }).toList();

          if (pruned.length != val.length) {
            await box.put(key, pruned);
            debugPrint("🧹 Pruned ${val.length - pruned.length} old payments from cache key: $key");
          }
        }
      }
    } catch (e) {
      debugPrint("Warning: Error pruning old payments cache: $e");
    }
  }

  /// Clean recursive map types to satisfy Hive
  Map<String, dynamic> _cleanMap(Map<dynamic, dynamic> map) {
    final Map<String, dynamic> clean = {};
    map.forEach((k, v) {
      final String keyStr = k.toString();
      if (v is Map) {
        clean[keyStr] = _cleanMap(v);
      } else if (v is List) {
        clean[keyStr] = v.map((item) {
          if (item is Map) {
            return _cleanMap(item);
          }
          return item;
        }).toList();
      } else {
        clean[keyStr] = v;
      }
    });
    return clean;
  }
}
