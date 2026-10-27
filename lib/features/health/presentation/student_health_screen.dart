import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/mobile_api_client.dart';

class StudentHealthScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentHealthScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentHealthScreen> createState() => _StudentHealthScreenState();
}

class _StudentHealthScreenState extends State<StudentHealthScreen> {
  final MobileApiClient _apiClient = MobileApiClient();

  bool _isLoading = true;
  Map<String, dynamic>? _medicalRecord;
  List<dynamic> _visits = [];

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson('/api/mobile/health/student?studentId=${widget.studentId}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res['success'] == true && res['data'] != null) {
            _medicalRecord = res['data']['medicalRecord'] != null
                ? Map<String, dynamic>.from(res['data']['medicalRecord'])
                : null;
            _visits = (res['data']['visits'] as List<dynamic>?) ?? [];
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callNumber(String phone) async {
    final clean = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloodGroup = _medicalRecord?['bloodGroup']?.toString() ?? 'O+';
    final allergies = _medicalRecord?['allergies']?.toString() ?? 'Aucune allergie connue';
    final chronic = _medicalRecord?['chronicConditions']?.toString() ?? 'Néant';
    final emergencyPhone = _medicalRecord?['emergencyContactPhone']?.toString() ?? '+227 90 00 11 22';
    final emergencyName = _medicalRecord?['emergencyContactName']?.toString() ?? 'Parent';
    final vaccinations = (_medicalRecord?['vaccinations'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Dossier Médical & Santé',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadHealthData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Emergency Quick Profile
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'FICHE D\'URGENCE VITAL',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Groupe $bloodGroup',
                                style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.studentName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Allergies Warning
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Allergies : $allergies',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.medical_services_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Pathologie : $chronic',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Emergency Contact Bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Urgence : $emergencyName ($emergencyPhone)',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.call, color: Colors.white, size: 18),
                                onPressed: () => _callNumber(emergencyPhone),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Vaccinations Checklist
                  if (vaccinations.isNotEmpty) ...[
                    Text('Carnet de Vaccination & Immunité', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: vaccinations.map((v) {
                          final name = v['name']?.toString() ?? 'Vaccin';
                          final isDone = v['isDone'] == true;
                          final date = v['date']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isDone ? const Color(0xFF059669) : Colors.black26,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                if (date.isNotEmpty)
                                  Text(date, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Infirmary Visits Timeline
                  Text('Historique des Passages à l\'Infirmerie (${_visits.length})', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (_visits.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.favorite_border_rounded, color: Colors.black26, size: 44),
                          const SizedBox(height: 8),
                          const Text('Aucune visite médicale enregistrée.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('L\'élève est en parfaite santé.', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ..._visits.map((v) {
                      final symptoms = v['symptoms']?.toString() ?? 'Consultation';
                      final care = v['careProvided']?.toString() ?? 'Soins infirmiers';
                      final temp = v['temperature'];
                      final outcome = v['outcome']?.toString() ?? 'Retour en classe';
                      final nurse = v['nurseName']?.toString() ?? 'Infirmerie';
                      final date = v['visitDate']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.medical_services_rounded, color: Color(0xFF2563EB), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(symptoms, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('$nurse • $date', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                if (temp != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${temp}°C',
                                      style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Soins prodigués : $care', style: const TextStyle(color: Colors.black87, fontSize: 12)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7EE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Décision : $outcome',
                                style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
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
