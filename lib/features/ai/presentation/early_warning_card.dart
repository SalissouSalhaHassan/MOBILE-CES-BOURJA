import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class EarlyWarningCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onOpenTutor;

  const EarlyWarningCard({
    super.key,
    required this.data,
    this.onOpenTutor,
  });

  @override
  Widget build(BuildContext context) {
    final riskLevel = data['riskLevel']?.toString() ?? 'Faible';
    final isHigh = riskLevel == 'Élevé';
    final isMedium = riskLevel == 'Modéré';

    final Color badgeColor = isHigh
        ? AppColors.danger
        : isMedium
            ? AppColors.warning
            : AppColors.success;

    final Color bgColor = isHigh
        ? const Color(0xFFFEF2F2)
        : isMedium
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF0FDF4);

    final rawAtRisk = List<Map<String, dynamic>>.from(data['atRiskSubjects'] ?? []);
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var s in rawAtRisk) {
      final name = (s['subjectName'] ?? '').toString().trim();
      if (name.isNotEmpty && !uniqueMap.containsKey(name.toLowerCase())) {
        uniqueMap[name.toLowerCase()] = s;
      }
    }
    final atRiskSubjects = uniqueMap.values.toList();
    final summary = data['riskSummary']?.toString() ?? 'Suivi académique normal.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHigh ? Icons.warning_amber_rounded : Icons.shield_rounded,
                  color: badgeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diagnostic IA & Prévention',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.slate900,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Risque $riskLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate700,
              height: 1.4,
            ),
          ),
          if (atRiskSubjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: atRiskSubjects.map((s) {
                final scoreVal = s['score'];
                final scoreFormatted = scoreVal is num ? (scoreVal == scoreVal.roundToDouble() ? scoreVal.toInt().toString() : scoreVal.toStringAsFixed(1)) : scoreVal.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${s['subjectName']} : $scoreFormatted/20',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (onOpenTutor != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenTutor,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6366F1)),
                    SizedBox(width: 6),
                    Text(
                      'Lancer une séance de révision avec le Tuteur IA',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
