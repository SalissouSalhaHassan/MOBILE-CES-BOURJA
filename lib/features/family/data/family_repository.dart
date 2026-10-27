import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';

class FamilyRepository {
  final MobileApiClient _apiClient;
  final SupabaseClient _client;

  FamilyRepository({MobileApiClient? apiClient, SupabaseClient? client})
      : _apiClient = apiClient ?? MobileApiClient(),
        _client = client ?? SupabaseClientManager().client;

  // Fetch children associated with the parent
  Future<List<Map<String, dynamic>>> getChildren() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/children',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching parent children: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getStudentSnapshot({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/child-summary?action=getStudentSnapshot&studentId=$studentId',
      );
      return Map<String, dynamic>.from(response['student'] ?? {});
    } catch (e) {
      debugPrint("Error fetching student snapshot: $e");
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getSessions(int schoolId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/finance/summary?action=getSessions&schoolId=$schoolId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching family sessions: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTimetable({
    required int schoolId,
    required String className,
    int? sessionId,
  }) async {
    try {
      final sIdStr = await locator<SessionManager>().getStudentId() ?? '';
      final studentId = int.tryParse(sIdStr) ?? 0;
      final response = await _apiClient.getJson(
        '/api/mobile/family/child-summary?action=getTimetable&studentId=$studentId&className=${Uri.encodeComponent(className)}',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching timetable: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGrades({
    required int studentId,
    required int schoolId,
    int? sessionId,
  }) async {
    try {
      final sessionPart = sessionId != null ? '&sessionId=$sessionId' : '';
      final response = await _apiClient.getJson(
        '/api/mobile/family/grades?studentId=$studentId$sessionPart',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching grades: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAttendance({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/attendance?studentId=$studentId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
      return [];
    }
  }

  Future<bool> justifyAbsence({
    required int studentId,
    required String reason,
    String? notes,
  }) async {
    try {
      final res = await _apiClient.postJson(
        '/api/mobile/family/attendance',
        {
          'studentId': studentId,
          'reason': reason,
          'notes': notes ?? '',
          'date': DateTime.now().toIso8601String(),
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint("Error submitting absence justification: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHomework({
    required String className,
  }) async {
    try {
      final sIdStr = await locator<SessionManager>().getStudentId() ?? '';
      final studentId = int.tryParse(sIdStr) ?? 0;
      final response = await _apiClient.getJson(
        '/api/mobile/family/homework?studentId=$studentId&className=${Uri.encodeComponent(className)}',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching homework: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getFinanceOverview({
    required int studentId,
    int? schoolId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/finance?studentId=$studentId',
      );
      return {
        'fees': List<Map<String, dynamic>>.from(response['fees'] ?? []),
        'payments': List<Map<String, dynamic>>.from(response['payments'] ?? []),
        'summary': Map<String, dynamic>.from(response['summary'] ?? {}),
      };
    } catch (e) {
      debugPrint("Error fetching finance overview: $e");
      return {
        'fees': <Map<String, dynamic>>[],
        'payments': <Map<String, dynamic>>[],
        'summary': {
          'totalExpected': 0.0,
          'totalPaid': 0.0,
          'totalReduction': 0.0,
          'totalBalance': 0.0,
        }
      };
    }
  }

  Future<List<Map<String, dynamic>>> getStudentPaymentsByFeeIds(
    List<int> feeIds,
  ) async {
    return [];
  }

  Future<Map<String, dynamic>?> getTransportSubscription({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/child-summary?action=getTransportSubscription&studentId=$studentId',
      );
      return response['data'] == null ? null : Map<String, dynamic>.from(response['data']);
    } catch (e) {
      debugPrint("Error fetching transport subscription: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLiveTransportData({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/transport/live?studentId=$studentId',
      );
      return response['data'] == null ? null : Map<String, dynamic>.from(response['data']);
    } catch (e) {
      debugPrint("Error fetching live transport data: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLibraryBooks() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/library?action=getLibraryBooks',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching library books: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStudentLibraryIssues({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/library?action=getStudentLibraryIssues&studentId=$studentId',
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint("Error fetching library issues: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> reserveBook({
    required int bookId,
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/family/library',
        {
          'action': 'reserveBook',
          'payload': {
            'bookId': bookId,
            'studentId': studentId,
          },
        },
      );
      return response;
    } catch (e) {
      debugPrint("Error reserving library book: $e");
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>?> getHostelAllocation({
    required int studentId,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mobile/family/child-summary?action=getHostelAllocation&studentId=$studentId',
      );
      return response['data'] == null ? null : Map<String, dynamic>.from(response['data']);
    } catch (e) {
      debugPrint("Error fetching hostel allocation: $e");
      return null;
    }
  }
}
