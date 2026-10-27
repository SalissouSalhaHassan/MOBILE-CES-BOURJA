import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/api/mobile_api_client.dart';

class LibraryRepository {
  final MobileApiClient _apiClient;
  static const String boxLibraryName = 'offline_library_box';

  LibraryRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  /// Fetches digital & physical library catalog
  Future<Map<String, dynamic>?> getCatalog({
    String? category,
    String? query,
    String? format,
  }) async {
    try {
      final queryParams = <String>[
        if (category != null && category.isNotEmpty && category != "Tous")
          'category=${Uri.encodeComponent(category)}',
        if (query != null && query.isNotEmpty)
          'q=${Uri.encodeComponent(query)}',
        if (format != null && format.isNotEmpty && format != "all")
          'format=${Uri.encodeComponent(format)}',
      ].join('&');

      final url = '/api/mobile/e-library/catalog${queryParams.isNotEmpty ? '?$queryParams' : ''}';
      final res = await _apiClient.getJson(url);
      if (res['success'] == true && res['data'] != null) {
        final data = Map<String, dynamic>.from(res['data']);
        // Cache in Hive
        _cacheCatalogLocally(data);
        return data;
      }
    } catch (e) {
      debugPrint("LibraryRepository.getCatalog network error: $e");
    }

    // Fallback to local offline cache
    return _getCachedCatalogLocally();
  }

  /// Fetches student or user library loan history & reservations
  Future<List<Map<String, dynamic>>> getIssues({int? studentId}) async {
    try {
      if (studentId != null) {
        final res = await _apiClient.getJson(
          '/api/mobile/family/library?action=getStudentLibraryIssues&studentId=$studentId',
        );
        if (res['success'] == true && res['data'] != null) {
          final list = (res['data'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cacheIssuesLocally(list);
          return list;
        }
      }
    } catch (e) {
      debugPrint("LibraryRepository.getIssues network error: $e");
    }

    return _getCachedIssuesLocally();
  }

  /// Reserves a physical book for a student
  Future<bool> reserveBook({required int bookId, required int studentId}) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/family/library', {
        'action': 'reserveBook',
        'payload': {
          'bookId': bookId,
          'studentId': studentId,
        },
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint("LibraryRepository.reserveBook error: $e");
      return false;
    }
  }

  Future<void> _cacheCatalogLocally(Map<String, dynamic> data) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      await box.put('cached_catalog', data);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getCachedCatalogLocally() async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      final raw = box.get('cached_catalog');
      if (raw != null) {
        return Map<String, dynamic>.from(raw as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheIssuesLocally(List<Map<String, dynamic>> issues) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      await box.put('cached_issues', issues);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _getCachedIssuesLocally() async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      final raw = box.get('cached_issues');
      if (raw != null && raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Mark book as downloaded offline
  Future<void> markBookDownloaded(int bookId, String localPath) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      await box.put('book_download_$bookId', localPath);
    } catch (_) {}
  }

  /// Check if book is saved locally
  Future<String?> getDownloadedBookPath(int bookId) async {
    try {
      final box = await Hive.openBox(boxLibraryName);
      final val = box.get('book_download_$bookId');
      return val?.toString();
    } catch (_) {}
    return null;
  }
}
