import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class LmsRepository {
  final MobileApiClient _apiClient;

  LmsRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Fetches all courses available for the student or specific course with modules & lessons
  Future<Map<String, dynamic>?> getCourses({int? studentId, int? courseId}) async {
    try {
      final queryParams = <String>[
        if (studentId != null) 'studentId=$studentId',
        if (courseId != null) 'courseId=$courseId',
      ].join('&');

      final url = '/api/mobile/lms/courses${queryParams.isNotEmpty ? '?$queryParams' : ''}';
      final res = await _apiClient.getJson(url);
      if (res['success'] == true) {
        return res;
      }
      return null;
    } catch (e) {
      debugPrint('LmsRepository.getCourses error: $e');
      return null;
    }
  }

  /// Updates lesson progress (video position, completion status, notes)
  Future<bool> saveLessonProgress({
    required int lessonId,
    int? studentId,
    bool? isCompleted,
    int? lastPosition,
    String? personalNotes,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/lms/progress', {
        'lessonId': lessonId,
        if (studentId != null) 'studentIdParam': studentId,
        if (isCompleted != null) 'isCompleted': isCompleted,
        if (lastPosition != null) 'lastPosition': lastPosition,
        if (personalNotes != null) 'personalNotes': personalNotes,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('LmsRepository.saveLessonProgress error: $e');
      return false;
    }
  }

  /// Submits quiz answers and returns grades and optional completion certificate
  Future<Map<String, dynamic>?> submitQuiz({
    required int quizId,
    required Map<int, int> answers, // questionId -> answerId
    int? studentId,
  }) async {
    try {
      final formattedAnswers = answers.map((k, v) => MapEntry(k.toString(), v));
      final res = await _apiClient.postJson('/api/mobile/lms/quiz/submit', {
        'quizId': quizId,
        'answers': formattedAnswers,
        if (studentId != null) 'studentIdParam': studentId,
      });
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      return null;
    } catch (e) {
      debugPrint('LmsRepository.submitQuiz error: $e');
      return null;
    }
  }

  /// Fetches virtual live classes
  Future<List<dynamic>> getVirtualClasses({int? studentId}) async {
    try {
      final queryParam = studentId != null ? '?studentId=$studentId' : '';
      final res = await _apiClient.getJson('/api/mobile/lms/virtual-classes$queryParam');
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      debugPrint('LmsRepository.getVirtualClasses error: $e');
      return [];
    }
  }

  /// Validates attendance for a virtual live session
  Future<bool> markVirtualClassAttendance({
    required int virtualClassId,
    int? studentId,
    int? durationMinutes,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/lms/virtual-classes', {
        'virtualClassId': virtualClassId,
        if (studentId != null) 'studentIdParam': studentId,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('LmsRepository.markVirtualClassAttendance error: $e');
      return false;
    }
  }

  /// Fetches homework assignments
  Future<List<dynamic>> getAssignments({int? studentId}) async {
    try {
      final queryParam = studentId != null ? '?studentId=$studentId' : '';
      final res = await _apiClient.getJson('/api/mobile/lms/assignments$queryParam');
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      debugPrint('LmsRepository.getAssignments error: $e');
      return [];
    }
  }

  /// Submits student work for an assignment
  Future<bool> submitAssignment({
    required int assignmentId,
    int? studentId,
    String? textResponse,
    String? fileReponsePath,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/lms/assignments', {
        'assignmentId': assignmentId,
        if (studentId != null) 'studentIdParam': studentId,
        if (textResponse != null) 'textResponse': textResponse,
        if (fileReponsePath != null) 'fileReponsePath': fileReponsePath,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('LmsRepository.submitAssignment error: $e');
      return false;
    }
  }

  /// Fetches earned certificates
  Future<List<dynamic>> getCertificates({int? studentId}) async {
    try {
      final queryParam = studentId != null ? '?studentId=$studentId' : '';
      final res = await _apiClient.getJson('/api/mobile/lms/certificates$queryParam');
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      debugPrint('LmsRepository.getCertificates error: $e');
      return [];
    }
  }

  /// Fetches discussions / Q&A forum messages for a course or lesson
  Future<List<dynamic>> getDiscussions({int? courseId, int? lessonId}) async {
    try {
      final queryParams = <String>[
        if (courseId != null) 'courseId=$courseId',
        if (lessonId != null) 'lessonId=$lessonId',
      ].join('&');

      final url = '/api/mobile/lms/discussions${queryParams.isNotEmpty ? '?$queryParams' : ''}';
      final res = await _apiClient.getJson(url);
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      debugPrint('LmsRepository.getDiscussions error: $e');
      return [];
    }
  }

  /// Posts a new message or reply in discussions
  Future<bool> postDiscussion({
    required String message,
    int? courseId,
    int? lessonId,
    int? parentId,
    int? studentId,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/lms/discussions', {
        'message': message,
        if (courseId != null) 'courseId': courseId,
        if (lessonId != null) 'lessonId': lessonId,
        if (parentId != null) 'parentId': parentId,
        if (studentId != null) 'studentIdParam': studentId,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('LmsRepository.postDiscussion error: $e');
      return false;
    }
  }

  /// Fetches student submissions for an assignment (Teacher / Grading mode)
  Future<List<dynamic>> getAssignmentSubmissions({required int assignmentId}) async {
    try {
      final res = await _apiClient.getJson('/api/mobile/lms/assignments/submissions?assignmentId=$assignmentId');
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      debugPrint('LmsRepository.getAssignmentSubmissions error: $e');
      return [];
    }
  }

  /// Grades a student assignment submission (Teacher / Grading mode)
  Future<bool> gradeAssignmentSubmission({
    required int submissionId,
    required double score,
    String? comment,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/lms/assignments/submissions', {
        'submissionId': submissionId,
        'score': score,
        if (comment != null) 'comment': comment,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('LmsRepository.gradeAssignmentSubmission error: $e');
      return false;
    }
  }
}
