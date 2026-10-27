import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../auth/session_manager.dart';
import '../di/injection.dart';

class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if hardware supports biometrics and has enrolled fingerprints/face
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('[BiometricAuthService] Check error: $e');
      return false;
    }
  }

  /// Get list of available biometric types (e.g. fingerprint, face, weak, strong)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('[BiometricAuthService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Authenticate the user with biometrics
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous par empreinte ou reconnaissance faciale pour accéder à Edut',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('[BiometricAuthService] Authentication error: $e');
      return false;
    }
  }

  /// Check if biometric login is enabled by user in settings
  Future<bool> isBiometricLoginEnabled() async {
    final session = locator<SessionManager>();
    final email = await session.getEmail();
    if (email == null || email.isEmpty) return false;
    return true; // Enabled if previously logged in on device
  }
}
