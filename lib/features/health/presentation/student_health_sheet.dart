import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection.dart';
import '../data/health_repository.dart';

class StudentHealthSheet extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final String? studentClass;

  const StudentHealthSheet({
    super.key,
    this.studentId,
    this.studentName,
    this.studentClass,
  });

  static Future<void> show(
    BuildContext context, {
    int? studentId,
    String? studentName,
    String? studentClass,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentHealthSheet(
        studentId: studentId,
        studentName: studentName,
        studentClass: studentClass,
      ),
    );
  }

  @override
  State<StudentHealthSheet> createState() => _StudentHealthSheetState();
}

class _StudentHealthSheetState extends State<StudentHealthSheet> {
  final HealthRepository _repository = locator<HealthRepository>();

  bool _isLoading = true;
  Map<String, dynamic>? _healthData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHealthProfile();
  }

  Future<void> _loadHealthProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getStudentHealthProfile(
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(() {
          _healthData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de charger le carnet de santé.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicalRecord = _healthData?['medicalRecord'] as Map<String, dynamic>? ?? {};
    final visits = List<Map<String, dynamic>>.from(_healthData?['visits'] ?? []);
    final vaccinations = List<Map<String, dynamic>>.from(medicalRecord['vaccinations'] ?? []);
    final isAtInfirmary = _healthData?['isCurrentlyAtInfirmary'] == true;
    final currentVisit = _healthData?['currentInfirmaryVisit'] as Map<String, dynamic>?;

    final bloodGroup = medicalRecord['bloodGroup']?.toString() ?? 'Non renseigné';
    final allergies = medicalRecord['allergies']?.toString() ?? 'Aucune';
    final chronicConditions = medicalRecord['chronicConditions']?.toString() ?? 'Aucune';
    final emergencyPhone = medicalRecord['emergencyContactPhone']?.toString() ?? '';
    final emergencyName = medicalRecord['emergencyContactName']?.toString() ?? 'Parent';

    final hasAllergies = allergies.isNotEmpty && allergies.toLowerCase() != 'aucune' && allergies.toLowerCase() != 'aucune connue';
    final hasChronic = chronicConditions.isNotEmpty && chronicConditions.toLowerCase() != 'aucune';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Color(0xFFE11D48),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName ?? "Dossier Médical Élève",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Carnet de santé & Infirmerie Scolaire • ${widget.studentClass ?? 'Classe'}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE11D48),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🚨 URGENT BANNER IF CURRENTLY AT INFIRMARY
                            if (isAtInfirmary && currentVisit != null) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE11D48).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.emergency_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "ÉLÈVE ACTUELLEMENT À L'INFIRMERIE",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Motif : ${currentVisit['symptoms']} • T°: ${currentVisit['temperature'] ?? 'N/A'}°C",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "Décision : ${currentVisit['outcome'] ?? 'En observation'}",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // BLOOD GROUP & EMERGENCY BADGES
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFFECDD3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.bloodtype_rounded,
                                          color: Color(0xFFE11D48),
                                          size: 28,
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "GROUPE SANGUIN",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF9F1239),
                                              ),
                                            ),
                                            Text(
                                              bloodGroup,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFBE123C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (emergencyPhone.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () => _callPhone(emergencyPhone),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A), size: 24),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Urgence $emergencyName",
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ALLERGIES & CHRONIC CONDITIONS ALERTS
                            if (hasAllergies) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "ALLERGIES CONNUES",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            allergies,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF78350F),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            if (hasChronic) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.favorite_rounded, color: Color(0xFFDC2626), size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "PATHOLOGIE CHRONIQUE (SUIVI SPÉCIAL)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF991B1B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            chronicConditions,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF7F1D1D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // DIGITAL VACCINE CARD
                            const Text(
                              "💉 Carnet de Vaccination Scolaire",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vaccinations.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final v = vaccinations[index];
                                  final isDone = v['isDone'] == true;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          color: isDone ? const Color(0xFF16A34A) : Colors.grey[400],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            v['name']?.toString() ?? 'Vaccin',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                                              color: isDone ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          isDone ? "À jour ✅" : "À faire ⚠️",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDone ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // INFIRMARY VISITS HISTORY
                            const Text(
                              "🏥 Historique des Passages à l'Infirmerie",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (visits.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Text(
                                    "Aucun passage à l'infirmerie enregistré. L'élève est en excellente santé ! ✨",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visits.length,
                                itemBuilder: (context, index) {
                                  final v = visits[index];
                                  final dateStr = v['visit_date'] ?? v['visitDate'] ?? '';
                                  DateTime? dt;
                                  if (dateStr.isNotEmpty) {
                                    dt = DateTime.tryParse(dateStr.toString());
                                  }

                                  final temp = v['temperature'] != null ? v['temperature'].toString() : null;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              dt != null
                                                  ? "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"
                                                  : "Visite",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            if (temp != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF1F2),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  "$temp °C",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Color(0xFFE11D48),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Symptômes : ${v['symptoms'] ?? 'Non spécifié'}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        if (v['care_provided'] != null || v['careProvided'] != null)
                                          Text(
                                            "Soins : ${v['care_provided'] ?? v['careProvided']}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        if (v['prescriptions'] != null && v['prescriptions'].toString().isNotEmpty)
                                          Text(
                                            "💊 Traitement : ${v['prescriptions']}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF4F46E5),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Décision : ${v['outcome'] ?? 'Retour en classe'}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
