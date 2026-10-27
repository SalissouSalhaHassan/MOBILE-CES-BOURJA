import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import '../../pedagogie/data/planification_repository.dart';
import '../../../core/di/injection.dart';

class AiFichePedagogiqueScreen extends StatefulWidget {
  final String? initialClass;
  final String? initialSubject;
  final String? initialLesson;

  const AiFichePedagogiqueScreen({super.key, this.initialClass, this.initialSubject, this.initialLesson});

  @override
  State<AiFichePedagogiqueScreen> createState() => _AiFichePedagogiqueScreenState();
}

class _AiFichePedagogiqueScreenState extends State<AiFichePedagogiqueScreen> {
  final _teacherRepo = locator<TeacherRepository>();
  final _planRepo = locator<PlanificationRepository>();

  final _chapController = TextEditingController();
  final _lessonController = TextEditingController();

  String _selectedClass = '';
  String _selectedSubject = '';
  String _selectedDuration = '55 min';

  bool _isGenerating = false;
  bool _isSavingPlan = false;
  Map<String, dynamic>? _ficheData;

  List<String> _classes = [];
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _chapController.text = 'Géométrie dans l\'Espace';
    _lessonController.text = widget.initialLesson ?? 'Sections planes de pyramides et de cônes';
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
  }

  @override
  void dispose() {
    _chapController.dispose();
    _lessonController.dispose();
    super.dispose();
  }

  Future<void> _generateFiche() async {
    final lesson = _lessonController.text.trim();
    if (lesson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir le titre de la leçon.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final fiche = await _teacherRepo.generateAiFichePedagogique(
        className: _selectedClass,
        subjectName: _selectedSubject,
        chapter: _chapController.text.trim(),
        lessonTitle: lesson,
        durationMinutes: _selectedDuration,
      );

      setState(() => _ficheData = fiche);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fiche pédagogique APC générée avec succès ! ✨'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveAsPlanification() async {
    if (_ficheData == null) return;
    setState(() => _isSavingPlan = true);

    try {
      final competences = (_ficheData?['competencesVisees'] as List?)?.join('\n') ?? '';
      await _planRepo.createPlanification(
        classId: 1,
        subjectId: 1,
        employeeId: 1,
        typePlan: 'Hebdomadaire',
        chapitre: _chapController.text.trim(),
        leconPrevue: _lessonController.text.trim(),
        competenceVisee: competences,
        datePrevue: DateTime.now().toIso8601String().split('T').first,
        statut: 'Planifié',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fiche enregistrée dans votre Planification Pédagogique ! 📁✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Fiche Pédagogique APC (IA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_ficheData != null)
            IconButton(
              icon: _isSavingPlan
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bookmark_add_rounded),
              tooltip: 'Ajouter à la planification',
              onPressed: _isSavingPlan ? null : _saveAsPlanification,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generator configuration
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0D9488), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Conception de Fiche de Leçon',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDec('Classe'),
                          value: _classes.contains(_selectedClass) ? _selectedClass : (_classes.isNotEmpty ? _classes.first : null),
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedClass = v ?? _selectedClass),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDec('Matière'),
                          value: _subjects.contains(_selectedSubject) ? _selectedSubject : (_subjects.isNotEmpty ? _subjects.first : null),
                          items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _selectedSubject = v ?? _selectedSubject),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _chapController,
                    decoration: _inputDec('Chapitre / Module *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lessonController,
                    decoration: _inputDec('Titre de la leçon / Séance *'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateFiche,
                      icon: _isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                      label: Text(
                        _isGenerating ? 'Génération APC en cours...' : 'Générer la Fiche Pédagogique APC',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Generated Fiche Display
            if (_ficheData != null) ...[
              // Objectives and Competencies
              _buildSectionCard(
                title: 'Compétences & Objectifs Visés',
                icon: Icons.psychology_rounded,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: ((_ficheData?['competencesVisees'] as List?) ?? [])
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0D9488), size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(c, style: const TextStyle(fontSize: 13, color: AppColors.slate800))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 14),

              // Phases of the Lesson
              _buildSectionCard(
                title: 'Déroulement de la Séance (Phases APC)',
                icon: Icons.view_timeline_rounded,
                content: Column(
                  children: ((_ficheData?['deroulementPhases'] as List?) ?? []).map((p) {
                    final phase = p['phase'] ?? '';
                    final dur = p['duree'] ?? '';
                    final roleEns = p['roleEnseignant'] ?? '';
                    final roleElv = p['roleEleve'] ?? '';
                    final modalite = p['modalite'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(phase, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(dur, style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Rôle de l\'enseignant : $roleEns', style: const TextStyle(fontSize: 12, height: 1.3)),
                          const SizedBox(height: 4),
                          Text('Rôle de l\'élève : $roleElv', style: const TextStyle(fontSize: 12, height: 1.3, color: AppColors.slate600)),
                          const SizedBox(height: 4),
                          Text('Modalité : $modalite', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget content}) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(icon, color: const Color(0xFF0D9488), size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );
}
