import 'package:flutter/material.dart';
import '../api/sync_engine.dart';
import '../api/offline_queue_manager.dart';
import '../di/injection.dart';

class NetworkStatusBannerWidget extends StatefulWidget {
  const NetworkStatusBannerWidget({super.key});

  @override
  State<NetworkStatusBannerWidget> createState() => _NetworkStatusBannerWidgetState();
}

class _NetworkStatusBannerWidgetState extends State<NetworkStatusBannerWidget> {
  final SyncEngine _syncEngine = locator<SyncEngine>();
  final OfflineQueueManager _queueManager = locator<OfflineQueueManager>();

  @override
  void initState() {
    super.initState();
    _syncEngine.isOnlineNotifier.addListener(_updateState);
    _syncEngine.isSyncingNotifier.addListener(_updateState);
    _queueManager.pendingCountNotifier.addListener(_updateState);
  }

  @override
  void dispose() {
    _syncEngine.isOnlineNotifier.removeListener(_updateState);
    _syncEngine.isSyncingNotifier.removeListener(_updateState);
    _queueManager.pendingCountNotifier.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncEngine.isOnlineNotifier.value;
    final isSyncing = _syncEngine.isSyncingNotifier.value;
    final pendingCount = _queueManager.pendingCountNotifier.value;

    // If online and nothing is pending and not syncing, do not show banner
    if (isOnline && pendingCount == 0 && !isSyncing) {
      return const SizedBox.shrink();
    }

    final Color bgColor = !isOnline
        ? const Color(0xFFD97706) // Amber for offline
        : isSyncing
            ? const Color(0xFF2563EB) // Blue for syncing
            : const Color(0xFF059669); // Green for pending online

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                !isOnline ? Icons.wifi_off_rounded : Icons.cloud_sync_rounded,
                color: Colors.white,
                size: 16,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                !isOnline
                    ? 'Mode Hors-ligne (Modifications locales sauvegardées)'
                    : isSyncing
                        ? 'Synchronisation des données en cours...'
                        : '$pendingCount opération(s) en attente de synchronisation',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOnline && pendingCount > 0 && !isSyncing) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _syncEngine.triggerSync(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Sync',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
