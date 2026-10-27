import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import '../../../core/di/injection.dart';

class AiRemediationScreen extends StatefulWidget {
  final String? initialClass;
  final String? initialSubject;

  const AiRemediationScreen({super.key, this.initialClass, this.initialSubject});

  @override
  State<AiRemediationScreen> createState() => _AiRemediationScreenState();
}

class _AiRemediationScreenState extends State<AiRemediationScreen> {
  final _teacherRepo = locator<TeacherRepository>();
  final _topicController = TextEditingController();

  String _selectedClass = '';
  String _selectedSubject = '';

  bool _isAnalyzing = false;
  Map<String, dynamic>? _diagnosticData;

  List<String> _classes = [];
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _topicController.text = 'Théorème de Thalès & Équations';
    _loadTeacherAssignments();
  }

  Future<void> _loadTeacherAssignments() async {
    final list = await _teacherRepo.getTeacherClassesAndSubjects();
    setState(() {
      final classNames = <String>{};
      final subjectNames = <String>{};

      for (final row in list) {
        final cName = row['school_classes']?['class_name'] ?? row['class_name'];
        final sName = row['school_subjects']?['subject_name'] ?? row['subject_name'];
        if (cName != null && cName.toString().isNotEmpty) classNames.add(cName.toString());
        if (sName != null && sName.toString().isNotEmpty) subjectNames.add(sName.toString());
      }

      _classes = classNames.isNotEmpty ? classNames.toList() : ['6ème A', '5ème A', '4ème A', '3ème A', '2nde C', '1ère D', 'Tle D'];
      _subjects = subjectNames.isNotEmpty ? subjectNames.toList() : ['Mathématiques', 'Français', 'Physique-Chimie', 'SVT', 'Histoire-Géo', 'Anglais', 'Philosophie'];

      if (widget.initialClass != null && _classes.contains(widget.initialClass)) {
        _selectedClass = widget.initialClass!;
      } else {
        _selectedClass = _classes.first;
      }

      if (widget.initialSubject != null && _subjects.contains(widget.initialSubject)) {
        _selectedSubject = widget.initialSubject!;
      } else {
        _selectedSubject = _subjects.first;
      }
    });

    _runDiagnostic();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostic() async {
    if (_selectedClass.isEmpty) return;
    setState(() => _isAnalyzing = true);
    try {
      final diag = await _teacherRepo.generateAiRemediation(
        className: _selectedClass,
        subjectName: _selectedSubject,
        topic: _topicController.text.trim(),
      );

      setState(() => _diagnosticData = diag);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final concepts = (_diagnosticData?['conceptBreakdown'] as List?) ?? [];
    final atRisk = (_diagnosticData?['atRiskStudents'] as List?) ?? [];
    final remediationPlan = _diagnosticData?['remediationPlan'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Diagnostic & Remédiation IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Réanalyser',
            onPressed: _isAnalyzing ? null : _runDiagnostic,
          ),
        ],
      ),
      body: _isAnalyzing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  SizedBox(height: 16),
                  Text('Analyse des notes et détection des lacunes par l\'IA...', style: TextStyle(color: AppColors.slate600, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Class Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DIAGNOSTIC : $_selectedClass',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _topicController.text,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Taux de maîtrise global : ${_diagnosticData?['overallMasteryRate'] ?? '64%'}',
                              style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Concept Breakdown Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pie_chart_rounded, color: Color(0xFF4F46E5), size: 20),
                          SizedBox(width: 8),
                          Text('Analyse des Compétences de la Classe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...concepts.map((c) {
                        final concept = c['concept'] ?? '';
                        final mastery = (c['mastery'] as num?)?.toInt() ?? 50;
                        final status = c['status'] ?? '';
                        final isGood = mastery >= 75;
                        final isFragile = mastery >= 50 && mastery < 75;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(concept, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                  Text(
                                    '$mastery%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isGood ? const Color(0xFF10B981) : (isFragile ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: mastery / 100,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isGood ? const Color(0xFF10B981) : (isFragile ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(status, style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // At-risk students in this lesson
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                          SizedBox(width: 8),
                          Text('Élèves Nécessitant un Renforcement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...atRisk.map((s) {
                        final name = s['name'] ?? '';
                        final avg = s['currentAverage'] ?? '';
                        final diff = s['specificDifficulty'] ?? '';
                        final action = s['recommendedAction'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(avg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF991B1B))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Obstacle : $diff', style: const TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                              const SizedBox(height: 4),
                              Text('Action suggérée : $action', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF047857))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Remediation Strategy
                if (remediationPlan != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                            SizedBox(width: 8),
                            Text('Plan d\'Action Pédagogique Recommandé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(remediationPlan['strategy'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.slate800)),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
