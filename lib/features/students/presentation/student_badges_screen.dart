import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/mobile_api_client.dart';

class StudentBadgesScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final bool isTeacherOrAdmin;

  const StudentBadgesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.isTeacherOrAdmin = false,
  });

  @override
  State<StudentBadgesScreen> createState() => _StudentBadgesScreenState();
}

class _StudentBadgesScreenState extends State<StudentBadgesScreen> {
  final MobileApiClient _apiClient = MobileApiClient();

  bool _isLoading = true;
  int _totalPoints = 100;
  String _level = "Élève Exemplaire ⭐";
  List<dynamic> _earnedBadges = [];
  List<dynamic> _badgesCatalog = [];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson('/api/mobile/badges/student?studentId=${widget.studentId}');
      if (mounted) {
        if (res['success'] == true && res['data'] != null) {
          final data = res['data'];
          setState(() {
            _isLoading = false;
            _totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 100;
            _level = data['level']?.toString() ?? "Élève Exemplaire ⭐";
            _earnedBadges = (data['earnedBadges'] as List<dynamic>?) ?? [];
            _badgesCatalog = (data['badgesCatalog'] as List<dynamic>?) ?? [];
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAwardBadgeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 10),
                Text(
                  'Décerner une distinction',
                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sélectionnez le badge à attribuer à l\'élève :',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ..._badgesCatalog.map((b) {
              final name = b['name']?.toString() ?? '';
              final desc = b['description']?.toString() ?? '';
              final pts = (b['points'] as num?)?.toInt() ?? 25;

              return InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await _awardBadge(name, pts);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(desc, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Text(
                        '+$pts pts',
                        style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _awardBadge(String badgeName, int points) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/badges/award', {
        'studentId': widget.studentId,
        'badgeName': badgeName,
        'points': points,
        'reason': 'Excellente attitude et rigueur en classe.',
        'notifyParent': true,
      });

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Distinction "$badgeName" décernée avec succès !'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadBadges();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Distinctions & Badges',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isTeacherOrAdmin)
            IconButton(
              icon: const Icon(Icons.add_moderator_rounded, color: AppColors.primary),
              tooltip: 'Décerner un badge',
              onPressed: _showAwardBadgeDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Level Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _level,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_totalPoints PTS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Score de Mérite Scolaire de ${widget.studentName}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Title
                  Text(
                    'Badges & Distinctions Reçus (${_earnedBadges.length})',
                    style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_earnedBadges.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.workspace_premium_outlined, color: Colors.black26, size: 48),
                          const SizedBox(height: 10),
                          const Text('Aucun badge attribué pour le moment.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Les distinctions décernées par les enseignants apparaîtront ici.', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    ..._earnedBadges.map((b) {
                      final title = b['rewardType']?.toString() ?? 'Badge d\'honneur';
                      final reason = b['reason']?.toString() ?? 'Comportement remarquable';
                      final grantedBy = b['grantedBy']?.toString() ?? 'Direction';
                      final points = (b['pointsEffect'] as num?)?.toInt() ?? 25;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(reason, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('Décerné par : $grantedBy', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7EE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+$points pts',
                                style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
