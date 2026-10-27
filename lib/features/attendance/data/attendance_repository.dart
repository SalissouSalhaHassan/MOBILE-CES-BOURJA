import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/utils/type_converters.dart';

class AttendanceRepository {
  final MobileApiClient _apiClient;
  final SupabaseClient _client;

  AttendanceRepository({MobileApiClient? apiClient, SupabaseClient? client})
      : _apiClient = apiClient ?? MobileApiClient(),
        _client = client ?? SupabaseClientManager().client;

  // Record student gate presence check-in from scanning QR Code (with offline auto-queue)
  Future<Map<String, dynamic>> recordStudentGateScan({
    int? studentId,
    String? numAdmission,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/attendance',
        {
          'action': 'recordStudentGateScan',
          'payload': {
            'studentId': studentId,
            'numAdmission': numAdmission,
            'scanMethod': 'QR_CODE',
          },
        },
      );
      return response;
    } catch (e) {
      debugPrint("📶 Offline Mode / Network Error on Gate Scan: Enqueueing scan locally ($e)");
      try {
        final queueManager = locator<OfflineQueueManager>();
        await queueManager.enqueueRequest(
          endpoint: '/api/mobile/attendance',
          method: 'POST',
          body: {
            'action': 'recordStudentGateScan',
            'payload': {
              'studentId': studentId,
              'numAdmission': numAdmission,
              'scanMethod': 'QR_CODE_OFFLINE',
              'scannedAt': DateTime.now().toIso8601String(),
            },
          },
        );
        return {
          'success': true,
          'isOffline': true,
          'message': 'Badge validé & enregistré hors-ligne (synchronisation automatique)',
          'data': {
            'student_id': studentId,
            'num_admission': numAdmission,
            'status': 'Présent',
            'time': DateTime.now().toIso8601String(),
          }
        };
      } catch (queueErr) {
        return {
          'success': false,
          'error': '$e',
        };
      }
    }
  }

  // Record presence check-in from scanning QR Code
  Future<Map<String, dynamic>> recordTeacherSessionScan({
    required int classId,
    required int employeeId,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/attendance',
        {
          'action': 'recordTeacherSessionScan',
          'payload': {
            'classId': classId,
            'employeeId': employeeId,
          },
        },
      );
      return response;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get schedule attendance for a teacher
  Future<Map<String, dynamic>> getTeacherScheduleAttendance({
    required int employeeId,
    required String filterType, // "day" | "week" | "month" | "year"
    required String dateStr,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "teacher_schedule_${employeeId}_${filterType}_$dateStr";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching teacher schedule from local cache.");
      final cachedData = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cachedData.isNotEmpty) {
        final firstItem = cachedData.first;
        final slots = firstItem['slots'] as List?;
        final stats = firstItem['stats'] as Map?;
        if (slots != null && stats != null) {
          return {
            'success': true,
            'slots': List<Map<String, dynamic>>.from(slots.map((e) => Map<String, dynamic>.from(e as Map))),
            'stats': Map<String, dynamic>.from(stats),
          };
        }
      }
      return {
        'success': false,
        'error': 'Pas de connexion internet et aucune donnée en cache.',
      };
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/attendance?action=getTeacherScheduleAttendance&employeeId=$employeeId&filterType=$filterType&dateStr=$dateStr',
      );

      final slots = response['slots'] as List?;
      final stats = response['stats'] as Map?;
      final slotsList = slots != null
          ? List<Map<String, dynamic>>.from(slots.map((e) => Map<String, dynamic>.from(e as Map)))
          : <Map<String, dynamic>>[];
      final statsMap = stats != null ? Map<String, dynamic>.from(stats) : <String, dynamic>{};

      // Cache the result
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: [
          {
            'slots': slotsList,
            'stats': statsMap,
          }
        ],
      );

      return {
        'success': true,
        'slots': slotsList,
        'stats': statsMap,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Fetch active students for a class name
  Future<List<Map<String, dynamic>>> getStudentsByClass(String className, int? employeeId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "students_${employeeId}_$className";

    List<Map<String, dynamic>> filterFromGeneralList() {
      final cachedStudents = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: "students_list",
      );
      if (cachedStudents.isNotEmpty) {
        final cleanClassName = className.trim().toLowerCase();
        final matched = cachedStudents.where((s) {
          final sClass = (s['classe'] ?? s['class_name'] ?? s['className'])?.toString().trim().toLowerCase();
          return sClass == cleanClassName;
        }).toList();
        return matched.isNotEmpty ? matched : cachedStudents;
      }
      return [];
    }

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching students for $className from local cache.");
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cached.isNotEmpty) return cached;
      return filterFromGeneralList();
    }

    try {
      final url = '/api/mobile/attendance?action=getStudentsByClass&className=${Uri.encodeComponent(className)}${employeeId != null ? '&employeeId=$employeeId' : ''}';
      final response = await _apiClient.getJson(url);
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);

      if (list.isNotEmpty) {
        await cacheManager.saveDataList(
          boxName: OfflineStoreManager.boxStudents,
          key: cacheKey,
          data: list,
        );
        return list;
      }

      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cached.isNotEmpty) return cached;
      return filterFromGeneralList();
    } catch (e) {
      debugPrint("Error fetching students by class: $e");
      final cached = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cached.isNotEmpty) return cached;
      return filterFromGeneralList();
    }
  }

  // Fetch student attendance records for a class on a specific date (and subject if applicable)
  Future<List<Map<String, dynamic>>> getStudentAttendanceRecords({
    required int classId,
    required String dateStr,
    int? subjectId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "attendance_${classId}_${dateStr}_$subjectId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching attendance records from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }

    try {
      final url = '/api/mobile/attendance?action=getStudentAttendanceRecords&classId=$classId&dateStr=$dateStr${subjectId != null ? '&subjectId=$subjectId' : ''}';
      final response = await _apiClient.getJson(url);
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: list,
      );

      return list;
    } catch (e) {
      debugPrint("Error fetching student attendance: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }
  }

  // Save batch student attendance records
  Future<Map<String, dynamic>> saveStudentBatchAttendance({
    required int classId,
    required String dateStr,
    int? subjectId,
    required int? employeeId,
    required List<Map<String, dynamic>> records,
    bool sendSMS = false,
    bool sendWhatsApp = false,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "attendance_${classId}_${dateStr}_$subjectId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Queueing batch attendance save locally.");

      await queueManager.enqueue(
        table: 'student_attendance',
        action: 'batch_attendance',
        data: {
          'classId': classId,
          'dateStr': dateStr,
          'subjectId': subjectId,
          'employeeId': employeeId,
          'records': records,
          'sendSMS': sendSMS,
          'sendWhatsApp': sendWhatsApp,
        },
      );

      final List<Map<String, dynamic>> cachedRecords = records.map((r) {
        return {
          'id': null,
          'student_id': r['student_id'],
          'status': r['status'],
          'remark': r['remark'],
        };
      }).toList();

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: cachedRecords,
      );

      return {'success': true};
    }

    try {
      final response = await _apiClient.postJson(
        '/api/mobile/attendance',
        {
          'action': 'saveStudentBatchAttendance',
          'payload': {
            'classId': classId,
            'dateStr': dateStr,
            'subjectId': subjectId,
            'employeeId': employeeId,
            'records': records,
            'sendSMS': sendSMS,
            'sendWhatsApp': sendWhatsApp,
          },
        },
      );

      // Save updated records locally
      final List<Map<String, dynamic>> freshMapped = records.map((r) {
        final stId = TypeConverters.safeInt(r['student_id'] ?? r['studentId'] ?? r['id']);
        return {
          'id': null,
          'student_id': stId,
          'status': r['status'],
          'remark': r['remark'],
        };
      }).toList();

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: freshMapped,
      );

      return response;
    } catch (e) {
      debugPrint("Error saving student batch attendance: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Fetch classes and subjects taught by a specific teacher / staff
  Future<List<Map<String, dynamic>>> getTeacherClassesAndSubjects(int employeeId) async {
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "attendance_teacher_classes_$employeeId";

    try {
      try {
        final response = await _apiClient.getJson(
          '/api/mobile/academics?action=getTeacherClassesAndSubjects&employeeId=$employeeId',
        );
        final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
        if (list.isNotEmpty) {
          await cacheManager.saveDataList(
            boxName: OfflineStoreManager.boxClassSubjects,
            key: cacheKey,
            data: list,
          );
          return list;
        }
      } catch (_) {}

      try {
        final response = await _apiClient.getJson(
          '/api/mobile/attendance?action=getTeacherClassesAndSubjects&employeeId=$employeeId',
        );
        final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
        if (list.isNotEmpty) {
          await cacheManager.saveDataList(
            boxName: OfflineStoreManager.boxClassSubjects,
            key: cacheKey,
            data: list,
          );
          return list;
        }
      } catch (_) {}

      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
      );
    } catch (e) {
      debugPrint("Error fetching teacher classes and subjects: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxClassSubjects,
        key: cacheKey,
      );
    }
  }
}
