import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import '../../../core/di/injection.dart';

class AiExamGeneratorScreen extends StatefulWidget {
  final String? initialClass;
  final String? initialSubject;

  const AiExamGeneratorScreen({super.key, this.initialClass, this.initialSubject});

  @override
  State<AiExamGeneratorScreen> createState() => _AiExamGeneratorScreenState();
}

class _AiExamGeneratorScreenState extends State<AiExamGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final _teacherRepo = locator<TeacherRepository>();
  final _topicController = TextEditingController();
  late TabController _tabController;

  String _selectedClass = '';
  String _selectedSubject = '';
  String _selectedDifficulty = 'Intermédiaire';
  String _selectedDuration = '45 min';
  int _questionCount = 4;

  bool _isGenerating = false;
  Map<String, dynamic>? _generatedExam;

  List<String> _classes = [];
  List<String> _subjects = [];

  final List<String> _difficulties = ['Facile', 'Intermédiaire', 'Examen Officiel / BEPC / BAC', 'Avancé'];
  final List<String> _durations = ['30 min', '45 min', '1 heure', '2 heures'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _topicController.text = 'Théorème de Pythagore & Trigonométrie';
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
    _topicController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateExam() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez spécifier le sujet ou thème de l\'épreuve.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final exam = await _teacherRepo.generateAiExam(
        className: _selectedClass,
        subjectName: _selectedSubject,
        topic: topic,
        difficulty: _selectedDifficulty,
        durationMinutes: _selectedDuration,
        questionCount: _questionCount,
      );

      setState(() {
        _generatedExam = exam;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Épreuve et corrigé générés avec succès par l\'IA ! ✨'),
            backgroundColor: Color(0xFF10B981),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Générateur d\'Examens IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_generatedExam != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Exporter l\'épreuve',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📄 Exportation PDF prête pour impression !'),
                    backgroundColor: Color(0xFF6D28D9),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generator Configuration Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D28D9), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Paramètres de l\'Épreuve',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Class & Subject Selectors
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDec('Classe'),
                          initialValue: _classes.contains(_selectedClass) ? _selectedClass : (_classes.isNotEmpty ? _classes.first : null),
                          items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedClass = v ?? _selectedClass),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDec('Matière'),
                          initialValue: _subjects.contains(_selectedSubject) ? _selectedSubject : (_subjects.isNotEmpty ? _subjects.first : null),
                          items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _selectedSubject = v ?? _selectedSubject),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Topic input
                  TextFormField(
                    controller: _topicController,
                    decoration: _inputDec('Chapitre ou Thème de l\'épreuve *').copyWith(
                      prefixIcon: const Icon(Icons.menu_book_rounded, color: Color(0xFF6D28D9), size: 20),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Difficulty and Duration
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDec('Niveau'),
                          initialValue: _selectedDifficulty,
                          items: _difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _selectedDifficulty = v ?? _selectedDifficulty),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDec('Durée'),
                          initialValue: _selectedDuration,
                          items: _durations.map((dur) => DropdownMenuItem(value: dur, child: Text(dur))).toList(),
                          onChanged: (v) => setState(() => _selectedDuration = v ?? _selectedDuration),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateExam,
                      icon: _isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                      label: Text(
                        _isGenerating ? 'Génération IA en cours...' : 'Générer l\'Épreuve & Corrigé',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Generated Result Display
            if (_generatedExam != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF6D28D9),
                      unselectedLabelColor: AppColors.slate500,
                      indicatorColor: const Color(0xFF6D28D9),
                      tabs: const [
                        Tab(icon: Icon(Icons.description_rounded), text: 'Sujet d\'Examen'),
                        Tab(icon: Icon(Icons.fact_check_rounded), text: 'Corrigé & Barème'),
                      ],
                    ),
                    SizedBox(
                      height: 520,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildExamPaperTab(),
                          _buildModelAnswerTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamPaperTab() {
    final questions = (_generatedExam?['questions'] as List?) ?? [];
    final header = _generatedExam?['header'] as Map<String, dynamic>?;
    final instructions = (_generatedExam?['instructions'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Exam official Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            children: [
              Text(
                header?['school'] ?? 'ÉTABLISSEMENT SCOLAIRE',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Épreuve de ${header?['discipline']} • Classe: ${header?['classe']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6D28D9)),
              ),
              const SizedBox(height: 2),
              Text('Durée : ${header?['duree']} • Barème : /${header?['totalPoints']} pts', style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Instructions
        if (instructions.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: instructions.map((ins) => Text('• $ins', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)))).toList(),
            ),
          ),

        const SizedBox(height: 14),

        // Questions
        ...questions.map((q) {
          final num = q['number'] ?? 1;
          final title = q['title'] ?? 'Exercice';
          final pts = q['points'] ?? 4;
          final prompt = q['prompt'] ?? '';
          final displayTitle = title.toString().startsWith('Exercice') || title.toString().startsWith('Partie')
              ? title.toString()
              : 'Exercice $num : $title';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('($pts pts)', style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(prompt, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.slate800)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildModelAnswerTab() {
    final questions = (_generatedExam?['questions'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Corrigé officiel réservé à l\'enseignant pour la notation.',
                  style: TextStyle(color: Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...questions.map((q) {
          final title = q['title'] ?? 'Exercice';
          final answer = q['modelAnswer'] ?? '';
          final rubric = q['rubric'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF059669))),
                const SizedBox(height: 6),
                const Text('Solution type :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.slate600)),
                const SizedBox(height: 4),
                Text(answer, style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.slate800)),
                if (rubric.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Barème : $rubric', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );
}
