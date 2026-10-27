import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../data/discipline_repository.dart';

class StudentConductSheet extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final String? studentClass;

  const StudentConductSheet({
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
      builder: (context) => StudentConductSheet(
        studentId: studentId,
        studentName: studentName,
        studentClass: studentClass,
      ),
    );
  }

  @override
  State<StudentConductSheet> createState() => _StudentConductSheetState();
}

class _StudentConductSheetState extends State<StudentConductSheet> {
  final DisciplineRepository _repository = locator<DisciplineRepository>();

  bool _isLoading = true;
  Map<String, dynamic>? _disciplineData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConductProfile();
  }

  Future<void> _loadConductProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getStudentDisciplineProfile(
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(() {
          _disciplineData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de charger le dossier de conduite.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _disciplineData?['student'] as Map<String, dynamic>? ?? {};
    final incidents = List<Map<String, dynamic>>.from(_disciplineData?['incidents'] ?? []);
    final councils = List<Map<String, dynamic>>.from(_disciplineData?['councils'] ?? []);
    final convocations = List<Map<String, dynamic>>.from(_disciplineData?['convocations'] ?? []);
    final rewards = List<Map<String, dynamic>>.from(_disciplineData?['rewards'] ?? []);

    final hasPendingConvocation = _disciplineData?['hasPendingConvocation'] == true;
    final pendingConvocation = _disciplineData?['pendingConvocation'] as Map<String, dynamic>?;

    final hasActiveCouncil = _disciplineData?['hasActiveCouncil'] == true;
    final activeCouncil = _disciplineData?['activeCouncil'] as Map<String, dynamic>?;

    final score = student['behaviorScore'] ?? 20;
    final appraisal = student['conductAppraisal']?.toString() ?? 'Bon comportement';

    final isWarning = score < 14;

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
                    color: isWarning ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: isWarning ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName ?? "Dossier Disciplinaire",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Suivi du Comportement & Discipline • ${widget.studentClass ?? 'Classe'}",
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
                      color: Color(0xFF4F46E5),
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
                            // 🚨 URGENT CONVOCATION BANNER
                            if (hasPendingConvocation && pendingConvocation != null) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFDC2626), Color(0xFFE11D48)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.mark_email_unread_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "CONVOCATION DES PARENTS EN ATTENTE",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Motif : ${pendingConvocation['reason']}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "Lieu : ${pendingConvocation['location'] ?? 'Bureau du Censeur'}",
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

                            // 🚨 ACTIVE DISCIPLINARY COUNCIL BANNER
                            if (hasActiveCouncil && activeCouncil != null) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF450A0A),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFDC2626)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.gavel_rounded,
                                      color: Color(0xFFFCA5A5),
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "CONSEIL DE DISCIPLINE PROGRAMMÉ",
                                            style: TextStyle(
                                              color: Color(0xFFFCA5A5),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Faits : ${activeCouncil['reproached_facts'] ?? activeCouncil['reproachedFacts']}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "Date : ${activeCouncil['session_date'] ?? activeCouncil['sessionDate']}",
                                            style: const TextStyle(
                                              color: Colors.white70,
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

                            // SCORE DE CONDUITE
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isWarning ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isWarning ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isWarning ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      "$score",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "NOTE DE CONDUITE & ASSIDUITÉ",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        Text(
                                          "$score / 20",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isWarning ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                                          ),
                                        ),
                                        Text(
                                          appraisal,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isWarning ? const Color(0xFF9F1239) : const Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // INCIDENTS & SANCTIONS LIST
                            const Text(
                              "⚠️ Incidents et Sanctions Enregistrés",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (incidents.isEmpty)
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
                                    "Aucun incident disciplinaire signalé. Élève exemplaire ! ✨",
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
                                itemCount: incidents.length,
                                itemBuilder: (context, index) {
                                  final inc = incidents[index];
                                  final dateStr = inc['date']?.toString() ?? '';
                                  DateTime? dt;
                                  if (dateStr.isNotEmpty) {
                                    dt = DateTime.tryParse(dateStr);
                                  }

                                  final severity = inc['severity']?.toString() ?? 'Mineur';
                                  final sanction = inc['sanction_type'] ?? inc['sanctionType'] ?? "Rappel à l'ordre";

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
                                              inc['incident_type'] ?? inc['incidentType'] ?? 'Incident',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: severity == 'Critique'
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                severity,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  color: severity == 'Critique'
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFFD97706),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          inc['description']?.toString() ?? 'Aucun détail',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Sanction : $sanction",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFBE123C),
                                              ),
                                            ),
                                            if (dt != null)
                                              Text(
                                                "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 20),

                            // REWARDS SECTION
                            if (rewards.isNotEmpty) ...[
                              const Text(
                                "🎖️ Tableau d'Honneur et Encouragements",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: rewards.length,
                                itemBuilder: (context, index) {
                                  final r = rewards[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.military_tech_rounded, color: Color(0xFF16A34A), size: 24),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r['reward_type'] ?? r['rewardType'] ?? 'Félicitations',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Color(0xFF166534),
                                                ),
                                              ),
                                              Text(
                                                r['reason']?.toString() ?? '',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF15803D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
