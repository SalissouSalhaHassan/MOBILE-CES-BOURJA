import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/session_manager.dart';
import '../di/injection.dart';

class InactivityLockService with WidgetsBindingObserver {
  static final InactivityLockService _instance = InactivityLockService._internal();
  factory InactivityLockService() => _instance;
  InactivityLockService._internal();

  final ValueNotifier<bool> isLocked = ValueNotifier<bool>(false);
  
  Timer? _heartbeatTimer;
  DateTime _lastActivityTime = DateTime.now();
  DateTime? _pausedTime;
  Duration _timeout = const Duration(minutes: 3);
  bool _isTracking = false;

  Duration get timeout => _timeout;
  DateTime get lastActivityTime => _lastActivityTime;

  Future<void> initialize() async {
    final minutes = await locator<SessionManager>().getInactivityTimeoutMinutes();
    _timeout = Duration(minutes: minutes > 0 ? minutes : 3);
    startTracking();
  }

  void startTracking() {
    if (!_isTracking) {
      _isTracking = true;
      _lastActivityTime = DateTime.now();
      WidgetsBinding.instance.addObserver(this);
      
      // Heartbeat timer running every 3 seconds to check inactivity
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkInactivity());
      debugPrint('[InactivityLockService] Tracking started with timeout ${_timeout.inMinutes} minutes.');
    }
  }

  void updateTimeout(int minutes) {
    if (minutes > 0) {
      _timeout = Duration(minutes: minutes);
      locator<SessionManager>().setInactivityTimeoutMinutes(minutes);
      recordActivity();
      debugPrint('[InactivityLockService] Timeout updated to $minutes minutes.');
    }
  }

  void recordActivity() {
    if (isLocked.value) return;
    _lastActivityTime = DateTime.now();
  }

  Future<void> _checkInactivity() async {
    if (isLocked.value) return;

    final sessionManager = locator<SessionManager>();
    final loggedIn = await sessionManager.isLoggedIn();
    if (!loggedIn) {
      // User is on Login/Register screen; keep updating activity time
      _lastActivityTime = DateTime.now();
      return;
    }

    final elapsed = DateTime.now().difference(_lastActivityTime);
    if (elapsed >= _timeout) {
      debugPrint('[InactivityLockService] Inactivity threshold reached (${elapsed.inSeconds}s >= ${_timeout.inSeconds}s). Locking app.');
      lock();
    }
  }

  void lock() {
    isLocked.value = true;
    debugPrint('[InactivityLockService] >>> APP IS LOCKED <<<');
  }

  void unlock() {
    _lastActivityTime = DateTime.now();
    isLocked.value = false;
    debugPrint('[InactivityLockService] >>> APP IS UNLOCKED <<<');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final backgroundElapsed = DateTime.now().difference(_pausedTime!);
        _pausedTime = null;

        if (backgroundElapsed >= _timeout && !isLocked.value) {
          locator<SessionManager>().isLoggedIn().then((loggedIn) {
            if (loggedIn) {
              debugPrint('[InactivityLockService] Resumed after background ($backgroundElapsed). Locking app.');
              lock();
            } else {
              recordActivity();
            }
          });
          return;
        }
      }
      recordActivity();
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _isTracking = false;
  }
}
