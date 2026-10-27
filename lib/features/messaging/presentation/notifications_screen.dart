import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/messaging_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final MessagingRepository _repository = locator<MessagingRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  String _activeCategory = 'Tous';
  bool _showUnreadOnly = false;

  static const _categories = [
    'Tous',
    'Messaging',
    'Finance',
    'Absence',
    'Scolarité',
    'Général',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.getNotifications(limit: 200);
      if (!mounted) return;
      setState(() {
        _all = List<Map<String, dynamic>>.from(
          data['notifications'] as List? ?? const [],
        );
        _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((n) {
        final category = (n['category'] ?? '').toString();
        final isRead = n['is_read'] == true || n['isRead'] == true;

        final matchesCategory =
            _activeCategory == 'Tous' || category == _activeCategory;
        final matchesRead = !_showUnreadOnly || !isRead;
        return matchesCategory && matchesRead;
      }).toList();
    });
  }

  Future<void> _markRead(int id) async {
    await _runAction(() => _repository.markNotificationRead(id));
  }

  Future<void> _markAllRead() async {
    await _runAction(_repository.markAllNotificationsRead);
  }

  Future<void> _delete(int id) async {
    await _runAction(() => _repository.deleteNotification(id));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return const Color(0xFF10B981);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'error':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _unreadCount > 0
              ? 'Notifications ($_unreadCount non lues)'
              : 'Notifications',
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          // Unread only toggle
          IconButton(
            tooltip: _showUnreadOnly ? 'Voir tout' : 'Non lues seulement',
            onPressed: _isSaving
                ? null
                : () {
                    setState(() => _showUnreadOnly = !_showUnreadOnly);
                    _applyFilter();
                  },
            icon: Icon(
              _showUnreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isSaving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Tout marquer lu',
              onPressed: _isSaving ? null : _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = cat == _activeCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _activeCategory = cat);
                    _applyFilter();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.slate600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 56, color: AppColors.slate400),
            const SizedBox(height: 12),
            Text(
              _showUnreadOnly
                  ? 'Aucune notification non lue.'
                  : 'Aucune notification.',
              style: AppTextStyles.body.copyWith(color: AppColors.slate500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _filtered[index];
          final id = (item['id'] as num).toInt();
          final isRead = item['is_read'] == true || item['isRead'] == true;
          final type = (item['type'] ?? 'info').toString();
          final color = _typeColor(type);
          final icon = _typeIcon(type);

          return Dismissible(
            key: ValueKey(id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              await _delete(id);
              return false;
            },
            child: InkWell(
              onTap: isRead ? null : () => _markRead(id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isRead ? Colors.white : color.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRead ? const Color(0xFFE2E8F0) : color,
                    width: isRead ? 1 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (item['title'] ?? 'Notification').toString(),
                                  style: isRead
                                      ? AppTextStyles.body
                                      : AppTextStyles.bodyBold,
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (item['content'] ?? '').toString(),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.slate600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (item['category'] ?? 'Général').toString(),
                                  style: AppTextStyles.caption
                                      .copyWith(color: color),
                                ),
                              ),
                              const Spacer(),
                              if (!isRead)
                                GestureDetector(
                                  onTap: () => _markRead(id),
                                  child: Text(
                                    'Marquer lu',
                                    style: AppTextStyles.caption.copyWith(
                                      color: const Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
