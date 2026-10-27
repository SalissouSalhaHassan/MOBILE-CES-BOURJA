import 'package:flutter/material.dart';
import '../api/sync_engine.dart';
import '../di/injection.dart';

/// A smart banner that shows connectivity and sync status.
/// States:
///   - Offline: amber/orange — shows last sync + retry button
///   - Syncing: blue — progress indicator + count of pending ops
///   - Connected (default): transparent, hides automatically
class SyncStatusBanner extends StatefulWidget {
  final VoidCallback? onRefresh;
  const SyncStatusBanner({super.key, this.onRefresh});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner>
    with SingleTickerProviderStateMixin {
  late final SyncEngine _syncEngine;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _syncEngine = locator<SyncEngine>();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _isOnline = _syncEngine.isOnlineNotifier.value;
    _isSyncing = _syncEngine.isSyncingNotifier.value;
    _lastSync = _syncEngine.lastSyncNotifier.value;

    _syncEngine.isOnlineNotifier.addListener(_onStatusChanged);
    _syncEngine.isSyncingNotifier.addListener(_onStatusChanged);
    _syncEngine.lastSyncNotifier.addListener(_onLastSyncChanged);

    _updateBannerVisibility();
  }

  void _onStatusChanged() {
    if (!mounted) return;
    setState(() {
      _isOnline = _syncEngine.isOnlineNotifier.value;
      _isSyncing = _syncEngine.isSyncingNotifier.value;
    });
    _updateBannerVisibility();
  }

  void _onLastSyncChanged() {
    if (!mounted) return;
    setState(() {
      _lastSync = _syncEngine.lastSyncNotifier.value;
    });
  }

  void _updateBannerVisibility() {
    final shouldShow = !_isOnline || _isSyncing;
    if (shouldShow) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    _syncEngine.isOnlineNotifier.removeListener(_onStatusChanged);
    _syncEngine.isSyncingNotifier.removeListener(_onStatusChanged);
    _syncEngine.lastSyncNotifier.removeListener(_onLastSyncChanged);
    _animController.dispose();
    super.dispose();
  }

  String _formatLastSync(DateTime? dt) {
    if (dt == null) return 'jamais synchronisé';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _handleRetry() async {
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    } else {
      await _syncEngine.triggerSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        if (_animController.value == 0.0 && _isOnline && !_isSyncing) {
          return const SizedBox.shrink();
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            )),
            child: _buildBannerContent(),
          ),
        );
      },
    );
  }

  Widget _buildBannerContent() {
    if (_isSyncing) return _buildSyncingBanner();
    if (!_isOnline) return _buildOfflineBanner();
    return const SizedBox.shrink();
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFFD97706)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mode hors-ligne — données en cache',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Dernière sync : ${_formatLastSync(_lastSync)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Réessayer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Synchronisation en cours…',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Envoi des données locales vers le serveur.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'EN COURS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
