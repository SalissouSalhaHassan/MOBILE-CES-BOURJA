import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/di/injection.dart';

class LoginResult {
  final bool success;
  final String? message;

  const LoginResult._({required this.success, this.message});

  const LoginResult.success() : this._(success: true);

  const LoginResult.failure(String message)
    : this._(success: false, message: message);
}

class AuthRepository {
  final SupabaseClient _client;
  final SessionManager _sessionManager;
  final MobileApiClient _mobileApiClient;

  AuthRepository({
    SupabaseClient? client,
    SessionManager? sessionManager,
    MobileApiClient? mobileApiClient,
  }) : _client = client ?? SupabaseClientManager().client,
       _sessionManager = sessionManager ?? SessionManager(),
        _mobileApiClient = mobileApiClient ?? MobileApiClient();

  Future<Map<String, dynamic>?> _resolveStudentProfile({
    required String role,
    required String loginEmail,
    required String? schoolIdStr,
    Map<String, dynamic>? userData,
  }) async {
    final normalizedRole = role.toLowerCase().trim();
    if (normalizedRole != 'student' && normalizedRole != 'parent') {
      return null;
    }

    final username = loginEmail.split('@').first.toLowerCase();
    final schoolId = int.tryParse(schoolIdStr ?? '');

    Future<Map<String, dynamic>?> queryStudentByField(
      String field,
      dynamic value,
    ) async {
      try {
        var query = _client
            .from('students')
            .select(
              'id, school_id, nom_etudiant, classe, num_admission, nom_pere, mobile, whatsapp, educational_level',
            )
            .eq(field, value);
        if (schoolId != null) {
          query = query.eq('school_id', schoolId);
        }
        return await query.maybeSingle();
      } catch (_) {
        return null;
      }
    }

    // 1. First priority: Direct student_id from users table
    final directStudentId = userData?['student_id'];
    if (directStudentId != null) {
      final directStudent = await queryStudentByField('id', directStudentId);
      if (directStudent != null) return directStudent;
    }

    // 2. Secondary check: Query users table if userData didn't include student_id
    try {
      final userRow = await _client
          .from('users')
          .select('student_id, school_id')
          .or('utilisateur.eq.$username,utilisateur.eq.$loginEmail')
          .maybeSingle();
      if (userRow != null && userRow['student_id'] != null) {
        final directStudent = await queryStudentByField('id', userRow['student_id']);
        if (directStudent != null) return directStudent;
      }
    } catch (_) {}

    if (normalizedRole == 'student') {
      final candidates = <Future<Map<String, dynamic>?>>[
        queryStudentByField('num_admission', username),
        queryStudentByField('num_admission', username.toUpperCase()),
        queryStudentByField('num_admission', loginEmail),
        queryStudentByField('mobile', username),
        queryStudentByField('whatsapp', username),
      ];

      for (final candidate in candidates) {
        final data = await candidate;
        if (data != null) return data;
      }
    }

    if (normalizedRole == 'parent') {
      final phoneCandidates = [username, loginEmail, userData?['utilisateur']];
      for (final value in phoneCandidates) {
        if (value == null || value.toString().trim().isEmpty) continue;
        final mobileMatch = await queryStudentByField('mobile', value);
        if (mobileMatch != null) return mobileMatch;
        final whatsappMatch = await queryStudentByField('whatsapp', value);
        if (whatsappMatch != null) return whatsappMatch;
      }

      final parentName = (userData?['nom_prenom'] as String?)?.trim();
      if (parentName != null && parentName.isNotEmpty) {
        try {
          var query = _client
              .from('students')
              .select(
                'id, school_id, nom_etudiant, classe, num_admission, nom_pere, mobile, whatsapp, educational_level',
              )
              .ilike('nom_pere', parentName);
          if (schoolId != null) {
            query = query.eq('school_id', schoolId);
          }
          final rows = await query.limit(1);
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first);
          }
        } catch (_) {}
      }
    }

    return null;
  }

  Future<List<String>> _resolveCandidateLoginEmails(String rawInput) async {
    final clean = rawInput.trim();
    if (clean.isEmpty) return const [];

    final candidates = <String>{};

    // 1. Direct from users table
    try {
      final userRows = await _client
          .from('users')
          .select('utilisateur')
          .or('utilisateur.eq.$clean,utilisateur.eq.${clean.toLowerCase()}')
          .limit(5);
      for (final row in userRows) {
        final u = (row['utilisateur'] as String?)?.trim().toLowerCase();
        if (u != null && u.isNotEmpty) {
          candidates.add(u.contains('@') ? u : '$u@test.com');
        }
      }
    } catch (_) {}

    // 2. From students table (num_admission, mobile, whatsapp)
    try {
      final studentRows = await _client
          .from('students')
          .select('id, num_admission')
          .or('num_admission.eq.$clean,num_admission.eq.${clean.toUpperCase()},num_admission.eq.${clean.toLowerCase()},mobile.eq.$clean,whatsapp.eq.$clean')
          .limit(5);

      for (final student in studentRows) {
        final studentId = student['id'];
        if (studentId != null) {
          final userMatch = await _client
              .from('users')
              .select('utilisateur')
              .eq('student_id', studentId)
              .maybeSingle();
          if (userMatch != null && userMatch['utilisateur'] != null) {
            final u = userMatch['utilisateur'].toString().trim().toLowerCase();
            candidates.add(u.contains('@') ? u : '$u@test.com');
          }
        }
        final adm = (student['num_admission'] as String?)?.trim().toLowerCase();
        if (adm != null && adm.isNotEmpty) {
          candidates.add(adm.contains('@') ? adm : '$adm@test.com');
        }
      }
    } catch (_) {}

    // 3. From employees table (emp_id, email, mobile)
    try {
      final empRows = await _client
          .from('employees')
          .select('id, email, emp_id')
          .or('emp_id.eq.$clean,email.eq.$clean,email.eq.${clean.toLowerCase()},mobile.eq.$clean')
          .limit(5);

      for (final emp in empRows) {
        final empId = emp['id'];
        if (empId != null) {
          final userMatch = await _client
              .from('users')
              .select('utilisateur')
              .eq('employee_id', empId)
              .maybeSingle();
          if (userMatch != null && userMatch['utilisateur'] != null) {
            final u = userMatch['utilisateur'].toString().trim().toLowerCase();
            candidates.add(u.contains('@') ? u : '$u@test.com');
          }
        }
        final emailVal = (emp['email'] as String?)?.trim().toLowerCase();
        if (emailVal != null && emailVal.isNotEmpty) {
          candidates.add(emailVal.contains('@') ? emailVal : '$emailVal@test.com');
        }
        final empIdVal = (emp['emp_id'] as String?)?.trim().toLowerCase();
        if (empIdVal != null && empIdVal.isNotEmpty) {
          candidates.add(empIdVal.contains('@') ? empIdVal : '$empIdVal@test.com');
        }
      }
    } catch (_) {}

    return candidates.toList();
  }

  /// Normalize role name to canonical values: 'teacher', 'admin', 'super_admin', 'director', 'owner', 'student', 'parent', 'accountant', 'secretary', 'staff'
  String _normalizeRole(String? rawRole, bool isAdmin, bool isSuperAdmin) {
    if (isSuperAdmin) {
      return 'super_admin';
    }

    final r = (rawRole ?? '').toLowerCase().trim();
    if (r == 'owner' ||
        r == 'proprietaire' ||
        r == 'propriétaire' ||
        r == 'proprietor' ||
        r.contains('proprietaire') ||
        r.contains('propriétaire') ||
        r.contains('proprietor') ||
        r.contains('owner')) {
      return 'owner';
    }
    if (r == 'director' ||
        r == 'general_director' ||
        r == 'school_director' ||
        r == 'level_director' ||
        r == 'directeur' ||
        r.contains('director') ||
        r.contains('directeur')) {
      return 'director';
    }
    if (r == 'teacher' ||
        r == 'enseignant' ||
        r == 'professeur' ||
        r.contains('teacher') ||
        r.contains('enseignant') ||
        r.contains('professeur')) {
      return 'teacher';
    }
    if (isAdmin || r == 'admin' || r.contains('admin')) {
      return 'admin';
    }
    if (r == 'student' ||
        r == 'eleve' ||
        r == 'élève' ||
        r.contains('student') ||
        r.contains('eleve') ||
        r.contains('élève')) {
      return 'student';
    }
    if (r == 'parent' || r.contains('parent')) {
      return 'parent';
    }
    if (r == 'accountant' ||
        r == 'comptable' ||
        r.contains('comptable') ||
        r.contains('accountant')) {
      return 'accountant';
    }
    if (r == 'secretary' ||
        r == 'secretaire' ||
        r.contains('secrétaire') ||
        r.contains('secretaire') ||
        r.contains('secretary')) {
      return 'secretary';
    }
    if (r == 'personnel' || r.contains('personnel')) {
      return 'personnel';
    }

    if (r.isNotEmpty) {
      return r;
    }

    return 'staff';
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final rawInput = email.trim();
    final normalizedEmail = rawInput.toLowerCase();
    final primaryEmail = normalizedEmail.contains('@')
        ? normalizedEmail
        : '$normalizedEmail@test.com';

    debugPrint("DEBUG LOGIN: Attempting login for $primaryEmail (input: $rawInput) on server: ${MobileApiConfig.baseUrl}");

    final syncEngine = locator.isRegistered<SyncEngine>() ? locator<SyncEngine>() : null;
    if (syncEngine != null && !syncEngine.isOnlineNotifier.value) {
      debugPrint("DEBUG LOGIN: Device is in OFFLINE mode. Directly authenticating via local offline cache...");
      return await _handleOfflineLogin(email, password);
    }

    // 1. PRIMARY STRATEGY: Authenticate against the active Edut Web server selected in UI
    // (e.g. edut-web-xi.vercel.app or custom server)
    try {
      debugPrint("DEBUG LOGIN: Primary attempt via active server API (${MobileApiConfig.baseUrl})...");
      final apiResult = await _mobileApiClient.loginWithApi(
        username: rawInput,
        password: password,
      ).timeout(const Duration(seconds: 8));

      if (apiResult['success'] == true && apiResult['user'] is Map) {
        final userObj = Map<String, dynamic>.from(apiResult['user'] as Map);
        debugPrint("DEBUG LOGIN: Primary API login success! Returning active server session.");
        return await _handleApiLoginSuccess(
          userObj: userObj,
          email: rawInput,
          password: password,
          token: apiResult['token']?.toString(),
          refreshToken: apiResult['refreshToken']?.toString(),
        );
      }
    } catch (apiErr) {
      debugPrint("DEBUG LOGIN: Active server API login attempt result: $apiErr");
      if (_isNetworkException(apiErr)) {
        return await _handleOfflineLogin(email, password);
      }
      if (apiErr is MobileApiException) {
        final errMsg = apiErr.message.toLowerCase();
        // If server explicitly rejected wrong password or username, don't fall back to mismatching local db
        if (errMsg.contains('incorrect') || errMsg.contains('invalide') || errMsg.contains('supprimé')) {
          return LoginResult.failure(apiErr.message);
        }
      }
    }

    // 2. SECONDARY STRATEGY: Standalone direct Supabase auth
    AuthResponse? response;
    String effectiveLoginEmail = primaryEmail;

    try {
      try {
        response = await _client.auth.signInWithPassword(
          email: primaryEmail,
          password: password,
        ).timeout(const Duration(seconds: 8));
      } catch (firstErr) {
        debugPrint("DEBUG LOGIN: Supabase fallback sign-in error with $primaryEmail: $firstErr");
        if (_isNetworkException(firstErr)) {
          rethrow;
        }
        // If primary failed, try to resolve candidate from users/students/employees
        try {
          final candidates = await _resolveCandidateLoginEmails(rawInput).timeout(
            const Duration(seconds: 3),
            onTimeout: () => const [],
          );
          for (final candidate in candidates) {
            if (candidate.toLowerCase() == primaryEmail.toLowerCase()) continue;
            try {
              debugPrint("DEBUG LOGIN: Retrying sign-in with resolved candidate: $candidate");
              response = await _client.auth.signInWithPassword(
                email: candidate,
                password: password,
              ).timeout(const Duration(seconds: 5));
              effectiveLoginEmail = candidate;
              break;
            } catch (retryErr) {
              debugPrint("DEBUG LOGIN: Candidate $candidate failed: $retryErr");
            }
          }
        } catch (_) {}

        if (response == null) {
          rethrow;
        }
      }

      if (response.session == null) {
        debugPrint("DEBUG LOGIN: Session was null");
        return const LoginResult.failure(
          'Session non créée. Veuillez vérifier vos identifiants.',
        );
      }

      debugPrint("DEBUG LOGIN: Auth success. User ID: ${response.user?.id}");

      try {
        final canonicalProfile = await _mobileApiClient
            .getCurrentProfile(accessToken: response.session!.accessToken)
            .timeout(const Duration(seconds: 4));

        await _sessionManager.saveSession(
          token: response.session!.accessToken,
          refreshToken: response.session?.refreshToken,
          email: canonicalProfile.email.isNotEmpty
              ? canonicalProfile.email
              : effectiveLoginEmail,
          password: password,
          role: canonicalProfile.role,
          employeeId: canonicalProfile.employeeId ?? '',
          userId: canonicalProfile.userId,
          schoolId: canonicalProfile.schoolId,
          studentId: canonicalProfile.studentId,
          studentName: canonicalProfile.studentName,
          studentClass: canonicalProfile.studentClass,
          educationalLevel: canonicalProfile.educationalLevel,
          permissions: canonicalProfile.permissions,
        );

        debugPrint(
          "DEBUG LOGIN: Session resolved through Edut web API -> Role: ${canonicalProfile.role}, SchoolId: ${canonicalProfile.schoolId}",
        );
        return const LoginResult.success();
      } on MobileApiException catch (apiErr) {
        if (apiErr.message.contains("Compte non relié") || apiErr.message.contains("supprimé")) {
          debugPrint("DEBUG LOGIN: Account is deleted/unlinked on server. Blocking login: $apiErr");
          await _client.auth.signOut();
          await _sessionManager.clearSession();
          return const LoginResult.failure(
            'Ce compte a été supprimé ou désactivé. Veuillez contacter l\'administrateur.',
          );
        }
        debugPrint("DEBUG LOGIN: Mobile API warning: $apiErr");
      } catch (e, stack) {
        debugPrint(
          "DEBUG LOGIN: Edut web API profile unavailable, using fast Supabase fallback: $e\n$stack",
        );
      }

      String role = 'staff';
      String? schoolIdStr;
      Map<String, dynamic>? userData;

      // 1. Fetch user profile with role join
      try {
        userData = await _fetchUserProfile(
          userId: response.session!.user.id,
          email: effectiveLoginEmail,
          select:
              'id, utilisateur, nom_prenom, admin, super_admin, school_id, role_id, student_id, roles(role_name)',
        );

        debugPrint("DEBUG LOGIN: Profile data fetched: $userData");

        if (userData != null) {
          final isSuperAdmin = userData['super_admin'] == true;
          final isAdmin = userData['admin'] == true;
          final rawRoleName = userData['roles']?['role_name'] as String?;
          schoolIdStr = userData['school_id']?.toString();

          role = _normalizeRole(rawRoleName, isAdmin, isSuperAdmin);
          debugPrint("DEBUG LOGIN: Normalized role from profile: $role");

          // If role still unresolved and role_id exists, fetch separately
          if (role == 'staff' &&
              userData['role_id'] != null &&
              !isAdmin &&
              !isSuperAdmin) {
            try {
              final roleData = await _client
                  .from('roles')
                  .select('role_name')
                  .eq('id', userData['role_id'])
                  .maybeSingle();
              debugPrint("DEBUG LOGIN: Separate role fetch result: $roleData");
              if (roleData != null) {
                role = _normalizeRole(
                  roleData['role_name'] as String?,
                  false,
                  false,
                );
                debugPrint("DEBUG LOGIN: Normalized separate role: $role");
              }
            } catch (e) {
              debugPrint("DEBUG LOGIN: Separate role fetch failed: $e");
            }
          }
        }
      } catch (e, stack) {
        debugPrint(
          "DEBUG LOGIN: Error fetching user profile with join: $e\n$stack",
        );
        // Fallback: query without roles join
        try {
          userData = await _fetchUserProfile(
            userId: response.session!.user.id,
            email: effectiveLoginEmail,
            select:
                'id, utilisateur, nom_prenom, admin, super_admin, school_id, role_id, student_id',
          );

          debugPrint("DEBUG LOGIN: Fallback profile data: $userData");

          if (userData != null) {
            final isSuperAdmin = userData['super_admin'] == true;
            final isAdmin = userData['admin'] == true;
            schoolIdStr = userData['school_id']?.toString();

            if (isSuperAdmin) {
              role = 'super_admin';
            } else if (isAdmin) {
              role = 'admin';
            } else {
              final roleId = userData['role_id'];
              if (roleId != null) {
                try {
                  final roleData = await _client
                      .from('roles')
                      .select('role_name')
                      .eq('id', roleId)
                      .maybeSingle();
                  debugPrint(
                    "DEBUG LOGIN: Fallback separate role data: $roleData",
                  );
                  if (roleData != null) {
                    role = _normalizeRole(
                      roleData['role_name'] as String?,
                      false,
                      false,
                    );
                  }
                } catch (_) {}
              }
            }
            debugPrint("DEBUG LOGIN: Role resolved in fallback: $role");
          }
        } catch (err, st) {
          debugPrint("DEBUG LOGIN: Fallback profile fetch failed: $err\n$st");
        }
      }

      // 2. Query employees table to get employee ID
      String employeeId = '';
      Map<String, dynamic>? employeeData;
      try {
        employeeData = await _client
            .from('employees')
            .select('id, school_id')
            .eq('email', effectiveLoginEmail)
            .maybeSingle();

        debugPrint("DEBUG LOGIN: Employee query result: $employeeData");

        if (employeeData != null) {
          employeeId = employeeData['id'].toString();
          // If school_id was not fetched from users, get from employees
          schoolIdStr ??= employeeData['school_id']?.toString();
          // If role is still generic 'staff' and we found in employees → teacher
          if (role == 'staff') {
            role = 'teacher';
            debugPrint(
              "DEBUG LOGIN: Role set to teacher since employee record exists",
            );
          }
        }
      } catch (e, stack) {
        debugPrint("DEBUG LOGIN: Employee fetch failed: $e\n$stack");
      }

      final studentProfile = await _resolveStudentProfile(
        role: role,
        loginEmail: effectiveLoginEmail,
        schoolIdStr: schoolIdStr,
        userData: userData,
      );

      // CRITICAL CHECK: If user does not exist in users table AND not in employees AND not in students
      if (userData == null && employeeData == null && studentProfile == null) {
        debugPrint("DEBUG LOGIN: Account is deleted (no record in users, employees, or students). Rejecting login.");
        await _client.auth.signOut();
        await _sessionManager.clearSession();
        return const LoginResult.failure(
          'Ce compte a été supprimé ou n\'existe plus. Veuillez contacter l\'administrateur.',
        );
      }

      if ((role == 'student' || role == 'parent') && studentProfile == null) {
        debugPrint(
          "WARNING: $role account logged in but no linked student record was found.",
        );
      }

      if (studentProfile != null && schoolIdStr == null) {
        schoolIdStr = studentProfile['school_id']?.toString();
      }

      debugPrint(
        "DEBUG LOGIN: Final resolved values for SessionManager -> Email: $effectiveLoginEmail, Role: $role, EmployeeId: $employeeId, SchoolId: $schoolIdStr",
      );

      await _sessionManager.saveSession(
        token: response.session!.accessToken,
        refreshToken: response.session?.refreshToken,
        email: effectiveLoginEmail,
        password: password,
        role: role,
        employeeId: employeeId,
        userId: userData?['id']?.toString(),
        schoolId: schoolIdStr,
        studentId: studentProfile?['id']?.toString(),
        studentName: studentProfile?['nom_etudiant'] as String?,
        studentClass: studentProfile?['classe'] as String?,
      );

      return const LoginResult.success();
    } on AuthException catch (e) {
      debugPrint("DEBUG LOGIN: AuthException during login: $e");
      if (_isNetworkException(e) || _isNetworkException(e.message)) {
        return await _handleOfflineLogin(email, password);
      }

      final message = e.message.toLowerCase();
      // On any authentication issue or rejection by Supabase, try Edut Web Backend API first!
      try {
        debugPrint("DEBUG LOGIN: Attempting authentication via Edut Web Backend API fallback...");
        final apiResult = await _mobileApiClient.loginWithApi(
          username: email,
          password: password,
        ).timeout(const Duration(seconds: 10));

        if (apiResult['success'] == true && apiResult['user'] is Map) {
          final userObj = Map<String, dynamic>.from(apiResult['user'] as Map);
          return await _handleApiLoginSuccess(
            userObj: userObj,
            email: email,
            password: password,
            token: apiResult['token']?.toString(),
            refreshToken: apiResult['refreshToken']?.toString(),
          );
        }
      } catch (apiErr) {
        debugPrint("DEBUG LOGIN: Backend API login fallback error: $apiErr");
        if (apiErr is MobileApiException) {
          return LoginResult.failure(apiErr.message);
        }
      }

      if (message.contains('invalid login credentials') ||
          message.contains('user not found') ||
          message.contains('invalid credentials')) {
        return const LoginResult.failure('Email ou mot de passe incorrect.');
      }
      if (message.contains('email not confirmed')) {
        return const LoginResult.failure(
          'Veuillez confirmer cet email avant de vous connecter.',
        );
      }
      if (message.contains('too many requests')) {
        return const LoginResult.failure(
          'Trop de tentatives. Veuillez patienter quelques instants avant de réessayer.',
        );
      }

      final cleanMsg = e.message.split('uri=').first.replaceAll('Exception:', '').trim();
      return LoginResult.failure(
        cleanMsg.isNotEmpty
            ? 'Erreur d\'authentification : $cleanMsg'
            : 'Erreur d\'authentification. Veuillez vérifier vos identifiants.',
      );
    } catch (e, stack) {
      debugPrint("DEBUG LOGIN: Network or unexpected error during login: $e\n$stack");
      if (_isNetworkException(e)) {
        return await _handleOfflineLogin(email, password);
      }

      // Try Backend API fallback on any unexpected error
      try {
        debugPrint("DEBUG LOGIN: Unexpected error caught, attempting Backend API fallback...");
        final apiResult = await _mobileApiClient.loginWithApi(
          username: email,
          password: password,
        ).timeout(const Duration(seconds: 10));

        if (apiResult['success'] == true && apiResult['user'] is Map) {
          final userObj = Map<String, dynamic>.from(apiResult['user'] as Map);
          return await _handleApiLoginSuccess(
            userObj: userObj,
            email: email,
            password: password,
            token: apiResult['token']?.toString(),
            refreshToken: apiResult['refreshToken']?.toString(),
          );
        }
      } catch (apiErr) {
        debugPrint("DEBUG LOGIN: Backend API login fallback after unexpected error failed: $apiErr");
        if (apiErr is MobileApiException) {
          return LoginResult.failure(apiErr.message);
        }
      }

      return const LoginResult.failure(
        'Impossible de se connecter. Vérifiez votre connexion Internet ou vos identifiants.',
      );
    }
  }

  Future<LoginResult> _handleApiLoginSuccess({
    required Map<String, dynamic> userObj,
    required String email,
    required String password,
    String? token,
    String? refreshToken,
  }) async {
    try {
      final isSuperAdmin = userObj['superAdmin'] == true;
      final isAdmin = userObj['admin'] == true;
      final roleMap = userObj['role'] is Map ? Map<String, dynamic>.from(userObj['role'] as Map) : null;
      final rawRoleName = roleMap?['roleName'] as String?;
      final role = _normalizeRole(rawRoleName, isAdmin, isSuperAdmin);

      final schoolIdStr = userObj['schoolId']?.toString() ??
          (userObj['school'] is Map ? userObj['school']['id']?.toString() : null);

      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : (_client.auth.currentSession?.accessToken ?? 'edut_session_${DateTime.now().millisecondsSinceEpoch}');

      final permissionsList = <String>[];
      if (roleMap?['permissions'] is List) {
        permissionsList.addAll(
          (roleMap!['permissions'] as List).map((p) => p.toString()),
        );
      }

      await _sessionManager.saveSession(
        token: effectiveToken,
        refreshToken: refreshToken,
        email: userObj['utilisateur']?.toString() ?? email,
        password: password,
        role: role,
        employeeId: userObj['employeeId']?.toString() ?? '',
        userId: userObj['id']?.toString(),
        schoolId: schoolIdStr,
        studentId: userObj['studentId']?.toString(),
        educationalLevel: userObj['educationalLevel']?.toString(),
        permissions: permissionsList.isNotEmpty ? permissionsList : null,
      );

      debugPrint("DEBUG LOGIN: Backend API login succeeded for ${userObj['utilisateur']} with role $role (School: $schoolIdStr)");
      return const LoginResult.success();
    } catch (saveErr) {
      debugPrint("DEBUG LOGIN: Error saving API login session: $saveErr");
      return const LoginResult.failure('Erreur lors de la sauvegarde de la session.');
    }
  }

  bool _isNetworkException(dynamic e) {
    if (e == null) return false;
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('clientexception') ||
        str.contains('failed host lookup') ||
        str.contains('no address associated with hostname') ||
        str.contains('network is unreachable') ||
        str.contains('connection refused') ||
        str.contains('connection timed out') ||
        str.contains('connection closed') ||
        str.contains('handshakeexception') ||
        str.contains('timeoutexception') ||
        str.contains('délai') ||
        str.contains('network error') ||
        str.contains('xmlhttprequest') ||
        str.contains('http client error') ||
        str.contains('errno = 7') ||
        str.contains('errno = 101') ||
        str.contains('errno = 110') ||
        str.contains('errno = 111') ||
        str.contains('offline');
  }

  Future<LoginResult> _handleOfflineLogin(String email, String password) async {
    final offlineCheck =
        await _sessionManager.validateOfflineCredentialsDetailed(
      email,
      password,
    );
    if (offlineCheck == OfflineAuthResult.success) {
      debugPrint("DEBUG LOGIN: Offline login validation succeeded!");
      return const LoginResult.success();
    } else if (offlineCheck == OfflineAuthResult.wrongPassword) {
      return const LoginResult.failure(
        'Mode hors-ligne : Mot de passe incorrect pour le compte enregistré sur cet appareil.',
      );
    } else if (offlineCheck == OfflineAuthResult.userMismatch) {
      return const LoginResult.failure(
        'Mode hors-ligne : Cet appareil est associé à un autre compte. Veuillez vous connecter avec le compte enregistré ou vous connecter à Internet.',
      );
    } else if (offlineCheck == OfflineAuthResult.noCachedUser) {
      return const LoginResult.failure(
        'Connexion Internet indisponible. Une première connexion avec accès réseau est requise sur cet appareil.',
      );
    }
    return const LoginResult.failure(
      'Connexion Internet indisponible. Veuillez vérifier votre réseau.',
    );
  }

  Future<Map<String, dynamic>?> _fetchUserProfile({
    required String userId,
    required String email,
    required String select,
  }) async {
    final username = email.split('@').first;

    final bySupabaseId = await _client
        .from('users')
        .select(select)
        .eq('supabase_id', userId)
        .maybeSingle();
    if (bySupabaseId != null) return bySupabaseId;

    final byEmail = await _client
        .from('users')
        .select(select)
        .eq('utilisateur', email)
        .maybeSingle();
    if (byEmail != null) return byEmail;

    return _client
        .from('users')
        .select(select)
        .eq('utilisateur', username)
        .maybeSingle();
  }

  Future<LoginResult> register({
    required String role,
    required String schoolSlug,
    required String matriculeOrEmail,
    required String username,
    required String fullName,
    required String password,
    required String activationPin,
  }) async {
    try {
      await _mobileApiClient.register(
        role: role,
        schoolSlug: schoolSlug,
        matriculeOrEmail: matriculeOrEmail,
        username: username,
        fullName: fullName,
        password: password,
        activationPin: activationPin,
      );
      return const LoginResult.success();
    } on MobileApiException catch (e) {
      return LoginResult.failure(e.message);
    } catch (e) {
      return LoginResult.failure(e.toString());
    }
  }

  Future<Map<String, dynamic>?> resetPassword({
    required String role,
    required String schoolSlug,
    required String matriculeOrEmail,
    required String verificationCodeOrPhone,
    String? newPassword,
  }) async {
    try {
      final data = await _mobileApiClient.resetPassword(
        role: role,
        schoolSlug: schoolSlug,
        matriculeOrEmail: matriculeOrEmail,
        verificationCodeOrPhone: verificationCodeOrPhone,
        newPassword: newPassword,
      );
      return data;
    } on MobileApiException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> logout() async {
    // NOTE: We deliberately do NOT wipe educational data caches (students, classes, fees, results)
    // on logout so that the user or any offline-authorized user on this device can continue
    // accessing and verifying school data while offline.
    await _client.auth.signOut();
    await _sessionManager.clearSession();
  }
}
