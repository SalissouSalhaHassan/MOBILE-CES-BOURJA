import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/mobile_api_client.dart';

class SatisfactionSurveyScreen extends StatefulWidget {
  const SatisfactionSurveyScreen({super.key});

  @override
  State<SatisfactionSurveyScreen> createState() => _SatisfactionSurveyScreenState();
}

class _SatisfactionSurveyScreenState extends State<SatisfactionSurveyScreen> {
  final MobileApiClient _apiClient = MobileApiClient();
  final TextEditingController _commentController = TextEditingController();

  int _overallRating = 5;
  int _teachingRating = 5;
  int _transportRating = 5;
  int _canteenRating = 5;
  int _cleanlinessRating = 5;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    setState(() => _isSubmitting = true);
    try {
      final res = await _apiClient.postJson('/api/mobile/feedback/submit', {
        'overallRating': _overallRating,
        'teachingQualityRating': _teachingRating,
        'transportRating': _transportRating,
        'canteenRating': _canteenRating,
        'cleanlinessRating': _cleanlinessRating,
        'comment': _commentController.text.trim(),
      });

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 28),
                  SizedBox(width: 10),
                  Text('Merci pour votre avis !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: const Text(
                'Votre évaluation et vos suggestions permettent à notre direction d\'améliorer continuellement la qualité de notre encadrement scolaire.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _ratingStars(String title, int currentRating, ValueChanged<int> onChanged, {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              final isFilled = star <= currentRating;
              return IconButton(
                onPressed: () => onChanged(star),
                icon: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFilled ? const Color(0xFFF59E0B) : Colors.black26,
                  size: 32,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Baromètre de Satisfaction',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rate_review_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Évaluez votre expérience Edut',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prenez 1 minute pour partager votre appréciation sur le suivi pédagogique et les services scolaires.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rating Criteria
          _ratingStars('Note Globale de Satisfaction ⭐', _overallRating, (val) => setState(() => _overallRating = val)),
          _ratingStars('Qualité de l\'Enseignement & Pédagogie', _teachingRating, (val) => setState(() => _teachingRating = val), subtitle: 'Clarté des cours, devoirs et disponibilité des professeurs.'),
          _ratingStars('Transport Scolaire & Ponctualité', _transportRating, (val) => setState(() => _transportRating = val), subtitle: 'Respect des horaires et suivi GPS en direct.'),
          _ratingStars('Restauration & Cantine Scolaire', _canteenRating, (val) => setState(() => _canteenRating = val), subtitle: 'Qualité des repas et hygiène du réfectoire.'),
          _ratingStars('Hygiène, Sécurité & Cadre de Vie', _cleanlinessRating, (val) => setState(() => _cleanlinessRating = val), subtitle: 'Propreté générale et sécurité des enfants.'),

          // Suggestions / Comments
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remarques ou Suggestions particulières (Optionnel)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ex: Nous apprécions particulièrement la réactivité du secrétariat...',
                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitSurvey,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Envoyer mon évaluation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
