import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

enum OfflineAuthResult {
  success,
  wrongPassword,
  userMismatch,
  noCachedUser,
}

class SessionManager {
  final _storage = const FlutterSecureStorage();

  static const String _keyToken = 'auth_token';
  static const String _keyEmail = 'auth_email';
  static const String _keyPasswordHash = 'auth_password_hash';
  static const String _keyRole = 'auth_role';
  static const String _keyEmployeeId = 'auth_employee_id';
  static const String _keySchoolId = 'auth_school_id';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyStudentId = 'auth_student_id';
  static const String _keyStudentName = 'auth_student_name';
  static const String _keyStudentClass = 'auth_student_class';
  static const String _keyPermissions = 'auth_permissions';
  static const String _keyEducationalLevel = 'auth_educational_level';
  static const String _keyOfflineProfile = 'auth_offline_profile_json';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyCustomServerUrl = 'custom_server_url';

  Future<void> setCustomServerUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _storage.delete(key: _keyCustomServerUrl);
    } else {
      await _storage.write(key: _keyCustomServerUrl, value: url.trim());
    }
  }

  Future<String?> getCustomServerUrl() async {
    return await _storage.read(key: _keyCustomServerUrl);
  }

  Future<void> saveSession({
    required String token,
    required String email,
    required String role,
    required String employeeId,
    String? refreshToken,
    String? password,
    String? userId,
    String? schoolId,
    String? studentId,
    String? studentName,
    String? studentClass,
    String? educationalLevel,
    List<String>? permissions,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    await _storage.write(key: _keyEmail, value: email.toLowerCase().trim());
    
    String? effectivePasswordHash;
    if (password != null && password.isNotEmpty) {
      effectivePasswordHash = sha256.convert(utf8.encode(password)).toString();
      await _storage.write(key: _keyPasswordHash, value: effectivePasswordHash);
    } else {
      effectivePasswordHash = await _storage.read(key: _keyPasswordHash);
    }

    await _storage.write(key: _keyRole, value: role);
    await _storage.write(key: _keyEmployeeId, value: employeeId);
    if (userId != null) {
      await _storage.write(key: _keyUserId, value: userId);
    }
    if (schoolId != null) {
      await _storage.write(key: _keySchoolId, value: schoolId);
    }
    if (studentId != null) {
      await _storage.write(key: _keyStudentId, value: studentId);
    }
    if (studentName != null) {
      await _storage.write(key: _keyStudentName, value: studentName);
    }
    if (studentClass != null) {
      await _storage.write(key: _keyStudentClass, value: studentClass);
    }
    if (educationalLevel != null) {
      await _storage.write(key: _keyEducationalLevel, value: educationalLevel);
    }
    if (permissions != null) {
      await _storage.write(
        key: _keyPermissions,
        value: jsonEncode(permissions),
      );
    }

    // Persist complete offline profile backup to allow login even when network is completely offline
    try {
      final cleanEmail = email.toLowerCase().trim();
      final offlineProfile = {
        'email': cleanEmail,
        'passwordHash': effectivePasswordHash,
        'role': role,
        'employeeId': employeeId,
        'userId': userId,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'studentClass': studentClass,
        'educationalLevel': educationalLevel,
        'permissions': permissions,
      };
      await _storage.write(
        key: _keyOfflineProfile,
        value: jsonEncode(offlineProfile),
      );

      // Also persist into multi-account offline registry so any logged-in user can log back in offline
      final accountsRaw = await _storage.read(key: _keyOfflineAccounts);
      Map<String, dynamic> accounts = {};
      if (accountsRaw != null && accountsRaw.isNotEmpty) {
        try {
          accounts = jsonDecode(accountsRaw) as Map<String, dynamic>;
        } catch (_) {}
      }
      accounts[cleanEmail] = offlineProfile;
      final usernameKey = cleanEmail.split('@').first;
      accounts[usernameKey] = offlineProfile;
      await _storage.write(key: _keyOfflineAccounts, value: jsonEncode(accounts));
    } catch (_) {}
  }

  static const String _keyOfflineAccounts = 'auth_offline_accounts_map';

  Future<String?> getToken() async => await _storage.read(key: _keyToken);
  Future<String?> getRefreshToken() async => await _storage.read(key: _keyRefreshToken);

  Future<void> updateAccessToken(String token, [String? refreshToken]) async {
    await _storage.write(key: _keyToken, value: token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
  }

  Future<String?> getEmail() async => await _storage.read(key: _keyEmail);
  Future<String?> getRole() async => await _storage.read(key: _keyRole);
  Future<String?> getEmployeeId() async =>
      await _storage.read(key: _keyEmployeeId);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getSchoolId() async => await _storage.read(key: _keySchoolId);
  Future<String?> getStudentId() async =>
      await _storage.read(key: _keyStudentId);
  Future<String?> getStudentName() async =>
      await _storage.read(key: _keyStudentName);
  Future<String?> getUserName() async {
    final name = await getStudentName();
    if (name != null && name.isNotEmpty) return name;
    return await getEmail();
  }
  Future<String?> getStudentClass() async =>
      await _storage.read(key: _keyStudentClass);
  Future<String?> getEducationalLevel() async =>
      await _storage.read(key: _keyEducationalLevel);

  Future<void> savePermissions(List<String> permissions) async {
    await _storage.write(
      key: _keyPermissions,
      value: jsonEncode(permissions),
    );
  }

  Future<List<String>> getPermissions() async {
    final rawValue = await _storage.read(key: _keyPermissions);
    if (rawValue == null || rawValue.isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {}

    return const [];
  }

  Future<String?> getCachedOfflineEmail() async {
    final email = await getEmail();
    if (email != null && email.isNotEmpty) return email;

    final offlineRaw = await _storage.read(key: _keyOfflineProfile);
    if (offlineRaw != null && offlineRaw.isNotEmpty) {
      try {
        final data = jsonDecode(offlineRaw) as Map<String, dynamic>?;
        return data?['email']?.toString();
      } catch (_) {}
    }
    return null;
  }

  Future<OfflineAuthResult> validateOfflineCredentialsDetailed(
    String email,
    String password,
  ) async {
    final normalizedInput = email.toLowerCase().trim();
    final inputUsername = normalizedInput.split('@').first;

    // 1. First check multi-account registry
    Map<String, dynamic>? matchingProfile;
    try {
      final accountsRaw = await _storage.read(key: _keyOfflineAccounts);
      if (accountsRaw != null && accountsRaw.isNotEmpty) {
        final accounts = jsonDecode(accountsRaw) as Map<String, dynamic>;
        if (accounts.containsKey(normalizedInput)) {
          matchingProfile = Map<String, dynamic>.from(accounts[normalizedInput] as Map);
        } else if (accounts.containsKey(inputUsername)) {
          matchingProfile = Map<String, dynamic>.from(accounts[inputUsername] as Map);
        }
      }
    } catch (_) {}

    // 2. If not found in registry, check primary offline profile
    var cachedEmail = await getEmail();
    var cachedHash = await _storage.read(key: _keyPasswordHash);

    Map<String, dynamic>? offlineData;
    final offlineRaw = await _storage.read(key: _keyOfflineProfile);
    if (offlineRaw != null && offlineRaw.isNotEmpty) {
      try {
        offlineData = jsonDecode(offlineRaw) as Map<String, dynamic>?;
      } catch (_) {}
    }

    if (matchingProfile != null) {
      offlineData = matchingProfile;
      cachedEmail = offlineData['email']?.toString();
      cachedHash = offlineData['passwordHash']?.toString();
    } else {
      if ((cachedEmail == null || cachedEmail.isEmpty) && offlineData != null) {
        cachedEmail = offlineData['email']?.toString();
        cachedHash ??= offlineData['passwordHash']?.toString();
      }
    }

    if (cachedEmail == null || cachedEmail.isEmpty) {
      return OfflineAuthResult.noCachedUser;
    }

    final cachedUsername = cachedEmail.toLowerCase().split('@').first;
    final emailMatches =
        normalizedInput == cachedEmail.toLowerCase() || inputUsername == cachedUsername;
    if (!emailMatches) {
      return OfflineAuthResult.userMismatch;
    }

    if (cachedHash != null && cachedHash.isNotEmpty) {
      final inputHash = sha256.convert(utf8.encode(password)).toString();
      if (cachedHash != inputHash) {
        return OfflineAuthResult.wrongPassword;
      }
    }

    // Ensure session is properly populated and activated
    final currentToken = await getToken();
    if (currentToken == null || currentToken.isEmpty) {
      await _storage.write(key: _keyToken, value: 'offline_session_token');
    }
    await _storage.write(key: _keyEmail, value: cachedEmail);
    if (cachedHash != null && cachedHash.isNotEmpty) {
      await _storage.write(key: _keyPasswordHash, value: cachedHash);
    }

    if (offlineData != null) {
      if (offlineData['role'] != null) {
        await _storage.write(
          key: _keyRole,
          value: offlineData['role'].toString(),
        );
      }
      if (offlineData['employeeId'] != null) {
        await _storage.write(
          key: _keyEmployeeId,
          value: offlineData['employeeId'].toString(),
        );
      }
      if (offlineData['userId'] != null) {
        await _storage.write(
          key: _keyUserId,
          value: offlineData['userId'].toString(),
        );
      }
      if (offlineData['schoolId'] != null) {
        await _storage.write(
          key: _keySchoolId,
          value: offlineData['schoolId'].toString(),
        );
      }
      if (offlineData['studentId'] != null) {
        await _storage.write(
          key: _keyStudentId,
          value: offlineData['studentId'].toString(),
        );
      }
      if (offlineData['studentName'] != null) {
        await _storage.write(
          key: _keyStudentName,
          value: offlineData['studentName'].toString(),
        );
      }
      if (offlineData['studentClass'] != null) {
        await _storage.write(
          key: _keyStudentClass,
          value: offlineData['studentClass'].toString(),
        );
      }
      if (offlineData['educationalLevel'] != null) {
        await _storage.write(
          key: _keyEducationalLevel,
          value: offlineData['educationalLevel'].toString(),
        );
      }
      if (offlineData['permissions'] != null) {
        await _storage.write(
          key: _keyPermissions,
          value: jsonEncode(offlineData['permissions']),
        );
      }
    }

    return OfflineAuthResult.success;
  }

  Future<bool> restoreSessionFromOfflineProfile() async {
    final offlineRaw = await _storage.read(key: _keyOfflineProfile);
    if (offlineRaw != null && offlineRaw.isNotEmpty) {
      try {
        final data = jsonDecode(offlineRaw) as Map<String, dynamic>?;
        if (data != null && data['email'] != null && data['role'] != null) {
          await _storage.write(key: _keyEmail, value: data['email'].toString());
          await _storage.write(key: _keyRole, value: data['role'].toString());
          final currentToken = await getToken();
          if (currentToken == null || currentToken.isEmpty) {
            await _storage.write(key: _keyToken, value: 'biometric_session_token');
          }
          if (data['employeeId'] != null) await _storage.write(key: _keyEmployeeId, value: data['employeeId'].toString());
          if (data['userId'] != null) await _storage.write(key: _keyUserId, value: data['userId'].toString());
          if (data['schoolId'] != null) await _storage.write(key: _keySchoolId, value: data['schoolId'].toString());
          if (data['studentId'] != null) await _storage.write(key: _keyStudentId, value: data['studentId'].toString());
          if (data['studentName'] != null) await _storage.write(key: _keyStudentName, value: data['studentName'].toString());
          if (data['studentClass'] != null) await _storage.write(key: _keyStudentClass, value: data['studentClass'].toString());
          if (data['educationalLevel'] != null) await _storage.write(key: _keyEducationalLevel, value: data['educationalLevel'].toString());
          if (data['permissions'] != null) await _storage.write(key: _keyPermissions, value: jsonEncode(data['permissions']));
          return true;
        }
      } catch (_) {}
    }
    return false;
  }


  Future<bool> validateOfflineCredentials(String email, String password) async {
    final res = await validateOfflineCredentialsDetailed(email, password);
    return res == OfflineAuthResult.success;
  }

  Future<bool> validateCurrentPassword(String password) async {
    final cachedHash = await _storage.read(key: _keyPasswordHash);
    if (cachedHash != null && cachedHash.isNotEmpty) {
      final inputHash = sha256.convert(utf8.encode(password)).toString();
      return cachedHash == inputHash;
    }
    return false;
  }

  Future<int> getInactivityTimeoutMinutes() async {
    final raw = await _storage.read(key: 'auth_inactivity_minutes');
    if (raw != null) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 3; // Default 3 minutes as requested
  }

  Future<void> setInactivityTimeoutMinutes(int minutes) async {
    await _storage.write(key: 'auth_inactivity_minutes', value: minutes.toString());
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) return true;
    final email = await getEmail();
    final role = await getRole();
    return email != null && email.isNotEmpty && role != null && role.isNotEmpty;
  }

  static const String _keyPinHash = 'auth_pin_hash';
  static const String _keyPinEnabled = 'auth_pin_enabled';

  Future<void> setOfflinePin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length >= 4) {
      final pinHash = sha256.convert(utf8.encode(cleanPin)).toString();
      await _storage.write(key: _keyPinHash, value: pinHash);
      await _storage.write(key: _keyPinEnabled, value: 'true');
    }
  }

  Future<bool> hasOfflinePin() async {
    final enabled = await _storage.read(key: _keyPinEnabled);
    final hash = await _storage.read(key: _keyPinHash);
    return enabled == 'true' && hash != null && hash.isNotEmpty;
  }

  Future<bool> validateOfflinePin(String pin) async {
    final savedHash = await _storage.read(key: _keyPinHash);
    if (savedHash == null || savedHash.isEmpty) return false;
    final inputHash = sha256.convert(utf8.encode(pin.trim())).toString();
    if (savedHash == inputHash) {
      // Ensure offline session token is alive
      final currentToken = await getToken();
      if (currentToken == null || currentToken.isEmpty) {
        await _storage.write(key: _keyToken, value: 'offline_pin_session_token');
      }
      return true;
    }
    return false;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyEmail);
    // Keep _keyPasswordHash and _keyOfflineProfile intact so that offline authentication
    // and PIN verification can work seamlessly even when logging out or opening the app offline!
    await _storage.delete(key: _keyRole);
    await _storage.delete(key: _keyEmployeeId);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keySchoolId);
    await _storage.delete(key: _keyStudentId);
    await _storage.delete(key: _keyStudentName);
    await _storage.delete(key: _keyStudentClass);
    await _storage.delete(key: _keyPermissions);
    await _storage.delete(key: _keyEducationalLevel);
  }

  /// Completely purge cached offline accounts and device lock binding
  Future<void> purgeOfflineProfileAndAccounts() async {
    await clearSession();
    await _storage.delete(key: _keyPasswordHash);
    await _storage.delete(key: _keyOfflineProfile);
    await _storage.delete(key: _keyOfflineAccounts);
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinEnabled);
  }
}
