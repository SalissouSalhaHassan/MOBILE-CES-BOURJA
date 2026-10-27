import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';

class HostelRepository {
  final SupabaseClient _client;
  final MobileApiClient _apiClient;

  HostelRepository({SupabaseClient? client, MobileApiClient? apiClient})
      : _client = client ?? SupabaseClientManager().client,
        _apiClient = apiClient ?? MobileApiClient();

  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      final rows = await _client
          .from('hostel_rooms')
          .select(
            'id, room_number, building_name, room_type, capacity, occupied_beds, created_at',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching hostel rooms: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllocations() async {
    try {
      final rows = await _client
          .from('hostel_allocations')
          .select(
            'id, student_id, room_id, join_date, leave_date, status, '
            'students(id, nom_etudiant, num_admission, classe), '
            'hostel_rooms(id, room_number, building_name, room_type)',
          )
          .order('join_date', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching hostel allocations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableStudents() async {
    try {
      final allocated = await _client
          .from('hostel_allocations')
          .select('student_id, status');

      final occupiedIds = List<Map<String, dynamic>>.from(allocated)
          .where(
            (row) => (row['status'] ?? '').toString().toLowerCase().contains('occup'),
          )
          .map((row) => row['student_id'] as int?)
          .whereType<int>()
          .toSet();

      final students = await _client
          .from('students')
          .select('id, nom_etudiant, num_admission, classe, section, statut')
          .order('nom_etudiant');

      return List<Map<String, dynamic>>.from(students)
          .where(
            (student) =>
                !occupiedIds.contains(student['id']) &&
                (student['statut'] ?? 'Actif')
                    .toString()
                    .toLowerCase()
                    .contains('actif'),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching available students: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveRoom({
    int? roomId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final data = Map<String, dynamic>.from(payload);
      data.remove('cost');
      if (roomId == null) {
        await _client.from('hostel_rooms').insert(data);
      } else {
        await _client.from('hostel_rooms').update(data).eq('id', roomId);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error saving hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> allocateStudent({
    required int studentId,
    required int roomId,
    String? remarks,
  }) async {
    try {
      final existing = await _client
          .from('hostel_allocations')
          .select('id')
          .eq('student_id', studentId)
          .eq('status', 'Occupé')
          .maybeSingle();

      if (existing != null) {
        return {
          'success': false,
          'error': 'Cet élève est déjà affecté à une chambre.',
        };
      }

      final room = await _client
          .from('hostel_rooms')
          .select('capacity, occupied_beds')
          .eq('id', roomId)
          .maybeSingle();

      final capacity = (room?['capacity'] as num?)?.toInt() ?? 1;
      final occupied = (room?['occupied_beds'] as num?)?.toInt() ?? 0;

      if (occupied >= capacity) {
        return {'success': false, 'error': 'Cette chambre est déjà complète.'};
      }

      await _client.from('hostel_allocations').insert({
        'student_id': studentId,
        'room_id': roomId,
        'status': 'Occupé',
        'join_date': DateTime.now().toIso8601String(),
        'remarks': remarks,
      });

      await _client.from('hostel_rooms').update({
        'occupied_beds': occupied + 1,
      }).eq('id', roomId);

      return {'success': true};
    } catch (e) {
      debugPrint('Error allocating student to hostel: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> vacateStudent({
    required int allocationId,
    required int roomId,
  }) async {
    try {
      await _client.from('hostel_allocations').update({
        'status': 'Libéré',
        'leave_date': DateTime.now().toIso8601String(),
      }).eq('id', allocationId);

      final room = await _client
          .from('hostel_rooms')
          .select('occupied_beds')
          .eq('id', roomId)
          .maybeSingle();
      final occupied = (room?['occupied_beds'] as num?)?.toInt() ?? 0;

      await _client.from('hostel_rooms').update({
        'occupied_beds': occupied > 0 ? occupied - 1 : 0,
      }).eq('id', roomId);

      return {'success': true};
    } catch (e) {
      debugPrint('Error vacating hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> vacateAllocation(int allocationId) async {
    try {
      final allocation = await _client
          .from('hostel_allocations')
          .select('room_id')
          .eq('id', allocationId)
          .maybeSingle();
      final roomId = (allocation?['room_id'] as num?)?.toInt() ?? 0;
      return await vacateStudent(allocationId: allocationId, roomId: roomId);
    } catch (e) {
      debugPrint('Error vacating allocation: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> deleteRoom(int roomId) async {
    try {
      final allocations = await _client
          .from('hostel_allocations')
          .select('id')
          .eq('room_id', roomId)
          .limit(1);

      if (List<Map<String, dynamic>>.from(allocations).isNotEmpty) {
        return {
          'success': false,
          'error': 'Impossible de supprimer une chambre avec des affectations.',
        };
      }

      await _client.from('hostel_rooms').delete().eq('id', roomId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting hostel room: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  // ─── Mobile Family & Boarder Methods ────────────────────────────────────────

  /// Fetch full student boarding profile, roommates, night attendance, and exit permits
  Future<Map<String, dynamic>> getStudentHostelDetails(int studentId) async {
    try {
      final res = await _apiClient.getJson('/api/mobile/hostel/student?studentId=$studentId');
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      return {'isBoarder': false};
    } catch (e) {
      debugPrint('Error getStudentHostelDetails: $e');
      return {'isBoarder': false, 'error': e.toString()};
    }
  }

  /// Request a weekend exit pass from mobile
  Future<Map<String, dynamic>> applyExitPermission({
    required int studentId,
    required String permissionType,
    required String departureDate,
    required String returnDateExpected,
    String? guardianName,
    String? guardianPhone,
    required String reason,
  }) async {
    try {
      final res = await _apiClient.postJson(
        '/api/mobile/hostel/exit-permissions/apply',
        {
          'studentId': studentId,
          'permissionType': permissionType,
          'departureDate': departureDate,
          'returnDateExpected': returnDateExpected,
          'guardianName': guardianName,
          'guardianPhone': guardianPhone,
          'reason': reason,
        },
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('Error applyExitPermission: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
