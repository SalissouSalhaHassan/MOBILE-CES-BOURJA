import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';

class TransportRepository {
  final SupabaseClient _client;
  final MobileApiClient _apiClient;

  TransportRepository({SupabaseClient? client, MobileApiClient? apiClient})
      : _client = client ?? SupabaseClientManager().client,
        _apiClient = apiClient ?? MobileApiClient();

  /// Fetches student's transport subscription, active circuit status, and recent boarding events
  Future<Map<String, dynamic>> getStudentTransportDetails(int studentId) async {
    try {
      final res = await _apiClient.get('/api/mobile/transport/student?studentId=$studentId');
      if (res['success'] == true) {
        return res;
      }
    } catch (e) {
      debugPrint('Mobile API getStudentTransportDetails error: $e');
    }

    // Fallback direct Supabase lookup
    try {
      final subRows = await _client
          .from('transport_subscriptions')
          .select('id, route_id, pickup_point, pickup_stop, dropoff_stop, trip_type, status, transport_routes(id, route_name, vehicle_number, driver_name, driver_phone, stops)')
          .eq('student_id', studentId)
          .eq('status', 'Actif')
          .maybeSingle();

      if (subRows == null) {
        return {'success': true, 'isSubscribed': false, 'subscription': null};
      }

      final route = subRows['transport_routes'] as Map<String, dynamic>?;

      return {
        'success': true,
        'isSubscribed': true,
        'subscription': {
          'id': subRows['id'],
          'routeName': route?['route_name'] ?? 'Ligne Scolaire',
          'vehicleNumber': route?['vehicle_number'] ?? 'Bus',
          'driverName': route?['driver_name'] ?? 'Chauffeur',
          'driverPhone': route?['driver_phone'],
          'pickupStop': subRows['pickup_stop'] ?? subRows['pickup_point'] ?? 'Arrêt Principal',
          'dropoffStop': subRows['dropoff_stop'] ?? 'École',
          'tripType': subRows['trip_type'] ?? 'Aller-Retour',
          'stops': route?['stops'] ?? [],
        },
        'activeTrip': null,
        'recentLogs': [],
      };
    } catch (e) {
      debugPrint('Supabase fallback error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Records boarding/descent check-in
  Future<Map<String, dynamic>> recordBoarding({
    required int studentId,
    int? tripId,
    int? subscriptionId,
    required String eventType,
    required String stopName,
  }) async {
    try {
      return await _apiClient.post(
        '/api/mobile/transport/board',
        body: {
          'studentId': studentId,
          if (tripId != null) 'tripId': tripId,
          if (subscriptionId != null) 'subscriptionId': subscriptionId,
          'eventType': eventType,
          'stopName': stopName,
        },
      );
    } catch (e) {
      debugPrint('Error recording transport boarding: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Driver broadcasts live GPS beacon ping
  Future<bool> sendGpsPing({
    required int tripId,
    required double latitude,
    required double longitude,
    double speedKmh = 0.0,
    double heading = 0.0,
    String? currentStop,
    int? estimatedArrivalMinutes,
  }) async {
    try {
      final res = await _apiClient.postJson(
        '/api/transport/gps/ping',
        {
          'tripId': tripId,
          'latitude': latitude,
          'longitude': longitude,
          'speedKmh': speedKmh,
          'heading': heading,
          if (currentStop != null) 'currentStop': currentStop,
          if (estimatedArrivalMinutes != null)
            'estimatedArrivalMinutes': estimatedArrivalMinutes,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error broadcasting GPS ping: $e');
      return false;
    }
  }

  /// Queries live GPS position for a student's active circuit
  Future<Map<String, dynamic>?> getLiveTripStatus(int tripId) async {
    try {
      final res = await _apiClient.getJson('/api/transport/gps/live?tripId=$tripId');
      if (res['success'] == true && res['trip'] != null) {
        return Map<String, dynamic>.from(res['trip']);
      }
      return null;
    } catch (e) {
      debugPrint('Error querying live trip status: $e');
      return null;
    }
  }

  /// Fetches assigned routes for driver
  Future<List<Map<String, dynamic>>> getDriverRoutes() async {
    try {
      final res = await _client.from('transport_routes').select('*');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching driver routes: $e');
      return [];
    }
  }
}

