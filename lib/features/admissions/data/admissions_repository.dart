import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class AdmissionsRepository {
  final MobileApiClient _apiClient;

  AdmissionsRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Submit a new online student admission application (University LMD or School)
  Future<Map<String, dynamic>> submitApplication({
    required String studentFirstName,
    required String studentLastName,
    required String dateOfBirth,
    String gender = 'M',
    String? placeOfBirth,
    String nationality = 'Nigérienne',
    String? educationLevel,
    String? faculty,
    String? department,
    String? degreeProgram,
    String? degreeLevel,
    String? studyMode,
    String? academicYear,
    required String targetClass,
    String? candidateEmail,
    String? candidatePhone,
    String? candidateWhatsapp,
    String? bacSeries,
    String? bacYear,
    String? bacMention,
    String? bacRollNumber,
    String? previousSchool,
    String? previousGradeAvg,
    required String parentName,
    String parentRelation = 'Père',
    required String parentPhone,
    String? parentWhatsapp,
    String? parentEmail,
    String? parentProfession,
    String? address,
    String city = 'Niamey',
    String? medicalNotes,
    String? birthCertificateUrl,
    String? photoUrl,
    String? idCardPassportUrl,
    String? bacTranscriptUrl,
    String? bacCertificateUrl,
    String? higherEdTranscriptUrl,
    String? cvUrl,
    String? coverLetter,
    String? reportCardUrl,
    int? schoolId,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/admissions/apply',
        {
          'studentFirstName': studentFirstName,
          'studentLastName': studentLastName,
          'dateOfBirth': dateOfBirth,
          'gender': gender,
          'placeOfBirth': placeOfBirth,
          'nationality': nationality,
          'educationLevel': educationLevel ?? 'Université / Supérieur',
          'faculty': faculty,
          'department': department,
          'degreeProgram': degreeProgram ?? targetClass,
          'degreeLevel': degreeLevel,
          'studyMode': studyMode,
          'academicYear': academicYear ?? '2026–2027',
          'targetClass': targetClass,
          'candidateEmail': candidateEmail,
          'candidatePhone': candidatePhone,
          'candidateWhatsapp': candidateWhatsapp,
          'bacSeries': bacSeries,
          'bacYear': bacYear,
          'bacMention': bacMention,
          'bacRollNumber': bacRollNumber,
          'previousSchool': previousSchool,
          'previousGradeAvg': previousGradeAvg,
          'parentName': parentName,
          'parentRelation': parentRelation,
          'parentPhone': parentPhone,
          'parentWhatsapp': parentWhatsapp,
          'parentEmail': parentEmail,
          'parentProfession': parentProfession,
          'address': address,
          'city': city,
          'medicalNotes': medicalNotes,
          'birthCertificateUrl': birthCertificateUrl,
          'photoUrl': photoUrl,
          'idCardPassportUrl': idCardPassportUrl,
          'bacTranscriptUrl': bacTranscriptUrl,
          'bacCertificateUrl': bacCertificateUrl,
          'higherEdTranscriptUrl': higherEdTranscriptUrl,
          'cvUrl': cvUrl,
          'coverLetter': coverLetter,
          'reportCardUrl': reportCardUrl,
          'schoolId': schoolId,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("❌ AdmissionsRepository submitApplication error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check status of applications by parent phone or tracking number
  Future<List<Map<String, dynamic>>> checkApplicationStatus({
    String? phone,
    String? applicationNumber,
  }) async {
    try {
      final queryParams = <String>[];
      if (phone != null && phone.isNotEmpty) queryParams.add('phone=$phone');
      if (applicationNumber != null && applicationNumber.isNotEmpty) {
        queryParams.add('applicationNumber=$applicationNumber');
      }

      final endpoint = '/api/mobile/admissions/status?${queryParams.join('&')}';
      final response = await _apiClient.getJson(endpoint);
      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ AdmissionsRepository checkApplicationStatus error: $e");
      return [];
    }
  }

  /// Admin: list applications
  Future<List<Map<String, dynamic>>> getAdminApplicationsList({
    String status = 'ALL',
    String targetClass = 'ALL',
    String query = '',
  }) async {
    try {
      final endpoint =
          '/api/mobile/admissions/admin/list?status=$status&targetClass=$targetClass&query=$query';
      final response = await _apiClient.getJson(endpoint);
      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ AdmissionsRepository getAdminApplicationsList error: $e");
      return [];
    }
  }

  /// Admin: review and admit candidate with matricule generation
  Future<Map<String, dynamic>> reviewApplication({
    required int applicationId,
    required String decision,
    String? reviewNotes,
    String? assignedClass,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/api/mobile/admissions/admin/review',
        {
          'applicationId': applicationId,
          'decision': decision,
          'reviewNotes': reviewNotes,
          'assignedClass': assignedClass,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("❌ AdmissionsRepository reviewApplication error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
