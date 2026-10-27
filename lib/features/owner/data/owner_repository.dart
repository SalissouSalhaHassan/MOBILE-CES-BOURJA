import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/supabase_client.dart';

class OwnerRepository {
  final SupabaseClient _client;

  OwnerRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      final schoolsRows = await _client
          .from('schools')
          .select('id, plan, status');
      final studentsRows = await _client.from('students').select('id');
      final usersRows = await _client.from('users').select('id');

      final schools = List<Map<String, dynamic>>.from(schoolsRows);
      final students = List<Map<String, dynamic>>.from(studentsRows);
      final users = List<Map<String, dynamic>>.from(usersRows);

      final activeSchools = schools
          .where(
            (row) => (row['status'] ?? 'active')
                .toString()
                .toLowerCase()
                .contains('active'),
          )
          .length;

      double revenue = 0;
      for (final school in schools) {
        final status = (school['status'] ?? '').toString().toLowerCase();
        if (!status.contains('active')) continue;
        final plan = (school['plan'] ?? 'basic').toString().toLowerCase();
        if (plan == 'enterprise' || plan == 'premium') {
          revenue += 150000;
        } else if (plan == 'pro') {
          revenue += 49000;
        } else {
          revenue += 19000;
        }
      }

      return {
        'totalSchools': schools.length,
        'totalStudents': students.length,
        'totalUsers': users.length,
        'activeSchools': activeSchools,
        'revenue': revenue,
      };
    } catch (e) {
      debugPrint('Error fetching platform stats: $e');
      return {
        'totalSchools': 0,
        'totalStudents': 0,
        'totalUsers': 0,
        'activeSchools': 0,
        'revenue': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getSchools() async {
    try {
      final rows = await _client
          .from('schools')
          .select(
            'id, name, slug, custom_domain, plan, status, subscription_expiry, created_at',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching schools: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createSchool({
    required String name,
    required String slug,
    required String plan,
    required String status,
  }) async {
    try {
      final cleanName = name.trim();
      final cleanSlug = slug.trim().toLowerCase();

      if (cleanName.isEmpty) {
        return {'success': false, 'error': 'Le nom de l ecole est requis.'};
      }
      if (cleanSlug.isEmpty) {
        return {'success': false, 'error': 'Le slug est requis.'};
      }

      final existing = await _client
          .from('schools')
          .select('id')
          .eq('slug', cleanSlug)
          .maybeSingle();
      if (existing != null) {
        return {
          'success': false,
          'error': 'Ce sous-domaine est deja utilise.',
        };
      }

      final expiry = DateTime(
        DateTime.now().year + 1,
        DateTime.now().month,
        DateTime.now().day,
      );

      await _client.from('schools').insert({
        'name': cleanName,
        'slug': cleanSlug,
        'plan': plan.trim().isEmpty ? 'basic' : plan.trim(),
        'status': status.trim().isEmpty ? 'active' : status.trim(),
        'subscription_expiry': expiry.toIso8601String(),
      });

      return {'success': true};
    } catch (e) {
      debugPrint('Error creating school: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> updateSchool({
    required int schoolId,
    String? plan,
    String? status,
    String? subscriptionExpiry,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (plan != null && plan.trim().isNotEmpty) {
        payload['plan'] = plan.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        payload['status'] = status.trim();
      }
      if (subscriptionExpiry != null && subscriptionExpiry.trim().isNotEmpty) {
        payload['subscription_expiry'] = subscriptionExpiry.trim();
      }
      if (payload.isEmpty) {
        return {'success': false, 'error': 'Aucune modification.'};
      }

      await _client.from('schools').update(payload).eq('id', schoolId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating school: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> deleteSchool(int schoolId) async {
    try {
      await _client.from('schools').delete().eq('id', schoolId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting school: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select(
            'id, school_id, user_id, action, table_name, record_id, timestamp',
          )
          .order('timestamp', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSubscriptionSummary() async {
    try {
      final schools = await getSchools();
      int basic = 0;
      int pro = 0;
      int premium = 0;
      int enterprise = 0;
      int active = 0;
      int suspended = 0;
      int expired = 0;

      final now = DateTime.now();
      for (final school in schools) {
        final plan = (school['plan'] ?? 'basic').toString().toLowerCase();
        final status = (school['status'] ?? 'active').toString().toLowerCase();
        final expiry = DateTime.tryParse(
          school['subscription_expiry']?.toString() ?? '',
        );

        if (plan == 'enterprise') {
          enterprise++;
        } else if (plan == 'premium') {
          premium++;
        } else if (plan == 'pro') {
          pro++;
        } else {
          basic++;
        }

        if (status.contains('suspend')) {
          suspended++;
        } else {
          active++;
        }

        if (expiry != null && expiry.isBefore(now)) {
          expired++;
        }
      }

      return {
        'basic': basic,
        'pro': pro,
        'premium': premium,
        'enterprise': enterprise,
        'active': active,
        'suspended': suspended,
        'expired': expired,
        'total': schools.length,
      };
    } catch (e) {
      debugPrint('Error fetching subscription summary: $e');
      return {
        'basic': 0,
        'pro': 0,
        'premium': 0,
        'enterprise': 0,
        'active': 0,
        'suspended': 0,
        'expired': 0,
        'total': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getRolesWithPermissions() async {
    try {
      final rows = await _client
          .from('roles')
          .select(
            'id, role_name, role_permissions(module_name, can_view, can_edit, can_delete), users(id)',
          )
          .order('role_name');

      return List<Map<String, dynamic>>.from(rows).map((row) {
        final permissions = List<Map<String, dynamic>>.from(
          row['role_permissions'] as List? ?? const [],
        );
        final users = List<Map<String, dynamic>>.from(
          row['users'] as List? ?? const [],
        );

        return {
          'id': row['id'],
          'role_name': row['role_name'],
          'permissions': permissions,
          'users_count': users.length,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching roles with permissions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createRole(String roleName) async {
    try {
      final cleanName = roleName.trim();
      if (cleanName.isEmpty) {
        return {'success': false, 'error': 'Le nom du role est requis.'};
      }

      final exists = await _client
          .from('roles')
          .select('id')
          .eq('role_name', cleanName)
          .maybeSingle();
      if (exists != null) {
        return {'success': false, 'error': 'Ce role existe deja.'};
      }

      await _client.from('roles').insert({'role_name': cleanName});
      return {'success': true};
    } catch (e) {
      debugPrint('Error creating role: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> deleteRole(int roleId) async {
    try {
      await _client.from('role_permissions').delete().eq('role_id', roleId);
      await _client.from('roles').delete().eq('id', roleId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting role: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> updateRolePermissions({
    required int roleId,
    required List<Map<String, dynamic>> permissions,
  }) async {
    try {
      await _client.from('role_permissions').delete().eq('role_id', roleId);

      final validPermissions = permissions
          .where(
            (row) =>
                row['can_view'] == true ||
                row['can_edit'] == true ||
                row['can_delete'] == true,
          )
          .map((row) => {
                'role_id': roleId,
                'module_name': row['module_name'],
                'can_view': row['can_view'] == true,
                'can_edit': row['can_edit'] == true,
                'can_delete': row['can_delete'] == true,
              })
          .toList();

      if (validPermissions.isNotEmpty) {
        await _client.from('role_permissions').insert(validPermissions);
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error updating role permissions: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
