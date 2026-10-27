import 'package:flutter/foundation.dart';
import '../../../core/api/mobile_api_client.dart';

/// Supported target audiences for sendMessage.
abstract class MessageTarget {
  static const String allParents = 'Tous les Parents';
  static const String allStaff = 'Tout le Personnel';
  static const String everyone = 'Tous (Parents + Staff)';
  static const String specificClass = 'Classe specifique';
  static const String specificRecipient = 'Destinataire specifique';
}

/// Supported message channels.
abstract class MessageChannel {
  static const String internal = 'Interne';
  static const String sms = 'SMS';
  static const String whatsapp = 'WhatsApp';
  static const String email = 'Email';
}

class MessagingRepository {
  MessagingRepository({MobileApiClient? apiClient})
      : _apiClient = apiClient ?? MobileApiClient();

  final MobileApiClient _apiClient;

  // ─────────────────────────────────────────────────────────────────────────
  //  NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch notifications for the current user.
  /// [category]   — optional category filter (e.g. 'Finance', 'Absence')
  /// [unreadOnly] — if true, returns only unread items
  /// [limit]      — max items to fetch (default 100)
  Future<Map<String, dynamic>> getNotifications({
    String? category,
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        if (unreadOnly) 'unreadOnly': 'true',
        if (category != null && category.isNotEmpty) 'category': category,
      };
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _apiClient.getJson('/api/mobile/notifications?$query');

      return {
        'notifications': List<Map<String, dynamic>>.from(
          body['notifications'] ?? const [],
        ),
        'unreadCount': (body['unreadCount'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return {'notifications': <Map<String, dynamic>>[], 'unreadCount': 0};
    }
  }

  /// Mark a single notification as read.
  Future<void> markNotificationRead(int id) async {
    try {
      await _apiClient.patchJson('/api/mobile/notifications/$id');
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllNotificationsRead() async {
    try {
      await _apiClient.patchJson('/api/mobile/notifications');
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  /// Delete a single notification.
  Future<void> deleteNotification(int id) async {
    try {
      await _apiClient.deleteJson('/api/mobile/notifications/$id');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Returns only the unread count (lightweight call for badge display).
  Future<int> getUnreadCount() async {
    try {
      final body = await _apiClient.getJson(
        '/api/mobile/notifications?unreadOnly=true&limit=1',
      );
      return (body['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Register device push token with the backend server.
  Future<bool> registerPushToken(String token, {String deviceType = 'Flutter/Mobile'}) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/push-token', {
        'pushToken': token,
        'deviceType': deviceType,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error registering push token: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MESSAGING DASHBOARD (staff / teacher / admin only)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMessagingDashboard() async {
    try {
      final body = await _apiClient.getJson('/api/mobile/messaging');
      return {
        'templates': List<Map<String, dynamic>>.from(body['templates'] ?? const []),
        'logs': List<Map<String, dynamic>>.from(body['logs'] ?? const []),
        'classes': List<Map<String, dynamic>>.from(body['classes'] ?? const []),
        'recipients': List<Map<String, dynamic>>.from(body['recipients'] ?? const []),
        'stats': Map<String, dynamic>.from(body['stats'] ?? const {}),
      };
    } catch (e) {
      debugPrint('Error fetching messaging dashboard: $e');
      return {
        'templates': <Map<String, dynamic>>[],
        'logs': <Map<String, dynamic>>[],
        'classes': <Map<String, dynamic>>[],
        'recipients': <Map<String, dynamic>>[],
        'stats': <String, dynamic>{},
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SEND MESSAGE (staff / teacher / admin only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Send a message to a target audience.
  ///
  /// [msgType]         — use [MessageChannel] constants
  /// [targetAudience]  — use [MessageTarget] constants
  /// [content]         — message body (required)
  /// [subject]         — optional subject / title
  /// [className]       — required when targetAudience = [MessageTarget.specificClass]
  /// [recipientUserId] — required when targetAudience = [MessageTarget.specificRecipient]
  ///
  /// Returns the number of recipients who received the message.
  Future<int> sendMessage({
    required String msgType,
    required String targetAudience,
    required String content,
    String? subject,
    String? className,
    int? recipientUserId,
  }) async {
    try {
      final body = await _apiClient.postJson('/api/mobile/messaging', {
        'msgType': msgType,
        'targetAudience': targetAudience,
        'subject': subject,
        'content': content,
        if (className != null) 'className': className,
        if (recipientUserId != null) 'recipientUserId': recipientUserId,
      });
      return (body['recipientCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Shortcut: Send to all parents in the school.
  Future<int> sendToAllParents({
    required String content,
    String? subject,
    String msgType = MessageChannel.internal,
  }) =>
      sendMessage(
        msgType: msgType,
        targetAudience: MessageTarget.allParents,
        content: content,
        subject: subject,
      );

  /// Shortcut: Send to all staff in the school.
  Future<int> sendToAllStaff({
    required String content,
    String? subject,
    String msgType = MessageChannel.internal,
  }) =>
      sendMessage(
        msgType: msgType,
        targetAudience: MessageTarget.allStaff,
        content: content,
        subject: subject,
      );

  /// Shortcut: Send to a specific class (parents/students of that class).
  Future<int> sendToClass({
    required String className,
    required String content,
    String? subject,
    String msgType = MessageChannel.internal,
  }) =>
      sendMessage(
        msgType: msgType,
        targetAudience: MessageTarget.specificClass,
        content: content,
        subject: subject,
        className: className,
      );

  /// Shortcut: Send to a single user (student, parent, or staff member).
  Future<int> sendToUser({
    required int userId,
    required String content,
    String? subject,
    String msgType = MessageChannel.internal,
  }) =>
      sendMessage(
        msgType: msgType,
        targetAudience: MessageTarget.specificRecipient,
        content: content,
        subject: subject,
        recipientUserId: userId,
      );
}
