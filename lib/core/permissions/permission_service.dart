import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../api/supabase_client.dart';
import '../auth/session_manager.dart';
import '../api/mobile_api_client.dart';

class AppPermissions {
  static const ownerPlatformView = 'owner.platform.view';
  static const ownerSchoolsManage = 'owner.schools.manage';
  static const studentsView = 'students.view';
  static const studentsCreate = 'students.create';
  static const studentsEdit = 'students.edit';
  static const studentsDelete = 'students.delete';
  static const studentsPromote = 'students.promote';
  static const financeView = 'finance.view';
  static const financeCollect = 'finance.collect';
  static const hrView = 'hr.view';
  static const hrManage = 'hr.manage';
  static const hostelView = 'hostel.view';
  static const hostelManage = 'hostel.manage';
  static const examsView = 'exams.view';
  static const examsManage = 'exams.manage';
  static const attendanceView = 'attendance.view';
  static const attendanceManage = 'attendance.manage';
  static const academicsView = 'academics.view';
  static const academicsManage = 'academics.manage';
  static const saisieNotesView = 'academics.saisieNotes.view';
  static const saisieNotesEdit = 'academics.saisieNotes.edit';
  static const gestionDevoirsView = 'academics.gestionDevoirs.view';
  static const gestionDevoirsEdit = 'academics.gestionDevoirs.edit';
  static const messagingView = 'messaging.view';
  static const messagingManage = 'messaging.manage';
}

class UserAccessProfile {
  const UserAccessProfile({required this.role, required this.permissions});

  final String role;
  final Set<String> permissions;
}

class PermissionService {
  PermissionService({required SessionManager sessionManager})
    : _sessionManager = sessionManager;

  final SessionManager _sessionManager;
  final _client = SupabaseClientManager().client;
  UserAccessProfile? _cachedProfile;
  String? _cachedCacheKey;

  Future<UserAccessProfile> getCurrentProfile({bool forceRefresh = false}) async {
    final role = ((await _sessionManager.getRole()) ?? 'staff')
        .toLowerCase()
        .trim();
    final userId = await _sessionManager.getUserId();
    final email =
        (await _sessionManager.getEmail())?.toLowerCase().trim() ?? '';
    final cacheKey = '$userId|$email|$role';

    if (!forceRefresh && _cachedProfile != null && _cachedCacheKey == cacheKey) {
      return _cachedProfile!;
    }

    try {
      final apiProfile = await MobileApiClient().getCurrentProfile();
      if (apiProfile.role.isNotEmpty || apiProfile.permissions.isNotEmpty) {
        if (apiProfile.permissions.isNotEmpty) {
          await _sessionManager.savePermissions(apiProfile.permissions);
        }
        final effectiveRole = apiProfile.role.isNotEmpty && apiProfile.role != 'staff'
            ? apiProfile.role
            : (role.isNotEmpty && role != 'staff' ? role : apiProfile.role);

        final profile = UserAccessProfile(
          role: effectiveRole,
          permissions: apiProfile.permissions.isNotEmpty
              ? apiProfile.permissions.toSet()
              : _permissionsForRole(effectiveRole),
        );
        _cachedProfile = profile;
        _cachedCacheKey = cacheKey;
        return profile;
      }
    } catch (e) {
      debugPrint('PermissionService Web API lookup error: $e');
    }

    final sessionPermissions = await _sessionManager.getPermissions();
    if (sessionPermissions.isNotEmpty || (role.isNotEmpty && role != 'staff')) {
      final profile = UserAccessProfile(
        role: role,
        permissions: sessionPermissions.isNotEmpty
            ? sessionPermissions.toSet()
            : _permissionsForRole(role),
      );
      _cachedProfile = profile;
      _cachedCacheKey = cacheKey;
      return profile;
    }

    try {
      final profile = await _loadProfileFromDatabase(
        fallbackRole: role,
        userId: userId,
        email: email,
      );
      _cachedProfile = profile;
      _cachedCacheKey = cacheKey;
      return profile;
    } catch (e) {
      debugPrint('PermissionService DB lookup error: $e');
    }

    final profile = UserAccessProfile(
      role: role,
      permissions: _permissionsForRole(role),
    );
    _cachedProfile = profile;
    _cachedCacheKey = cacheKey;
    return profile;
  }

  Future<bool> hasPermission(String permission) async {
    final profile = await getCurrentProfile();
    final role = profile.role.toLowerCase().trim();

    // 1. Super Admin, Owner, Director, General Director, Admin, Censeur, Surveillant have broad access
    if (role == 'super_admin' ||
        role == 'owner' ||
        role == 'director' ||
        role == 'directeur' ||
        role == 'admin' ||
        role == 'censeur' ||
        role.contains('super') ||
        role.contains('admin') ||
        role.contains('direct') ||
        role.contains('owner') ||
        role.contains('proviseur') ||
        role.contains('principal') ||
        role.contains('fondat') ||
        role.contains('promoteur') ||
        role.contains('مدير')) {
      return true;
    }

    // 2. Teachers have guaranteed access to exams, messaging, attendance, academics, and student views
    if (role == 'teacher' ||
        role == 'enseignant' ||
        role == 'professeur' ||
        role.contains('teacher') ||
        role.contains('enseign') ||
        role.contains('prof') ||
        role.contains('أستاذ') ||
        role.contains('معلم')) {
      if (permission.startsWith('messaging.') ||
          permission.startsWith('exams.') ||
          permission.startsWith('attendance.') ||
          permission.startsWith('academics.') ||
          permission.startsWith('students.')) {
        return true;
      }
    }

    // 3. Students & Parents have guaranteed access to view exams, messaging, attendance, academics
    if (role == 'student' ||
        role == 'parent' ||
        role.contains('student') ||
        role.contains('eleve') ||
        role.contains('élève') ||
        role.contains('parent') ||
        role.contains('tuteur')) {
      if (permission == AppPermissions.messagingView ||
          permission == AppPermissions.examsView ||
          permission == AppPermissions.attendanceView ||
          permission == AppPermissions.academicsView) {
        return true;
      }
    }

    // 4. Finance & Accounting staff have guaranteed access to finance operations, student lookups, and messaging
    if (role == 'accountant' ||
        role == 'comptable' ||
        role == 'finance' ||
        role == 'financier' ||
        role == 'caissier' ||
        role == 'tresorier' ||
        role == 'trésorier' ||
        role == 'daf' ||
        role.contains('account') ||
        role.contains('comptab') ||
        role.contains('financ') ||
        role.contains('caiss') ||
        role.contains('tresor') ||
        role.contains('trésor') ||
        role.contains('daf') ||
        role.contains('economat') ||
        role.contains('économe') ||
        role.contains('econome') ||
        role.contains('gestionnaire') ||
        role.contains('محاسب') ||
        role.contains('مالي') ||
        role.contains('مالية') ||
        role.contains('صندوق') ||
        role.contains('خزينة')) {
      if (permission == AppPermissions.financeView ||
          permission == AppPermissions.financeCollect ||
          permission == AppPermissions.studentsView ||
          permission == AppPermissions.messagingView) {
        return true;
      }
    }

    return profile.permissions.contains(permission);
  }

  Future<bool> hasAnyPermission(List<String> permissions) async {
    for (final p in permissions) {
      if (await hasPermission(p)) return true;
    }
    return false;
  }

  Future<bool> hasRole(String role) async {
    final profile = await getCurrentProfile();
    return profile.role == role.toLowerCase().trim();
  }

  Future<void> refresh() async {
    _cachedProfile = null;
    _cachedCacheKey = null;
    await getCurrentProfile();
  }

  Set<String> permissionsForRole(String role) => _permissionsForRole(role);

  Future<UserAccessProfile> _loadProfileFromDatabase({
    required String fallbackRole,
    required String? userId,
    required String email,
  }) async {
    final userRecord = await _fetchCurrentUserRecord(
      userId: userId,
      email: email,
    );

    if (userRecord == null) {
      return UserAccessProfile(
        role: fallbackRole,
        permissions: _permissionsForRole(fallbackRole),
      );
    }

    final isAdmin = userRecord['admin'] == true;
    final isSuperAdmin = userRecord['super_admin'] == true;
    var roleId = userRecord['role_id'];
    final roleNameStr = userRecord['roles']?['role_name']?.toString();

    final dbRole = _normalizeRoleName(
      roleNameStr,
      isAdmin: isAdmin,
      isSuperAdmin: isSuperAdmin,
      fallbackRole: fallbackRole,
    );

    if (roleId == null && roleNameStr != null && roleNameStr.isNotEmpty) {
      try {
        final roleRow = await _client
            .from('roles')
            .select('id')
            .ilike('role_name', roleNameStr)
            .maybeSingle();
        if (roleRow != null && roleRow['id'] != null) {
          roleId = roleRow['id'];
        }
      } catch (_) {}
    }

    var permissions = <String>{..._permissionsForRole(dbRole)};

    if (roleId != null) {
      final rows = await _client
          .from('role_permissions')
          .select('module_name, can_view, can_edit, can_delete, field_permissions')
          .eq('role_id', roleId);

      final rowList = List<Map<String, dynamic>>.from(rows);
      if (rowList.isNotEmpty) {
        for (final row in rowList) {
          permissions.addAll(_mapModulePermissionRow(row));
        }
      }
    }

    return UserAccessProfile(role: dbRole, permissions: permissions);
  }

  Future<Map<String, dynamic>?> _fetchCurrentUserRecord({
    required String? userId,
    required String email,
  }) async {
    final currentSupabaseUser = _client.auth.currentUser;
    final username = email.contains('@') ? email.split('@').first : email;
    const select =
        'id, utilisateur, admin, super_admin, role_id, roles(role_name)';

    if (userId != null && userId.isNotEmpty) {
      try {
        final parsedId = int.tryParse(userId);
        if (parsedId != null) {
          final byId = await _client
              .from('users')
              .select(select)
              .eq('id', parsedId)
              .maybeSingle();
          if (byId != null) {
            return byId;
          }
        }
      } catch (_) {}
    }

    if (currentSupabaseUser != null) {
      try {
        final bySupabaseId = await _client
            .from('users')
            .select(select)
            .eq('supabase_id', currentSupabaseUser.id)
            .maybeSingle();
        if (bySupabaseId != null) {
          return bySupabaseId;
        }
      } catch (_) {}
    }

    if (email.isNotEmpty) {
      try {
        final byEmail = await _client
            .from('users')
            .select(select)
            .eq('utilisateur', email)
            .maybeSingle();
        if (byEmail != null) {
          return byEmail;
        }
      } catch (_) {}
    }

    if (username.isNotEmpty) {
      try {
        return await _client
            .from('users')
            .select(select)
            .eq('utilisateur', username)
            .maybeSingle();
      } catch (_) {}
    }

    return null;
  }

  String _normalizeRoleName(
    String? roleName, {
    required bool isAdmin,
    required bool isSuperAdmin,
    required String fallbackRole,
  }) {
    final role = (roleName ?? fallbackRole).toLowerCase().trim();

    if (role.contains('super') || isSuperAdmin) return 'super_admin';
    if (role.contains('teacher') ||
        role.contains('enseignant') ||
        role.contains('professeur') ||
        role.contains('prof') ||
        role.contains('أستاذ') ||
        role.contains('معلم')) {
      return 'teacher';
    }
    if (role.contains('director') ||
        role.contains('directeur') ||
        role.contains('proviseur') ||
        role.contains('principal') ||
        role.contains('fondat') ||
        role.contains('promoteur') ||
        role.contains('dirigeant') ||
        role.contains('مدير')) {
      return 'director';
    }
    if (role.contains('censeur')) return 'censeur';
    if (role.contains('surveillant')) return 'surveillant';
    if (role.contains('comptab') ||
        role.contains('account') ||
        role.contains('caiss') ||
        role.contains('financ') ||
        role.contains('tresor') ||
        role.contains('trésor') ||
        role.contains('daf') ||
        role.contains('economat') ||
        role.contains('économe') ||
        role.contains('econome') ||
        role.contains('gestionnaire') ||
        role.contains('محاسب') ||
        role.contains('مالي') ||
        role.contains('مالية') ||
        role.contains('صندوق') ||
        role.contains('خزينة')) {
      return 'accountant';
    }
    if (role.contains('secret') ||
        role.contains('سكرتير') ||
        role.contains('أمانة')) {
      return 'secretary';
    }
    if (role.contains('personnel') || role == 'hr' || role.contains('rh')) return 'personnel';
    if (role.contains('owner') || role.contains('propriet')) return 'owner';
    if (role.contains('admin') || isAdmin) return 'admin';
    if (role.contains('parent') || role.contains('tuteur')) return 'parent';
    if (role.contains('eleve') || role.contains('élève') || role.contains('student') || role.contains('etudiant')) return 'student';

    return role.isEmpty ? fallbackRole : role;
  }

  Set<String> _mapModulePermissionRow(Map<String, dynamic> row) {
    final moduleName = (row['module_name'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final canView = row['can_view'] == true;
    final canEdit = row['can_edit'] == true;
    final canDelete = row['can_delete'] == true;

    final permissions = <String>{};

    if (_matchesModule(moduleName, const [
      'students',
      'student',
      'eleves',
      'eleve',
      'élève',
      'élèves',
      'etudiant',
      'etudiants',
      'inscription',
      'inscriptions',
      'admission',
    ])) {
      if (canView) permissions.add(AppPermissions.studentsView);
      if (canEdit) {
        permissions.addAll({
          AppPermissions.studentsCreate,
          AppPermissions.studentsEdit,
          AppPermissions.studentsPromote,
        });
      }
      if (canDelete) permissions.add(AppPermissions.studentsDelete);
    }

    if (_matchesModule(moduleName, const [
      'finance',
      'finances',
      'comptabilite',
      'comptabilité',
      'caisse',
      'paiements',
      'paiement',
      'frais',
      'scolarite',
      'scolarité',
      'recus',
      'reçus',
      'versement',
      'versements',
      'tresorerie',
      'trésorerie',
      'ecolage',
      'écolage',
      'tuition',
      'fee',
      'fees',
      'cash',
      'cashier',
      'recouvrement',
      'recouvrements',
      'dépenses',
      'depenses',
      'recettes',
      'recette',
      'budget',
      'facture',
      'factures',
      'مالية',
      'محاسبة',
      'صندوق',
      'خزينة',
      'رسوم',
      'مصاريف',
      'أقساط',
      'دفع',
      'فواتير',
      'تحصيل',
    ])) {
      if (canView) permissions.add(AppPermissions.financeView);
      if (canEdit || canDelete) permissions.add(AppPermissions.financeCollect);
    }

    if (_matchesModule(moduleName, const [
      'hr',
      'rh',
      'human resources',
      'ressources humaines',
      'personnel',
      'employes',
      'employés',
      'enseignants',
      'professeurs',
      'salaires',
    ])) {
      if (canView) permissions.add(AppPermissions.hrView);
      if (canEdit || canDelete) permissions.add(AppPermissions.hrManage);
    }

    if (_matchesModule(moduleName, const [
      'hostel',
      'internat',
      'dortoir',
      'dortoirs',
      'chambres',
      'hebergement',
      'hébergement',
      'dormitory',
    ])) {
      if (canView) permissions.add(AppPermissions.hostelView);
      if (canEdit || canDelete) permissions.add(AppPermissions.hostelManage);
    }

    if (_matchesModule(moduleName, const [
      'owner',
      'platform',
      'schools',
      'security',
      'etablissements',
      'établissements',
      'configuration',
    ])) {
      if (canView) permissions.add(AppPermissions.ownerPlatformView);
      if (canEdit || canDelete) {
        permissions.add(AppPermissions.ownerSchoolsManage);
      }
    }

    if (_matchesModule(moduleName, const [
      'exam',
      'exams',
      'examen',
      'examens',
      'evaluation',
      'evaluations',
      'évaluation',
      'évaluations',
      'resultat',
      'resultats',
      'résultat',
      'résultats',
      'bulletin',
      'bulletins',
      'composition',
      'compositions',
      'note',
      'notes',
    ])) {
      if (canView) permissions.add(AppPermissions.examsView);
      if (canEdit || canDelete) permissions.add(AppPermissions.examsManage);
    }

    if (_matchesModule(moduleName, const [
      'attendance',
      'appel',
      'presence',
      'presences',
      'présence',
      'présences',
      'assiduite',
      'assiduité',
      'absences',
      'retards',
      'pointage',
    ])) {
      if (canView) permissions.add(AppPermissions.attendanceView);
      if (canEdit || canDelete) {
        permissions.add(AppPermissions.attendanceManage);
      }
    }

    if (_matchesModule(moduleName, const [
      'academics',
      'academic',
      'pedagogie',
      'pédagogie',
      'cours',
      'classes',
      'matieres',
      'matières',
      'notes',
      'devoirs',
      'homework',
      'cahier_textes',
      'planification',
    ])) {
      if (canView) permissions.add(AppPermissions.academicsView);
      if (canEdit || canDelete) permissions.add(AppPermissions.academicsManage);

      // Parse sub-permissions / field_permissions JSON column
      final rawFieldPerms = row['field_permissions'];
      Map<String, dynamic>? fieldPerms;
      if (rawFieldPerms != null) {
        try {
          fieldPerms = rawFieldPerms is String
              ? jsonDecode(rawFieldPerms) as Map<String, dynamic>
              : Map<String, dynamic>.from(rawFieldPerms as Map);
        } catch (_) {}
      }

      final snConfig = fieldPerms?['saisieNotes'];
      final snView = (snConfig?['view'] as bool?) ?? canView;
      final snEdit = (snConfig?['edit'] as bool?) ?? canEdit;

      if (snView) permissions.add(AppPermissions.saisieNotesView);
      if (snEdit) permissions.add(AppPermissions.saisieNotesEdit);

      final gdConfig = fieldPerms?['gestionDevoirs'];
      final gdView = (gdConfig?['view'] as bool?) ?? canView;
      final gdEdit = (gdConfig?['edit'] as bool?) ?? canEdit;

      if (gdView) permissions.add(AppPermissions.gestionDevoirsView);
      if (gdEdit) permissions.add(AppPermissions.gestionDevoirsEdit);
    }

    if (_matchesModule(moduleName, const [
      'messaging',
      'messages',
      'message',
      'messagerie',
      'notification',
      'notifications',
      'communication',
      'communications',
      'chat',
      'sms',
      'discussion',
      'discussions',
      'mail',
      'email',
    ])) {
      if (canView) permissions.add(AppPermissions.messagingView);
      if (canEdit || canDelete) permissions.add(AppPermissions.messagingManage);
    }

    return permissions;
  }

  bool _matchesModule(String moduleName, List<String> aliases) {
    for (final alias in aliases) {
      if (moduleName == alias || moduleName.contains(alias)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _permissionsForRole(String rawRole) {
    final role = rawRole.toLowerCase().trim();

    if (role == 'super_admin' || role == 'owner') {
      return {
        AppPermissions.ownerPlatformView,
        AppPermissions.ownerSchoolsManage,
        AppPermissions.studentsView,
        AppPermissions.studentsCreate,
        AppPermissions.studentsEdit,
        AppPermissions.studentsDelete,
        AppPermissions.studentsPromote,
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.hrView,
        AppPermissions.hrManage,
        AppPermissions.hostelView,
        AppPermissions.hostelManage,
        AppPermissions.examsView,
        AppPermissions.examsManage,
        AppPermissions.attendanceView,
        AppPermissions.attendanceManage,
        AppPermissions.academicsView,
        AppPermissions.academicsManage,
        AppPermissions.saisieNotesView,
        AppPermissions.saisieNotesEdit,
        AppPermissions.gestionDevoirsView,
        AppPermissions.gestionDevoirsEdit,
        AppPermissions.messagingView,
        AppPermissions.messagingManage,
      };
    }

    if (role == 'admin' || role == 'director') {
      return {
        AppPermissions.studentsView,
        AppPermissions.studentsCreate,
        AppPermissions.studentsEdit,
        AppPermissions.studentsDelete,
        AppPermissions.studentsPromote,
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.hrView,
        AppPermissions.hrManage,
        AppPermissions.hostelView,
        AppPermissions.hostelManage,
        AppPermissions.examsView,
        AppPermissions.examsManage,
        AppPermissions.attendanceView,
        AppPermissions.attendanceManage,
        AppPermissions.academicsView,
        AppPermissions.academicsManage,
        AppPermissions.saisieNotesView,
        AppPermissions.saisieNotesEdit,
        AppPermissions.gestionDevoirsView,
        AppPermissions.gestionDevoirsEdit,
        AppPermissions.messagingView,
        AppPermissions.messagingManage,
      };
    }

    if (role == 'accountant' ||
        role == 'comptable' ||
        role == 'finance' ||
        role == 'financier' ||
        role == 'caissier' ||
        role == 'tresorier' ||
        role == 'trésorier' ||
        role == 'daf' ||
        role.contains('account') ||
        role.contains('comptab') ||
        role.contains('financ') ||
        role.contains('caiss') ||
        role.contains('tresor') ||
        role.contains('trésor') ||
        role.contains('daf') ||
        role.contains('economat') ||
        role.contains('économe') ||
        role.contains('econome') ||
        role.contains('gestionnaire') ||
        role.contains('محاسب') ||
        role.contains('مالي') ||
        role.contains('مالية') ||
        role.contains('صندوق') ||
        role.contains('خزينة')) {
      return {
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.studentsView,
        AppPermissions.messagingView,
      };
    }

    if (role == 'hr' || role == 'personnel') {
      return {AppPermissions.hrView, AppPermissions.hrManage};
    }

    if (role == 'teacher' || role == 'enseignant' || role == 'professeur') {
      return {
        AppPermissions.studentsView,
        AppPermissions.examsView,
        AppPermissions.examsManage,
        AppPermissions.attendanceView,
        AppPermissions.attendanceManage,
        AppPermissions.academicsView,
        AppPermissions.saisieNotesView,
        AppPermissions.saisieNotesEdit,
        AppPermissions.gestionDevoirsView,
        AppPermissions.gestionDevoirsEdit,
        AppPermissions.messagingView,
        AppPermissions.messagingManage,
      };
    }

    if (role == 'secretary' ||
        role == 'secretaire' ||
        role == 'secrétaire' ||
        role.contains('secret') ||
        role.contains('سكرتير') ||
        role.contains('أمانة')) {
      return {
        AppPermissions.studentsView,
        AppPermissions.studentsCreate,
        AppPermissions.studentsEdit,
        AppPermissions.financeView,
        AppPermissions.financeCollect,
        AppPermissions.examsView,
        AppPermissions.attendanceView,
        AppPermissions.messagingView,
        AppPermissions.messagingManage,
      };
    }

    if (role == 'student' || role == 'parent') {
      return {
        AppPermissions.attendanceView,
        AppPermissions.academicsView,
        AppPermissions.examsView,
        AppPermissions.messagingView,
      };
    }

    return <String>{};
  }
}
