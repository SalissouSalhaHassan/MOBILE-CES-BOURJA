import 'dart:async';
import 'package:flutter/material.dart';
import '../di/injection.dart';
import '../../features/messaging/data/messaging_repository.dart';

/// Client-side Mobile Push Notification Manager
/// Handles FCM/Device push tokens, background sync & real-time in-app alerts.
class MobilePushNotificationService {
  MobilePushNotificationService({MessagingRepository? repository})
      : _repository = repository ?? locator<MessagingRepository>();

  final MessagingRepository _repository;
  Timer? _pollingTimer;
  int _lastSeenNotificationId = 0;
  bool _isInitialized = false;

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationReceived =>
      _notificationStreamController.stream;

  /// Initialize Mobile Push Notifications and device registration
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Generate & register mobile push token with backend
      final mockDeviceToken = 'FCM_TOKEN_MOBILE_${DateTime.now().millisecondsSinceEpoch}';
      await _repository.registerPushToken(mockDeviceToken, deviceType: 'Flutter_Android_iOS');

      // 2. Fetch initial notification state to establish baseline ID
      final res = await _repository.getNotifications(limit: 5);
      final notifs = res['notifications'] as List<Map<String, dynamic>>? ?? [];
      if (notifs.isNotEmpty) {
        _lastSeenNotificationId = (notifs.first['id'] as num?)?.toInt() ?? 0;
      }

      // 3. Start real-time background sync loop (every 20 seconds)
      _startNotificationSyncLoop();

      debugPrint('MobilePushNotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing MobilePushNotificationService: $e');
    }
  }

  /// Background sync loop checking for new Push Notifications
  void _startNotificationSyncLoop() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await _checkNewPushNotifications();
    });
  }

  /// Query server for new push notifications
  Future<void> _checkNewPushNotifications() async {
    try {
      final res = await _repository.getNotifications(limit: 10);
      final notifs = res['notifications'] as List<Map<String, dynamic>>? ?? [];
      if (notifs.isEmpty) return;

      final latestId = (notifs.first['id'] as num?)?.toInt() ?? 0;
      if (_lastSeenNotificationId == 0) {
        _lastSeenNotificationId = latestId;
        return;
      }

      if (latestId > _lastSeenNotificationId) {
        // New notification(s) arrived!
        final newItems = notifs.where((n) {
          final id = (n['id'] as num?)?.toInt() ?? 0;
          return id > _lastSeenNotificationId;
        }).toList();

        _lastSeenNotificationId = latestId;

        for (final item in newItems.reversed) {
          _notificationStreamController.add(item);
        }
      }
    } catch (e) {
      debugPrint('Error checking push notifications: $e');
    }
  }

  /// Display real-time Floating Banner Notification inside the Flutter App
  static void showInAppPushBanner(BuildContext context, Map<String, dynamic> notification) {
    final title = (notification['title'] ?? 'Notification').toString();
    final content = (notification['content'] ?? '').toString();
    final category = (notification['category'] ?? '').toString();

    IconData iconData = Icons.notifications_active;
    Color iconColor = Colors.amber;

    if (category.toLowerCase().contains('absence') || title.contains('Absence')) {
      iconData = Icons.warning_amber_rounded;
      iconColor = const Color(0xFFE11D48); // Rose/Red
    } else if (category.toLowerCase().contains('devoir') || title.contains('Devoir')) {
      iconData = Icons.assignment_rounded;
      iconColor = const Color(0xFF6366F1); // Indigo
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E2235),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _pollingTimer?.cancel();
    _notificationStreamController.close();
  }
}
