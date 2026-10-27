import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class DisciplineRepository {
  final MobileApiClient _apiClient;

  DisciplineRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Fetch student conduct, behavior points, sanctions, convocations, and council sessions
  Future<Map<String, dynamic>> getStudentDisciplineProfile({int? studentId}) async {
    try {
      final endpoint = studentId != null
          ? '/api/mobile/discipline/student?studentId=$studentId'
          : '/api/mobile/discipline/student';
      final response = await _apiClient.getJson(endpoint);
      if (response['success'] == true && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      debugPrint("❌ DisciplineRepository getStudentDisciplineProfile error: $e");
      return {};
    }
  }

  /// Log a new discipline incident from mobile (Teacher / Supervisor)
  Future<Map<String, dynamic>> recordDisciplineIncident({
    required int studentId,
    required String incidentType,
    String severity = 'Mineur',
    String? description,
    String? proposedAction,
    String sanctionType = "Rappel à l'ordre",
    int sanctionDurationDays = 0,
    bool notifyParent = true,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/discipline/incidents',
        {
          'studentId': studentId,
          'incidentType': incidentType,
          'severity': severity,
          'description': description,
          'proposedAction': proposedAction,
          'sanctionType': sanctionType,
          'sanctionDurationDays': sanctionDurationDays,
          'notifyParent': notifyParent,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("❌ DisciplineRepository recordDisciplineIncident error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Issue a parent appointment/convocation from mobile
  Future<Map<String, dynamic>> issueParentConvocation({
    required int studentId,
    required String reason,
    required String convocationDate,
    String location = "Bureau du Censeur / Surveillant Général",
    String channel = "WhatsApp",
    String? notes,
    bool notifyParent = true,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/discipline/convocations',
        {
          'studentId': studentId,
          'reason': reason,
          'convocationDate': convocationDate,
          'location': location,
          'channel': channel,
          'notes': notes,
          'notifyParent': notifyParent,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("❌ DisciplineRepository issueParentConvocation error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
