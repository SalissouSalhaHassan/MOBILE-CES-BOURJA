import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/type_converters.dart';

class HrRepository {
  final SupabaseClient _client;
  final MobileApiClient _apiClient;

  HrRepository({SupabaseClient? client, MobileApiClient? apiClient})
      : _client = client ?? SupabaseClientManager().client,
        _apiClient = apiClient ?? locator<MobileApiClient>();

  Future<int?> _schoolId() async {
    return int.tryParse(await locator<SessionManager>().getSchoolId() ?? '');
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/hr?action=employees');
      if (res['data'] is List) {
        return List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (e) {
      debugPrint('API getEmployees error: $e. Falling back to Supabase...');
    }

    try {
      final schoolId = await _schoolId();
      final query = _client.from('employees').select(
            'id, school_id, emp_id, nom, poste, departement, mobile, email, '
            'date_embauche, salaire_base, sexe, date_naissance, cnic, adresse, '
            'banque_nom, banque_compte, statut, photo_path, educational_level, created_at',
          );
      final rows = schoolId == null
          ? await query.order('created_at', ascending: false)
          : await query.eq('school_id', schoolId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching employees from Supabase: $e');
      return [];
    }
  }

  /// Checks whether an academic session is closed, archived, or locked
  bool isSessionFrozen({int? sessionId, String? sessionName, int? schoolId}) {
    try {
      final cacheManager = locator<OfflineStoreManager>();
      List<Map<String, dynamic>> sessionList = [];

      if (schoolId != null && schoolId > 0) {
        sessionList = cacheManager.getDataList(
          boxName: OfflineStoreManager.boxSchoolSessions,
          key: "finance_sessions_$schoolId",
        );
        if (sessionList.isEmpty) {
          sessionList = cacheManager.getDataList(
            boxName: OfflineStoreManager.boxSchoolSessions,
            key: "sessions_$schoolId",
          );
        }
      }

      if (sessionList.isEmpty && Hive.isBoxOpen(OfflineStoreManager.boxSchoolSessions)) {
        final box = Hive.box(OfflineStoreManager.boxSchoolSessions);
        for (final k in box.keys) {
          final data = box.get(k);
          if (data is List && data.isNotEmpty) {
            sessionList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            break;
          }
        }
      }

      if (sessionId == null && (sessionName == null || sessionName.isEmpty)) {
        if (sessionList.isNotEmpty) {
          final active = sessionList.firstWhere(
            (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
            orElse: () => sessionList.first,
          );
          return _checkSessionFrozenMap(active);
        }
      }

      for (final s in sessionList) {
        final sId = TypeConverters.safeInt(s['id']);
        final sName = s['session_name']?.toString() ?? s['name']?.toString() ?? '';
        final matchesId = sessionId != null && sessionId > 0 && sId == sessionId;
        final matchesName = sessionName != null && sessionName.trim().isNotEmpty &&
            sName.trim().toLowerCase() == sessionName.trim().toLowerCase();

        if (matchesId || matchesName) {
          return _checkSessionFrozenMap(s);
        }
      }
    } catch (e) {
      debugPrint("Error checking isSessionFrozen in HrRepository: $e");
    }
    return false;
  }

  bool _checkSessionFrozenMap(Map<String, dynamic> s) {
    final status = s['status']?.toString().toLowerCase().trim() ?? '';
    final isActive = s['is_active'] == true;
    return !isActive ||
        status == 'clôturé' ||
        status == 'cloture' ||
        status == 'verrouillé' ||
        status == 'verrouille' ||
        status == 'archivé' ||
        status == 'archive';
  }

  Future<Map<String, dynamic>> saveEmployee({
    int? employeeId,
    required Map<String, dynamic> payload,
  }) async {
    if (isSessionFrozen()) {
      return {
        'success': false,
        'error': "L'année scolaire est clôturée ou verrouillée. Les modifications RH sont gelées.",
      };
    }
    try {
      final res = await _apiClient.postJson('/api/mobile/hr', {
        'action': 'save_employee',
        if (employeeId != null) 'employeeId': employeeId,
        'payload': payload,
      });
      return {'success': true, 'data': res['data']};
    } catch (e) {
      debugPrint('API saveEmployee error: $e. Falling back to Supabase...');
      try {
        final schoolId = await _schoolId();
        final data = Map<String, dynamic>.from(payload);
        if (schoolId != null) {
          data['school_id'] = schoolId;
        }

        if (employeeId == null) {
          await _client.from('employees').insert(data);
        } else {
          await _client.from('employees').update(data).eq('id', employeeId);
        }

        return {'success': true};
      } catch (err) {
        debugPrint('Error saving employee via Supabase: $err');
        return {'success': false, 'error': '$err'};
      }
    }
  }

  Future<Map<String, dynamic>> deleteEmployee(int employeeId) async {
    if (isSessionFrozen()) {
      return {
        'success': false,
        'error': "L'année scolaire est clôturée ou verrouillée. La suppression d'employés est gelée.",
      };
    }
    try {
      await _apiClient.postJson('/api/mobile/hr', {
        'action': 'delete_employee',
        'employeeId': employeeId,
      });
      return {'success': true};
    } catch (e) {
      debugPrint('API deleteEmployee error: $e. Falling back to Supabase...');
      try {
        await _client.from('employees').update({'statut': 'Inactif'}).eq('id', employeeId);
        return {'success': true};
      } catch (err) {
        debugPrint('Error deleting employee: $err');
        return {'success': false, 'error': '$err'};
      }
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeeAttendance(String dateStr) async {
    try {
      final res = await _apiClient.getJson('/api/mobile/hr?action=attendance&date=$dateStr');
      if (res['data'] is List) {
        return List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (e) {
      debugPrint('API getEmployeeAttendance error: $e. Falling back to Supabase...');
    }

    try {
      final schoolId = await _schoolId();
      final rows = await _client
          .from('employee_attendance')
          .select(
            'id, school_id, employee_id, date, period_number, status, '
            'heure_entree, heure_sortie, remarques',
          )
          .eq('school_id', schoolId ?? -1)
          .gte('date', '${dateStr}T00:00:00')
          .lt('date', '${dateStr}T23:59:59');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching employee attendance: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveEmployeeAttendance({
    required String dateStr,
    required List<Map<String, dynamic>> records,
  }) async {
    if (isSessionFrozen()) {
      return {
        'success': false,
        'error': "L'année scolaire est clôturée ou verrouillée. L'enregistrement des présences est gelé.",
      };
    }
    try {
      await _apiClient.postJson('/api/mobile/hr', {
        'action': 'save_attendance',
        'dateStr': dateStr,
        'records': records,
      });
      return {'success': true};
    } catch (e) {
      debugPrint('API saveEmployeeAttendance error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> getPayrollRules() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/hr?action=payroll_rules');
      if (res['data'] is Map) {
        return Map<String, dynamic>.from(res['data']);
      }
    } catch (e) {
      debugPrint('API getPayrollRules error: $e. Falling back to Supabase...');
    }

    try {
      final row = await _client
          .from('payroll_rules')
          .select('id, leave_allow_per_month, late_penalty, half_day_penalty')
          .limit(1)
          .maybeSingle();
      if (row != null) {
        return row;
      }
      return {
        'leave_allow_per_month': 1,
        'late_penalty': 0.5,
        'half_day_penalty': 0.5,
      };
    } catch (e) {
      debugPrint('Error fetching payroll rules: $e');
      return {
        'leave_allow_per_month': 1,
        'late_penalty': 0.5,
        'half_day_penalty': 0.5,
      };
    }
  }

  Future<Map<String, dynamic>> savePayrollRules(Map<String, dynamic> payload) async {
    if (isSessionFrozen()) {
      return {
        'success': false,
        'error': "L'année scolaire est clôturée ou verrouillée. La modification des règles est gelée.",
      };
    }
    try {
      await _apiClient.postJson('/api/mobile/hr', {
        'action': 'save_payroll_rules',
        ...payload,
      });
      return {'success': true};
    } catch (e) {
      debugPrint('API savePayrollRules error: $e. Falling back to Supabase...');
      try {
        final existing = await _client
            .from('payroll_rules')
            .select('id')
            .limit(1)
            .maybeSingle();
        if (existing == null) {
          await _client.from('payroll_rules').insert(payload);
        } else {
          await _client.from('payroll_rules').update(payload).eq('id', existing['id']);
        }
        return {'success': true};
      } catch (err) {
        debugPrint('Error saving payroll rules: $err');
        return {'success': false, 'error': '$err'};
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSalaryRecords({
    int? employeeId,
    String? monthYear,
  }) async {
    try {
      final queryParams = <String, String>{'action': 'salary_records'};
      if (employeeId != null) queryParams['employeeId'] = employeeId.toString();
      if (monthYear != null && monthYear.isNotEmpty) queryParams['monthYear'] = monthYear;

      final queryString = Uri(queryParameters: queryParams).query;
      final res = await _apiClient.getJson('/api/mobile/hr?$queryString');
      if (res['data'] is List) {
        return List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (e) {
      debugPrint('API getSalaryRecords error: $e. Falling back to Supabase...');
    }

    try {
      dynamic query = _client.from('salary_records').select(
            'id, employee_id, month_year, absent_days, leave_taken, late_days, '
            'half_days, basic_salary, calculated_basic, total_allowance, '
            'total_deduction, net_salary, status, payment_date, payment_mode, remark, created_at, '
            'employees(id, nom, poste, emp_id)',
          );
      if (employeeId != null) {
        query = query.eq('employee_id', employeeId);
      }
      if (monthYear != null && monthYear.isNotEmpty) {
        query = query.eq('month_year', monthYear);
      }
      final rows = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching salary records: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveSalaryRecord({
    int? recordId,
    required Map<String, dynamic> payload,
  }) async {
    if (isSessionFrozen()) {
      return {
        'success': false,
        'error': "L'année scolaire est clôturée ou verrouillée. La gestion des salaires est gelée.",
      };
    }
    try {
      final res = await _apiClient.postJson('/api/mobile/hr', {
        'action': 'save_salary_record',
        if (recordId != null) 'recordId': recordId,
        ...payload,
      });
      return {'success': true, 'data': res['data']};
    } catch (e) {
      debugPrint('API saveSalaryRecord error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> markSalaryAsPaid(int recordId) async {
    if (isSessionFrozen()) {
      return {
        'success': false,
        'error': "L'année scolaire est clôturée ou verrouillée. Le paiement de salaire est gelé.",
      };
    }
    try {
      await _apiClient.postJson('/api/mobile/hr', {
        'action': 'mark_paid',
        'recordId': recordId,
      });
      return {'success': true};
    } catch (e) {
      debugPrint('API markSalaryAsPaid error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, int>> getEmployeeAttendanceSummary({
    required int employeeId,
    required String monthYear,
  }) async {
    try {
      final range = _monthRange(monthYear);
      final rows = await _client
          .from('employee_attendance')
          .select('status')
          .eq('employee_id', employeeId)
          .gte('date', range['start']!)
          .lt('date', range['end']!);

      var presents = 0;
      var absents = 0;
      var conges = 0;
      var retards = 0;

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final status = _normalizeAttendanceStatus(
          (row['status'] ?? '').toString(),
        );
        if (status == 'Present') {
          presents++;
        } else if (status == 'Absent') {
          absents++;
        } else if (status == 'Conge') {
          conges++;
        } else if (status == 'En Retard') {
          retards++;
        }
      }

      return {
        'presents': presents,
        'absents': absents,
        'conges': conges,
        'retards': retards,
      };
    } catch (e) {
      debugPrint('Error fetching employee attendance summary: $e');
      return {
        'presents': 0,
        'absents': 0,
        'conges': 0,
        'retards': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getHrDashboardData() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/hr?action=dashboard');
      if (res['data'] is Map) {
        return Map<String, dynamic>.from(res['data']);
      }
    } catch (e) {
      debugPrint('API getHrDashboardData error: $e. Falling back to local composition...');
    }

    try {
      final employees = await getEmployees();
      final salaryRecords = await getSalaryRecords();
      final today = DateTime.now().toIso8601String().split('T').first;
      final attendance = await getEmployeeAttendance(today);

      final activeEmployees = employees
          .where((e) => (e['statut'] ?? '').toString().toLowerCase().contains('actif'))
          .length;
      final presentToday = attendance
          .where(
            (e) => _normalizeAttendanceStatus(
              (e['status'] ?? '').toString(),
            ) ==
            'Present',
          )
          .length;
      final paid = salaryRecords
          .where(
            (e) => _normalizeSalaryStatus((e['status'] ?? '').toString()) ==
                'Paid',
          )
          .fold<double>(0, (sum, row) => sum + ((row['net_salary'] as num?)?.toDouble() ?? 0));
      final unpaid = salaryRecords
          .where(
            (e) => _normalizeSalaryStatus((e['status'] ?? '').toString()) !=
                'Paid',
          )
          .fold<double>(0, (sum, row) => sum + ((row['net_salary'] as num?)?.toDouble() ?? 0));

      return {
        'employees': employees,
        'salaryRecords': salaryRecords,
        'attendance': attendance,
        'stats': {
          'activeEmployees': activeEmployees,
          'presentToday': presentToday,
          'paidAmount': paid,
          'unpaidAmount': unpaid,
        },
      };
    } catch (e) {
      debugPrint('Error fetching HR dashboard data: $e');
      return {
        'employees': <Map<String, dynamic>>[],
        'salaryRecords': <Map<String, dynamic>>[],
        'attendance': <Map<String, dynamic>>[],
        'stats': {
          'activeEmployees': 0,
          'presentToday': 0,
          'paidAmount': 0.0,
          'unpaidAmount': 0.0,
        },
      };
    }
  }

  Map<String, String> _monthRange(String monthYear) {
    const months = {
      'janvier': 1,
      'fevrier': 2,
      'février': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'aout': 8,
      'août': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'decembre': 12,
      'décembre': 12,
    };

    final parts = monthYear.trim().split(RegExp(r'\s+'));
    final monthName = parts.isNotEmpty ? parts.first.toLowerCase() : '';
    final year = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final month = months[monthName] ?? DateTime.now().month;
    final safeYear = year ?? DateTime.now().year;
    final start = DateTime(safeYear, month, 1);
    final end = DateTime(safeYear, month + 1, 1);
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }

  String _normalizeAttendanceStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('present') || normalized.contains('présent')) {
      return 'Present';
    }
    if (normalized.contains('absent')) {
      return 'Absent';
    }
    if (normalized.contains('retard') || normalized.contains('late')) {
      return 'En Retard';
    }
    if (normalized.contains('conge') || normalized.contains('congé')) {
      return 'Conge';
    }
    return value.trim().isEmpty ? 'Absent' : value.trim();
  }

  String _normalizeSalaryStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'paid' || normalized == 'paye' || normalized == 'payé') {
      return 'Paid';
    }
    return 'Unpaid';
  }
}
