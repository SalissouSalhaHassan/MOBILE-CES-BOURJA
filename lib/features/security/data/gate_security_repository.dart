import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';

class GateSecurityRepository {
  final MobileApiClient _apiClient;

  GateSecurityRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? locator<MobileApiClient>();

  /// Scan a student QR code and retrieve instant security / gate status
  Future<Map<String, dynamic>> scanGatePass({
    required String qrPayload,
    String? action, // 'scan', 'entry', 'exit'
    String? note,
  }) async {
    try {
      final res = await _apiClient.postJson(
        '/api/mobile/security/gate-scan',
        {
          'qrPayload': qrPayload.trim(),
          if (action != null) 'action': action,
          if (note != null) 'note': note,
        },
      );

      return res;
    } catch (e) {
      debugPrint('Gate pass scan error: $e');
      return {
        'success': false,
        'valid': false,
        'alertLevel': 'red',
        'message': 'Erreur de connexion lors de la vérification du pass : $e',
      };
    }
  }
}
