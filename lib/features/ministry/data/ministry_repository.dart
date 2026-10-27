import '../../../core/api/mobile_api_client.dart';

class MinistryRepository {
  MinistryRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  final MobileApiClient _apiClient;

  Future<Map<String, dynamic>> getSummary() async {
    final body = await _apiClient.getJson('/api/mobile/ministry/summary');
    return Map<String, dynamic>.from(body['summary'] ?? const {});
  }

  Future<List<Map<String, dynamic>>> getSchools({String query = ""}) async {
    final path = query.isNotEmpty
        ? '/api/mobile/ministry/schools?query=${Uri.encodeComponent(query)}'
        : '/api/mobile/ministry/schools';
    final body = await _apiClient.getJson(path);
    final list = body['schools'] as List? ?? [];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    final body = await _apiClient.getJson('/api/mobile/ministry/alerts');
    final list = body['alerts'] as List? ?? [];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
