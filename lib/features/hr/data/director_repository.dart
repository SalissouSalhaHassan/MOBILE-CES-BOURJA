import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';

class DirectorRepository {
  final MobileApiClient _apiClient;

  DirectorRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? locator<MobileApiClient>();

  Future<Map<String, dynamic>> getDirectorCockpit() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/admin/director-cockpit');
      return Map<String, dynamic>.from(res['data'] ?? {});
    } catch (e) {
      debugPrint('DirectorRepository.getDirectorCockpit error: $e');
      return {
        'directorName': 'Direction Générale',
        'schoolName': 'Complexe Scolaire Privé d\'Excellence EDUT',
        'kpis': {
          'totalTeachers': 0,
          'presentTeachersCount': 0,
          'absentTeachersCount': 0,
          'teacherPresenceRate': '0%',
          'totalClassesCount': 0,
          'filledClassesCount': 0,
          'fillRatePercent': '0%',
          'pendingRequestsCount': 0,
        },
        'approvals': {
          'hrRequests': [],
          'extraHours': [],
        },
        'pedagogie': {
          'filledToday': [],
          'missingToday': [],
          'fillRatePercent': 0,
        },
        'teacherAttendance': {
          'list': [],
          'presentCount': 0,
          'absentCount': 0,
        },
      };
    }
  }

  Future<void> approveOrRejectRequest({
    required String category,
    required int id,
    required String status,
    String? adminComment,
  }) async {
    try {
      await _apiClient.postJson('/api/mobile/admin/director-cockpit', {
        'category': category,
        'id': id,
        'status': status,
        if (adminComment != null && adminComment.isNotEmpty) 'adminComment': adminComment,
      });
    } catch (e) {
      debugPrint('DirectorRepository.approveOrRejectRequest error: $e');
      // Optimistic simulated completion if offline
    }
  }
}
