import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineOperation {
  final String id;
  final String table;
  final String action; // 'insert' | 'update' | 'delete' | 'batch_insert' | 'custom'
  final Map<String, dynamic> data;
  final String timestamp;
  final int priority; // 1 = Students, 2 = Financials, 3 = Academics, 4 = Attendance, 5 = Others
  final String? idempotencyKey;
  bool isSynced;
  int retryCount;
  String? lastError;

  static const int maxRetries = 3;

  OfflineOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
    required this.timestamp,
    int? priority,
    String? idempotencyKey,
    this.isSynced = false,
    this.retryCount = 0,
    this.lastError,
  })  : priority = priority ?? _resolvePriority(table),
        idempotencyKey = idempotencyKey ?? 'idemp_${id}_${DateTime.now().millisecondsSinceEpoch}';

  static int _resolvePriority(String table) {
    if (table == 'students') return 1;
    if (table == 'fee_payments' || table.contains('finance')) return 2;
    if (table == 'student_results' || table == 'grade_workflow' || table.contains('academics')) return 3;
    if (table == 'student_attendance') return 4;
    return 5;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table': table,
      'action': action,
      'data': data,
      'timestamp': timestamp,
      'priority': priority,
      'idempotencyKey': idempotencyKey,
      'isSynced': isSynced,
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  factory OfflineOperation.fromMap(Map<dynamic, dynamic> map) {
    return OfflineOperation(
      id: map['id'] as String,
      table: map['table'] as String,
      action: map['action'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
      timestamp: map['timestamp'] as String,
      priority: (map['priority'] as num?)?.toInt(),
      idempotencyKey: map['idempotencyKey'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
    );
  }
}

class OfflineQueueManager {
  static const String boxQueueName = 'operations_queue';
  /// Dead-letter queue: stores operations that failed after maxRetries
  static const String boxDeadLetterName = 'operations_dlq';
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// Initialize queue box
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) {
        await Hive.openBox(boxQueueName);
      }
      if (!Hive.isBoxOpen(boxDeadLetterName)) {
        await Hive.openBox(boxDeadLetterName);
      }
      _updatePendingCount();
      await purgeOldDeadLetterOperations(retentionDays: 7);
      debugPrint("✅ OfflineQueueManager: Queue Hive box initialized successfully.");
    } catch (e) {
      debugPrint("❌ OfflineQueueManager Initialization Error: $e");
    }
  }

  void _updatePendingCount() {
    pendingCountNotifier.value = getPendingOperations().length;
  }

  /// Enqueue a new operation
  Future<void> enqueue({
    required String table,
    required String action,
    required Map<String, dynamic> data,
    int? priority,
  }) async {
    try {
      final box = Hive.box(boxQueueName);
      final id = "${DateTime.now().millisecondsSinceEpoch}_${table}_$action";
      
      final operation = OfflineOperation(
        id: id,
        table: table,
        action: action,
        data: data,
        timestamp: DateTime.now().toIso8601String(),
        priority: priority,
      );

      await box.put(id, operation.toMap());
      _updatePendingCount();
      debugPrint("➕ Enqueued Operation -> ID: $id, Table: $table, Priority: ${operation.priority}");
    } catch (e) {
      debugPrint("❌ Failed to enqueue operation: $e");
    }
  }

  /// Enqueue an HTTP API request for offline synchronization
  Future<void> enqueueRequest({
    required String endpoint,
    required String method,
    required Map<String, dynamic> body,
    int? priority,
  }) async {
    await enqueue(
      table: endpoint,
      action: method,
      data: body,
      priority: priority,
    );
  }

  /// Get list of all pending operations sorted by priority (1 is highest) then timestamp
  List<OfflineOperation> getPendingOperations() {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) return [];
      final box = Hive.box(boxQueueName);
      
      final List<OfflineOperation> list = [];
      for (var key in box.keys) {
        if (key == 'last_sync_time') continue;
        final val = box.get(key);
        if (val is Map) {
          list.add(OfflineOperation.fromMap(val));
        }
      }
      
      // Sort by priority first (1 is highest), then timestamp
      list.sort((a, b) {
        final pComp = a.priority.compareTo(b.priority);
        if (pComp != 0) return pComp;
        return a.timestamp.compareTo(b.timestamp);
      });
      return list;
    } catch (e) {
      debugPrint("❌ Error reading queue: $e");
      return [];
    }
  }

  /// Get a specific operation by its ID
  OfflineOperation? getOperationById(String id) {
    try {
      if (!Hive.isBoxOpen(boxQueueName)) return null;
      final box = Hive.box(boxQueueName);
      final val = box.get(id);
      if (val is Map) {
        return OfflineOperation.fromMap(val);
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error getting operation $id: $e");
      return null;
    }
  }

  /// Remove operation from queue (after successful sync)
  Future<void> dequeue(String id) async {
    try {
      final box = Hive.box(boxQueueName);
      await box.delete(id);
      _updatePendingCount();
      debugPrint("➖ Dequeued Operation -> ID: $id");
    } catch (e) {
      debugPrint("❌ Error dequeuing operation $id: $e");
    }
  }

  /// Remap temporary offline IDs (e.g. temp_std_UUID) to permanent server IDs (realId)
  /// and fee accounts in subsequent operations across the queue to prevent Foreign Key errors.
  Future<int> remapTemporaryId({
    required String temporaryId,
    required dynamic permanentId,
    dynamic temporaryFeeId,
    dynamic permanentFeeId,
    String? numAdmission,
    String? studentName,
  }) async {
    try {
      final box = Hive.box(boxQueueName);
      int remappedCount = 0;

      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final op = OfflineOperation.fromMap(val);
          bool modified = false;
          final updatedData = Map<String, dynamic>.from(op.data);

          // Check common student foreign key fields
          for (final field in ['studentId', 'student_id', 'studentIdStr']) {
            if (updatedData[field]?.toString() == temporaryId) {
              updatedData[field] = permanentId;
              modified = true;
            }
          }

          // Remap explicit feeId if matching temporaryId or temporaryFeeId
          for (final field in ['feeId', 'fee_id']) {
            if (updatedData[field]?.toString() == temporaryId) {
              updatedData[field] = permanentId;
              modified = true;
            }
            if (temporaryFeeId != null && permanentFeeId != null && updatedData[field]?.toString() == temporaryFeeId.toString()) {
              updatedData[field] = permanentFeeId;
              modified = true;
            }
          }

          // If this is a fee payment operation and matches student identity, attach permanent student & fee IDs
          if (op.table == 'fee_payments' || op.action == 'record_payment') {
            final opStudentName = updatedData['studentName']?.toString() ?? updatedData['student_name']?.toString();
            final opNumAdm = updatedData['numAdmission']?.toString() ?? updatedData['num_admission']?.toString();
            final opStdId = updatedData['studentId']?.toString() ?? updatedData['student_id']?.toString();

            final matchesStudent = (opStdId != null && opStdId == temporaryId) ||
                (numAdmission != null && numAdmission.isNotEmpty && opNumAdm == numAdmission) ||
                (studentName != null && studentName.isNotEmpty && opStudentName == studentName);

            if (matchesStudent) {
              updatedData['studentId'] = permanentId;
              if (permanentFeeId != null) {
                updatedData['feeId'] = permanentFeeId;
              }
              modified = true;
            }
          }

          if (modified) {
            final newOp = OfflineOperation(
              id: op.id,
              table: op.table,
              action: op.action,
              data: updatedData,
              timestamp: op.timestamp,
              priority: op.priority,
              idempotencyKey: op.idempotencyKey,
              isSynced: op.isSynced,
              retryCount: op.retryCount,
              lastError: op.lastError,
            );
            await box.put(key, newOp.toMap());
            remappedCount++;
            debugPrint("🔗 Remapped temporary IDs for op ${op.id} ($temporaryId -> $permanentId, fee: $permanentFeeId)");
          }
        }
      }
      return remappedCount;
    } catch (e) {
      debugPrint("❌ Error remapping temporary ID $temporaryId: $e");
      return 0;
    }
  }

  /// Increment retry count for a failed operation
  Future<void> incrementRetry(String id, {String? error}) async {
    try {
      final box = Hive.box(boxQueueName);
      final val = box.get(id);
      if (val is Map) {
        final op = OfflineOperation.fromMap(val);
        op.retryCount += 1;
        op.lastError = error;
        await box.put(id, op.toMap());
        _updatePendingCount();
        debugPrint("🔁 Retry #${op.retryCount} for Operation -> ID: $id");
      }
    } catch (e) {
      debugPrint("❌ Error updating retry count for $id: $e");
    }
  }

  /// Move a permanently failed operation to the dead-letter queue
  Future<void> moveToDeadLetter(String id, {String? reason}) async {
    try {
      final box = Hive.box(boxQueueName);
      final dlqBox = Hive.box(boxDeadLetterName);
      final val = box.get(id);
      if (val is Map) {
        final op = OfflineOperation.fromMap(val);
        op.lastError = reason ?? op.lastError;
        await dlqBox.put("dlq_$id", op.toMap());
        await box.delete(id);
        _updatePendingCount();
        debugPrint("☠️ Operation moved to Dead-Letter Queue -> ID: $id, Reason: $reason");
      }
    } catch (e) {
      debugPrint("❌ Error moving to DLQ: $e");
    }
  }

  /// Get all dead-letter operations for admin inspection
  List<OfflineOperation> getDeadLetterOperations() {
    try {
      if (!Hive.isBoxOpen(boxDeadLetterName)) return [];
      final box = Hive.box(boxDeadLetterName);
      return box.values
          .whereType<Map>()
          .map((e) => OfflineOperation.fromMap(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all dead-letter entries with their box keys
  List<({String key, OfflineOperation op})> getDeadLetterEntries() {
    try {
      if (!Hive.isBoxOpen(boxDeadLetterName)) return [];
      final box = Hive.box(boxDeadLetterName);
      final list = <({String key, OfflineOperation op})>[];
      for (final key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          list.add((key: key.toString(), op: OfflineOperation.fromMap(val)));
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Clear the entire queue
  Future<void> clearQueue() async {
    try {
      if (Hive.isBoxOpen(boxQueueName)) {
        await Hive.box(boxQueueName).clear();
        _updatePendingCount();
      }
    } catch (e) {
      debugPrint("❌ Error clearing queue: $e");
    }
  }

  /// Automatically purge DLQ records older than retentionDays (default: 7 days)
  Future<int> purgeOldDeadLetterOperations({int retentionDays = 7}) async {
    try {
      if (!Hive.isBoxOpen(boxDeadLetterName)) return 0;
      final box = Hive.box(boxDeadLetterName);
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));

      final keysToDelete = <dynamic>[];
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final timestampStr = val['timestamp'] as String?;
          if (timestampStr != null) {
            final opDate = DateTime.tryParse(timestampStr);
            if (opDate != null && opDate.isBefore(cutoff)) {
              keysToDelete.add(key);
            }
          }
        }
      }

      for (var k in keysToDelete) {
        await box.delete(k);
      }

      if (keysToDelete.isNotEmpty) {
        debugPrint("🧹 OfflineQueueManager: Purged ${keysToDelete.length} DLQ records older than $retentionDays days.");
      }
      return keysToDelete.length;
    } catch (e) {
      debugPrint("❌ Error purging old DLQ operations: $e");
      return 0;
    }
  }

  /// Move a DLQ operation back to the pending queue for re-processing
  Future<void> retryDeadLetter(String dlqKey) async {
    try {
      final box = Hive.box(boxQueueName);
      final dlqBox = Hive.box(boxDeadLetterName);
      final val = dlqBox.get(dlqKey);
      if (val is Map) {
        final op = OfflineOperation.fromMap(val);
        op.retryCount = 0;
        op.lastError = null;
        await box.put(op.id, op.toMap());
        await dlqBox.delete(dlqKey);
        _updatePendingCount();
        debugPrint("♻️ Retrying DLQ Operation -> ID: ${op.id}");
      }
    } catch (e) {
      debugPrint("❌ Error retrying DLQ operation: $e");
    }
  }

  /// Delete a single DLQ operation permanently
  Future<void> deleteDeadLetter(String dlqKey) async {
    try {
      if (!Hive.isBoxOpen(boxDeadLetterName)) return;
      final dlqBox = Hive.box(boxDeadLetterName);
      await dlqBox.delete(dlqKey);
      debugPrint("🗑️ Deleted DLQ Operation -> Key: $dlqKey");
    } catch (e) {
      debugPrint("❌ Error deleting DLQ operation: $e");
    }
  }
}
