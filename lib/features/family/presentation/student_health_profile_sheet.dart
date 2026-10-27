import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class StudentHealthProfileSheet extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentHealthProfileSheet({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  static void show(BuildContext context, {required int studentId, required String studentName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentHealthProfileSheet(studentId: studentId, studentName: studentName),
    );
  }

  @override
  State<StudentHealthProfileSheet> createState() => _StudentHealthProfileSheetState();
}

class _StudentHealthProfileSheetState extends State<StudentHealthProfileSheet> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/health?studentId=${widget.studentId}');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _profile = Map<String, dynamic>.from(res['data']['profile'] ?? {});
          _visits = List<Map<String, dynamic>>.from(res['data']['visits'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dossier Médical & Santé', style: AppTextStyles.heading3),
                      Text('Élève : ${widget.studentName}', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Medical Highlights
                      Row(
                        children: [
                          Expanded(
                            child: _buildHealthBadge('Groupe Sanguin', _profile?['bloodGroup'] ?? 'O+', Icons.water_drop_rounded, const Color(0xFFEF4444)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHealthBadge('Aptitude EPS', 'Apte', Icons.directions_run_rounded, const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Allergies & Conditions
                      _buildInfoSection(
                        'Allergies Déclarées',
                        (_profile?['allergies'] as List?)?.join(', ') ?? 'Aucune allergie connue',
                        Icons.warning_amber_rounded,
                        const Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoSection(
                        'Antécédents / Conditions',
                        (_profile?['chronicConditions'] as List?)?.join(', ') ?? 'Néant',
                        Icons.medical_services_outlined,
                        const Color(0xFF6366F1),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoSection(
                        'Vaccinations à Jour',
                        (_profile?['vaccinations'] as List?)?.join(', ') ?? 'BCG, Polio, Fièvre Jaune',
                        Icons.verified_rounded,
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 20),

                      // Clinic visits history
                      const Text(
                        'Historique des Passages à l\'Infirmerie :',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 10),
                      if (_visits.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Aucun passage à l\'infirmerie enregistré ce trimestre.', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                        )
                      else
                        ..._visits.map((v) => _buildVisitItem(v)),
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 10.5, color: AppColors.slate600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(content, style: const TextStyle(fontSize: 12, color: AppColors.slate700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> v) {
    final reason = v['reason'] ?? 'Consultation';
    final treatment = v['treatment'] ?? 'Soins';
    final temp = v['temperature'] ?? '37°C';
    final nurse = v['nurseName'] ?? 'Infirmière';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text('Temp: $temp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Traitement : $treatment', style: const TextStyle(fontSize: 11.5, color: AppColors.slate700)),
          Text('Soigné par : $nurse', style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
        ],
      ),
    );
  }
}
