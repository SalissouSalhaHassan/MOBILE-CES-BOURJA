import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/di/injection.dart';

class ExamsRepository {
  final MobileApiClient _apiClient;

  ExamsRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  OfflineStoreManager get _cacheManager => locator<OfflineStoreManager>();
  SyncEngine get _syncEngine => locator<SyncEngine>();

  // ─────────────────────────────────────────────────────────────────────────
  //  LIST & FORM OPTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExamsList() async {
    const cacheKey = 'exams_list';

    // 1. If offline, immediately return cached list
    if (!_syncEngine.isOnlineNotifier.value) {
      return _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getExamsList',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      
      // Update cache in background
      await _cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: list,
      );

      return list;
    } catch (e) {
      debugPrint('Error fetching exams list: $e');
      return _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> getExamFormOptions() async {
    const cacheKey = 'exam_form_options';

    if (!_syncEngine.isOnlineNotifier.value) {
      final cached = _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
      if (cached.isNotEmpty) {
        final first = cached.first;
        return {
          'classes': List<Map<String, dynamic>>.from(first['classes'] ?? []),
          'subjects': List<Map<String, dynamic>>.from(first['subjects'] ?? []),
          'periods': List<Map<String, dynamic>>.from(first['periods'] ?? []),
        };
      }
      return _buildFallbackExamFormOptions();
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getExamFormOptions',
      );
      final result = {
        'classes': List<Map<String, dynamic>>.from(response['classes'] ?? []),
        'subjects': List<Map<String, dynamic>>.from(response['subjects'] ?? []),
        'periods': List<Map<String, dynamic>>.from(response['periods'] ?? []),
      };

      await _cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: [result],
      );

      return result;
    } catch (e) {
      debugPrint('Error fetching exam form options: $e');
      final cached = _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
      if (cached.isNotEmpty) {
        final first = cached.first;
        return {
          'classes': List<Map<String, dynamic>>.from(first['classes'] ?? []),
          'subjects': List<Map<String, dynamic>>.from(first['subjects'] ?? []),
          'periods': List<Map<String, dynamic>>.from(first['periods'] ?? []),
        };
      }
      return _buildFallbackExamFormOptions();
    }
  }

  Map<String, List<Map<String, dynamic>>> _buildFallbackExamFormOptions() {
    final List<Map<String, dynamic>> classes = [];
    final List<Map<String, dynamic>> subjects = [];
    final Set<String> seenClasses = {};
    final Set<String> seenSubjects = {};

    try {
      if (Hive.isBoxOpen(OfflineStoreManager.boxClassSubjects)) {
        final box = _cacheManager.getBox(OfflineStoreManager.boxClassSubjects);
        for (final key in box.keys) {
          final raw = box.get(key);
          if (raw is List) {
            for (final elem in raw) {
              if (elem is Map) {
                final item = Map<String, dynamic>.from(elem);
                final cName = (item['school_classes']?['class_name'] ?? item['class_name'] ?? item['className'])?.toString();
                final cId = item['class_id'] ?? item['id'] ?? item['classId'];
                final edLevel = item['school_classes']?['educational_level'] ?? item['educational_level'] ?? item['educationalLevel'];
                final secName = item['school_classes']?['section_name'] ?? item['section_name'] ?? item['sectionName'];

                if (cName != null && cName.isNotEmpty && !seenClasses.contains(cName)) {
                  seenClasses.add(cName);
                  classes.add({
                    'id': cId ?? classes.length + 1,
                    'class_name': cName,
                    'educational_level': edLevel,
                    'section_name': secName,
                  });
                }

                final sName = (item['school_subjects']?['subject_name'] ?? item['subject_name'] ?? item['subjectName'])?.toString();
                final sId = item['subject_id'] ?? item['subjectId'];
                if (sName != null && sName.isNotEmpty && !seenSubjects.contains(sName)) {
                  seenSubjects.add(sName);
                  subjects.add({
                    'id': sId ?? subjects.length + 1,
                    'subject_name': sName,
                  });
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return {
      'classes': classes,
      'subjects': subjects,
      'periods': [
        {'id': 1, 'name': '1er Semestre'},
        {'id': 2, 'name': '2ème Semestre'},
        {'id': 3, 'name': '1er Trimestre'},
        {'id': 4, 'name': '2ème Trimestre'},
        {'id': 5, 'name': '3ème Trimestre'},
      ],
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SINGLE EXAM DETAIL
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getExamDetails(int examId) async {
    try {
      final response = await _apiClient.getJson('/api/mobile/exams/$examId');
      return Map<String, dynamic>.from(response['data'] ?? {});
    } catch (e) {
      debugPrint('Error fetching exam details: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  RESULTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all results for a specific exam (admin / teacher use).
  Future<List<Map<String, dynamic>>> getExamResults(int examId) async {
    final cacheKey = 'exam_results_$examId';

    if (!_syncEngine.isOnlineNotifier.value) {
      return _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getExamResults&examId=$examId',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);
      
      await _cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: list,
      );

      return list;
    } catch (e) {
      debugPrint('Error fetching exam results: $e');
      return _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
    }
  }

  /// Fetch all exam results for a specific student (parent / student use).
  Future<List<Map<String, dynamic>>> getResultsByStudent(int studentId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams/results?studentId=$studentId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching results for student: $e');
      return [];
    }
  }

  /// Fetch results for a specific exam, filtered by student scope.
  Future<List<Map<String, dynamic>>> getResultsByExam(int examId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams/results?examId=$examId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('Error fetching results for exam: $e');
      return [];
    }
  }

  /// Save results for a single student in a single exam.
  Future<Map<String, dynamic>> saveExamResult({
    required int examId,
    required int studentId,
    double? marksObtained,
    String? remarks,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/exams/results',
        {
          'examId': examId,
          'studentId': studentId,
          'marksObtained': marksObtained,
          'remarks': remarks,
        },
      );
      return response;
    } catch (e) {
      debugPrint('Error saving exam result: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BATCH RESULTS (for entering a full class at once)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveBatchExamResults({
    required int examId,
    required List<Map<String, dynamic>> results,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/exams',
        {
          'action': 'saveBatchExamResults',
          'payload': {
            'examId': examId,
            'results': results,
          },
        },
      );

      // Update cached results immediately
      if (response['success'] == true) {
        final cacheKey = 'exam_results_$examId';
        await _cacheManager.saveDataList(
          boxName: OfflineStoreManager.boxStudentResults,
          key: cacheKey,
          data: results,
        );
      }

      return response;
    } catch (e) {
      debugPrint('Error saving batch exam results: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STUDENTS FOR EXAM
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStudentsForExam({
    required int classId,
  }) async {
    final cacheKey = 'students_exam_$classId';

    if (!_syncEngine.isOnlineNotifier.value) {
      return _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/api/mobile/exams?action=getStudentsForExam&classId=$classId',
      );
      final list = List<Map<String, dynamic>>.from(response['data'] ?? []);

      await _cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
        data: list,
      );

      return list;
    } catch (e) {
      debugPrint('Error fetching students for exam: $e');
      return _cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudentResults,
        key: cacheKey,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createExam({
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _apiClient.postJson(
        '/api/mobile/exams',
        {'action': 'createExam', 'payload': payload},
      );
    } catch (e) {
      debugPrint('Error creating exam: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateExam({
    required int examId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _apiClient.postJson(
        '/api/mobile/exams',
        {
          'action': 'updateExam',
          'payload': {'examId': examId, ...payload},
        },
      );
    } catch (e) {
      debugPrint('Error updating exam: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteExam(int examId) async {
    try {
      return await _apiClient.postJson(
        '/api/mobile/exams',
        {
          'action': 'deleteExam',
          'payload': {'examId': examId},
        },
      );
    } catch (e) {
      debugPrint('Error deleting exam: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
