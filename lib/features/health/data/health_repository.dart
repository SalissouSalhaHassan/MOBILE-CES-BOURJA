import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class HealthRepository {
  final MobileApiClient _apiClient;

  HealthRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Fetch student health snapshot, digital medical record, vaccine card, and infirmary visits
  Future<Map<String, dynamic>> getStudentHealthProfile({int? studentId}) async {
    try {
      final endpoint = studentId != null
          ? '/api/mobile/health/student?studentId=$studentId'
          : '/api/mobile/health/student';
      final response = await _apiClient.getJson(endpoint);
      if (response['success'] == true && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      debugPrint("❌ HealthRepository getStudentHealthProfile error: $e");
      return {};
    }
  }

  /// Record a new infirmary visit from mobile (Nurse or Supervisor)
  Future<Map<String, dynamic>> recordInfirmaryVisit({
    required int studentId,
    required String symptoms,
    double? temperature,
    String? bloodPressure,
    int? heartRate,
    String? diagnosis,
    String? careProvided,
    String? prescriptions,
    String severity = 'Bénin',
    String outcome = 'Retour en classe',
    bool notifyParent = true,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/health/visits',
        {
          'studentId': studentId,
          'symptoms': symptoms,
          'temperature': temperature,
          'bloodPressure': bloodPressure,
          'heartRate': heartRate,
          'diagnosis': diagnosis,
          'careProvided': careProvided,
          'prescriptions': prescriptions,
          'severity': severity,
          'outcome': outcome,
          'notifyParent': notifyParent,
          'notes': notes,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("❌ HealthRepository recordInfirmaryVisit error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update student medical record (Blood group, allergies, chronic conditions, vaccines)
  Future<Map<String, dynamic>> updateStudentMedicalProfile({
    required int studentId,
    String? bloodGroup,
    String? allergies,
    String? chronicConditions,
    String? regularMedications,
    List<Map<String, dynamic>>? vaccinations,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? doctorName,
    String? doctorPhone,
    double? heightCm,
    double? weightKg,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/health/profile',
        {
          'studentId': studentId,
          'bloodGroup': bloodGroup,
          'allergies': allergies,
          'chronicConditions': chronicConditions,
          'regularMedications': regularMedications,
          'vaccinations': vaccinations,
          'emergencyContactName': emergencyContactName,
          'emergencyContactPhone': emergencyContactPhone,
          'emergencyContactRelation': emergencyContactRelation,
          'doctorName': doctorName,
          'doctorPhone': doctorPhone,
          'heightCm': heightCm,
          'weightKg': weightKg,
          'notes': notes,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("❌ HealthRepository updateStudentMedicalProfile error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
