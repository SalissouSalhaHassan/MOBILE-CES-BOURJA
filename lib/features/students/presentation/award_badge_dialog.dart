import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AwardBadgeDialog extends StatefulWidget {
  final int studentId;
  final String studentName;

  const AwardBadgeDialog({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  static Future<void> show(BuildContext context, {required int studentId, required String studentName}) {
    return showDialog(
      context: context,
      builder: (_) => AwardBadgeDialog(studentId: studentId, studentName: studentName),
    );
  }

  @override
  State<AwardBadgeDialog> createState() => _AwardBadgeDialogState();
}

class _AwardBadgeDialogState extends State<AwardBadgeDialog> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _reasonController = TextEditingController();

  String _selectedBadgeId = 'math_star';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _badges = [
    {
      'id': 'math_star',
      'title': 'Étoile des Maths',
      'titleAr': 'نجم الرياضيات',
      'icon': '🌟',
      'color': Color(0xFFF59E0B),
      'points': '+50 pts',
    },
    {
      'id': 'golden_discipline',
      'title': 'Discipline d\'Or',
      'titleAr': 'وسام الانضباط الذهبي',
      'icon': '🎖️',
      'color': Color(0xFF10B981),
      'points': '+40 pts',
    },
    {
      'id': 'reading_champion',
      'title': 'Champion de Lecture',
      'titleAr': 'بطل القراءة',
      'icon': '📚',
      'color': Color(0xFF3B82F6),
      'points': '+35 pts',
    },
    {
      'id': 'rapid_progress',
      'title': 'Progression Éclair',
      'titleAr': 'أفضل تقدم أسبوعي',
      'icon': '🚀',
      'color': Color(0xFF8B5CF6),
      'points': '+45 pts',
    },
    {
      'id': 'science_genius',
      'title': 'Génie Scientifique',
      'titleAr': 'العبقري العلمي',
      'icon': '💡',
      'color': Color(0xFF06B6D4),
      'points': '+50 pts',
    },
    {
      'id': 'team_spirit',
      'title': 'Esprit d\'Équipe',
      'titleAr': 'روح التعاون',
      'icon': '🤝',
      'color': Color(0xFFEC4899),
      'points': '+30 pts',
    },
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _awardBadge() async {
    setState(() => _isSubmitting = true);
    try {
      final res = await _apiClient.postJson('/api/mobile/badges', {
        'studentId': widget.studentId,
        'badgeId': _selectedBadgeId,
        'reason': _reasonController.text.trim(),
      });

      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Écusson d\'honneur décerné à ${widget.studentName} ! 🏆'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 24),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Décerner un Écusson de Mérite',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Élève : ${widget.studentName}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              const Text('Sélectionner le badge d\'honneur :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _badges.length,
                itemBuilder: (context, index) {
                  final b = _badges[index];
                  final isSel = b['id'] == _selectedBadgeId;
                  final Color color = b['color'];

                  return InkWell(
                    onTap: () => setState(() => _selectedBadgeId = b['id']),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? color.withValues(alpha: 0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel ? color : const Color(0xFFE2E8F0),
                          width: isSel ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b['icon'], style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            b['title'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              color: isSel ? color : AppColors.slate800,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            b['points'],
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text('Motif d\'encouragement / Félicitations :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ex: 19/20 au contrôle et participation brillante...',
                  hintStyle: TextStyle(color: AppColors.slate400, fontSize: 11.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppColors.slate500)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _awardBadge,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Décerner le badge 🏆', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
