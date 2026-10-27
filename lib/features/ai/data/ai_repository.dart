import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

class AiRepository {
  final MobileApiClient _apiClient;

  AiRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  Future<String> askAiTutor({
    required String question,
    String? subject,
    String? educationalLevel,
    String? studentName,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/tutor', {
        'question': question,
        'subject': subject ?? 'Général',
        'educationalLevel': educationalLevel ?? 'Secondaire',
        'studentName': studentName ?? '',
      });
      return response['answer']?.toString() ?? 'Aucune réponse générée.';
    } catch (e) {
      debugPrint("AiRepository.askAiTutor error: $e");
      return "Désolé, une erreur de connexion avec le tuteur IA est survenue. Veuillez vérifier votre réseau.";
    }
  }

  Future<Map<String, dynamic>?> getEarlyWarningAnalysis({
    required int studentId,
    int? sessionId,
    String? term,
  }) async {
    try {
      final queryParams = <String>[
        'studentId=$studentId',
        if (sessionId != null) 'sessionId=$sessionId',
        if (term != null && term.isNotEmpty) 'term=${Uri.encodeComponent(term)}',
      ].join('&');

      final response = await _apiClient.getJson(
        '/api/mobile/ai/early-warning?$queryParams',
      );
      return response['data'] != null ? Map<String, dynamic>.from(response['data']) : null;
    } catch (e) {
      debugPrint("AiRepository.getEarlyWarningAnalysis error: $e");
      return null;
    }
  }

  Future<bool> sendEarlyWarningAlert({
    required int studentId,
    required String riskLevel,
    String? message,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/ai/early-warning', {
        'action': 'notifyParent',
        'studentId': studentId,
        'riskLevel': riskLevel,
        'message': message,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint("AiRepository.sendEarlyWarningAlert error: $e");
      return false;
    }
  }

  Future<String> generateGradeAppreciation({
    required String studentName,
    required String subjectName,
    required double score,
    String? className,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateAppreciation',
        'studentName': studentName,
        'subjectName': subjectName,
        'score': score,
        'className': className ?? '',
      });
      return response['appreciation']?.toString() ?? 'Bon travail.';
    } catch (e) {
      debugPrint("AiRepository.generateGradeAppreciation error: $e");
      return "Travail satisfaisant.";
    }
  }

  Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String lessonTitle,
    required String subjectName,
    String? className,
    String? difficulty,
    int count = 4,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateQuiz',
        'lessonTitle': lessonTitle,
        'subjectName': subjectName,
        'className': className ?? '',
        'difficulty': difficulty ?? 'Moyenne',
        'questionCount': count,
      });
      return List<Map<String, dynamic>>.from(response['questions'] ?? []);
    } catch (e) {
      debugPrint("AiRepository.generateQuizQuestions error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> generateFullExam({
    required String lessonTitle,
    required String subjectName,
    required String className,
    int durationMinutes = 120,
    String difficulty = 'Moyen',
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateExam',
        'lessonTitle': lessonTitle,
        'subjectName': subjectName,
        'className': className,
        'durationMinutes': durationMinutes,
        'difficulty': difficulty,
      });
      return response['exam'] != null ? Map<String, dynamic>.from(response['exam']) : null;
    } catch (e) {
      debugPrint("AiRepository.generateFullExam error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateFichePedagogique({
    required String lessonTitle,
    required String subjectName,
    required String className,
    int durationMinutes = 55,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateFichePedagogique',
        'lessonTitle': lessonTitle,
        'subjectName': subjectName,
        'className': className,
        'durationMinutes': durationMinutes,
      });
      return response['fiche'] != null ? Map<String, dynamic>.from(response['fiche']) : null;
    } catch (e) {
      debugPrint("AiRepository.generateFichePedagogique error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateRemediationPlan({
    required String lessonTitle,
    required String subjectName,
    required String className,
    String? difficultyFocus,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/teacher-copilot', {
        'action': 'generateRemediation',
        'lessonTitle': lessonTitle,
        'subjectName': subjectName,
        'className': className,
        'difficultyFocus': difficultyFocus,
      });
      return response['remediation'] != null ? Map<String, dynamic>.from(response['remediation']) : null;
    } catch (e) {
      debugPrint("AiRepository.generateRemediationPlan error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> askVoiceAssistant({
    required String query,
    required String language, // "HA" | "ZA" | "FR"
    int? studentId,
    String? studentName,
    String? studentClass,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/ai/voice-assistant', {
        'query': query,
        'language': language,
        'studentId': studentId,
        'studentName': studentName,
        'studentClass': studentClass,
      });
      return response['data'] != null ? Map<String, dynamic>.from(response['data']) : null;
    } catch (e) {
      debugPrint("AiRepository.askVoiceAssistant error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> gradeExamWithCamera({
    required String imageBase64,
    int? examId,
    int? classId,
    int? studentId,
    String? answerKey,
    String? subjectName,
    double? maxMarks,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/exams/ai/grade-camera', {
        'imageBase64': imageBase64,
        'examId': examId,
        'classId': classId,
        'studentId': studentId,
        'answerKey': answerKey,
        'subjectName': subjectName,
        'maxMarks': maxMarks ?? 20.0,
      });
      return response['data'] != null ? Map<String, dynamic>.from(response['data']) : null;
    } catch (e) {
      debugPrint("AiRepository.gradeExamWithCamera error: $e");
      return null;
    }
  }

  Future<bool> saveGradedExamResult({
    required int examId,
    required int studentId,
    required double marksObtained,
    String? remarks,
    bool notifyParent = true,
  }) async {
    try {
      final response = await _apiClient.postJson('/api/mobile/exams/results', {
        'examId': examId,
        'studentId': studentId,
        'marksObtained': marksObtained,
        'remarks': remarks,
        'notifyParent': notifyParent,
      });
      return response['success'] == true || response['ok'] == true;
    } catch (e) {
      debugPrint("AiRepository.saveGradedExamResult error: $e");
      return false;
    }
  }
}

