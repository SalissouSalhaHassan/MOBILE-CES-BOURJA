import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';

class CanteenRepository {
  final SupabaseClient _client;
  final MobileApiClient _apiClient;

  CanteenRepository({SupabaseClient? client, MobileApiClient? apiClient})
      : _client = client ?? SupabaseClientManager().client,
        _apiClient = apiClient ?? MobileApiClient();

  /// Fetches student's canteen meal subscription, digital wallet balance, today's weekly menu, and recent meals served
  Future<Map<String, dynamic>> getStudentCanteenDetails(int studentId) async {
    try {
      final res = await _apiClient.get('/api/mobile/canteen/student?studentId=$studentId');
      if (res['success'] == true) {
        return res;
      }
    } catch (e) {
      debugPrint('Mobile API getStudentCanteenDetails error: $e');
    }

    // Direct Supabase Fallback
    try {
      final results = await Future.wait([
        _client
            .from('canteen_meal_subscriptions')
            .select('id, plan_type, monthly_price, special_diet, allergies_notice, status')
            .eq('student_id', studentId)
            .eq('status', 'Actif')
            .maybeSingle(),
        _client
            .from('student_wallets')
            .select('balance, daily_spending_limit, is_locked')
            .eq('student_id', studentId)
            .maybeSingle(),
        _client
            .from('canteen_meal_consumptions')
            .select('id, meal_type, menu_description, served_at, allergy_warning_triggered, cost_deducted')
            .eq('student_id', studentId)
            .order('served_at', ascending: false)
            .limit(10),
      ]);

      final subRow = results[0] as Map<String, dynamic>?;
      final walletRow = results[1] as Map<String, dynamic>?;
      final logsRows = results[2] as List<dynamic>?;

      return {
        'success': true,
        'isSubscribed': subRow != null,
        'subscription': subRow != null
            ? {
                'id': subRow['id'],
                'planType': subRow['plan_type'],
                'monthlyPrice': subRow['monthly_price'],
                'specialDiet': subRow['special_diet'],
                'allergiesNotice': subRow['allergies_notice'],
                'status': subRow['status'],
              }
            : null,
        'wallet': {
          'balance': walletRow != null ? (walletRow['balance'] as num).toDouble() : 0.0,
          'dailySpendingLimit':
              walletRow != null ? (walletRow['daily_spending_limit'] as num?)?.toDouble() ?? 2000.0 : 2000.0,
          'isLocked': walletRow != null ? (walletRow['is_locked'] == true) : false,
        },
        'todayMenu': null,
        'recentLogs': List<Map<String, dynamic>>.from(logsRows ?? []),
      };
    } catch (e) {
      debugPrint('Supabase fallback error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Tops up student wallet
  Future<Map<String, dynamic>> topUpWallet({
    required int studentId,
    required double amount,
    String? paymentMethod,
  }) async {
    try {
      return await _apiClient.post(
        '/api/mobile/canteen/topup',
        body: {
          'studentId': studentId,
          'amount': amount,
          'paymentMethod': paymentMethod ?? 'Mobile Money',
        },
      );
    } catch (e) {
      debugPrint('Error topping up canteen wallet: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetches weekly canteen menus and nutritional information
  Future<Map<String, dynamic>?> getWeeklyMenu() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/canteen/menu');
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching weekly canteen menu: $e');
      return null;
    }
  }

  /// Preorders a meal for a student
  Future<bool> preorderMeal({
    required int studentId,
    required String mealDate,
    required String menuDescription,
    double price = 1200.0,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/canteen/preorder', {
        'studentId': studentId,
        'mealDate': mealDate,
        'menuDescription': menuDescription,
        'price': price,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error preordering canteen meal: $e');
      return false;
    }
  }

  /// Process contactless QR payment
  Future<Map<String, dynamic>?> processQrPayment({
    required int studentId,
    required double amount,
    String? itemDescription,
  }) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/canteen/qr-pay', {
        'studentId': studentId,
        'amount': amount,
        'itemDescription': itemDescription,
      });
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Error processing QR payment: $e');
      return null;
    }
  }
}

