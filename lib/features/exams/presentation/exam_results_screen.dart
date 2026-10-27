import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/exams_repository.dart';

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({
    super.key,
    required this.exam,
  });

  final Map<String, dynamic> exam;

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  final ExamsRepository _repository = locator<ExamsRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageExams = false;
  bool _isLocked = false;
  String? _lockReason;
  List<Map<String, dynamic>> _students = [];
  final Map<int, TextEditingController> _marksControllers = {};
  final Map<int, TextEditingController> _remarkControllers = {};

  int get _examId => widget.exam['id'] as int;
  double get _maxMarks =>
      (widget.exam['max_marks'] as num?)?.toDouble() ?? 20.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _marksControllers.values) {
      controller.dispose();
    }
    for (final controller in _remarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final classId = widget.exam['class_id'] as int;
    final futures = await Future.wait([
      locator<PermissionService>().getCurrentProfile(),
      _repository.getStudentsForExam(classId: classId),
      _repository.getExamResults(_examId),
    ]);

    final profile = futures[0] as dynamic;
    final students = futures[1] as List<Map<String, dynamic>>;
    final results = futures[2] as List<Map<String, dynamic>>;

    for (final controller in _marksControllers.values) {
      controller.dispose();
    }
    for (final controller in _remarkControllers.values) {
      controller.dispose();
    }
    _marksControllers.clear();
    _remarkControllers.clear();

    final resultsByStudent = {
      for (final result in results) result['student_id'] as int: result,
    };

    for (final student in students) {
      final studentId = student['id'] as int;
      final existing = resultsByStudent[studentId];
      _marksControllers[studentId] = TextEditingController(
        text: existing?['marks_obtained']?.toString() ?? '',
      );
      _remarkControllers[studentId] = TextEditingController(
        text: existing?['remarks']?.toString() ?? '',
      );
    }

    final isLockedExam = widget.exam['is_locked'] == true;
    final lockReasonExam = widget.exam['lock_reason']?.toString();

    if (!mounted) return;
    setState(() {
      _canManageExams =
          profile.permissions.contains(AppPermissions.examsManage);
      _students = students;
      _isLocked = isLockedExam;
      _lockReason = lockReasonExam;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lockReason ?? 'Période ou session clôturée. Enregistrement interdit.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    final payload = <Map<String, dynamic>>[];

    for (final student in _students) {
      final studentId = student['id'] as int;
      final marksText = _marksControllers[studentId]?.text.trim() ?? '';
      if (marksText.isEmpty) continue;

      final marks = double.tryParse(marksText.replaceAll(',', '.'));
      if (marks == null) continue;

      payload.add({
        'student_id': studentId,
        'marks_obtained': marks,
        'remarks': _remarkControllers[studentId]?.text.trim() ?? '',
      });
    }

    final result = await _repository.saveBatchExamResults(
      examId: _examId,
      results: payload,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Resultats enregistres.'
              : (result['error']?.toString() ?? 'Erreur enregistrement'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Resultats examen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      _buildHeroHeader(),
                      if (_isLocked) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.shade600),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock, color: Colors.amber.shade900, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _lockReason ?? 'Examen clôturé ou période verrouillée (Mode lecture seule).',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildHeader(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildStudentResultCard(student),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSaving || !_canManageExams || _isLocked ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving ? 'Enregistrement...' : 'Enregistrer les notes',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withAlpha(60),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Saisie des resultats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            (widget.exam['exam_name'] ?? 'Examen').toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.exam['school_classes']?['class_name'] ?? '-'} • ${widget.exam['school_subjects']?['subject_name'] ?? '-'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final studentsWithMarks = _students.where((student) {
      final studentId = student['id'] as int;
      return (_marksControllers[studentId]?.text.trim().isNotEmpty ?? false);
    }).length;
    final enteredMarks = _students
        .map((student) {
          final studentId = student['id'] as int;
          return double.tryParse(
            (_marksControllers[studentId]?.text.trim() ?? '')
                .replaceAll(',', '.'),
          );
        })
        .whereType<double>()
        .toList();
    final passedCount =
        enteredMarks.where((mark) => mark >= (_maxMarks / 2)).length;
    final average = enteredMarks.isEmpty
        ? 0.0
        : enteredMarks.reduce((a, b) => a + b) / enteredMarks.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEBF0F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apercu global', style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Bareme', _maxMarks.toStringAsFixed(0)),
              const SizedBox(width: 12),
              _metric('Eleves', '${_students.length}'),
              const SizedBox(width: 12),
              _metric('Saisis', '$studentsWithMarks'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Moyenne', average.toStringAsFixed(1)),
              const SizedBox(width: 12),
              _metric('Admis', '$passedCount'),
              const SizedBox(width: 12),
              _metric('A renforcer', '${enteredMarks.length - passedCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextStyles.heading3),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentResultCard(Map<String, dynamic> student) {
    final studentId = student['id'] as int;
    final marksController = _marksControllers[studentId]!;
    final remarkController = _remarkControllers[studentId]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (student['nom_etudiant'] ?? 'Etudiant').toString(),
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mat: ${student['num_admission'] ?? '-'}',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _resultChip(marksController.text),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: marksController,
                  enabled: _canManageExams && !_isLocked,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Note / ${_maxMarks.toStringAsFixed(0)}',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Color(0xFFEBF0F5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Color(0xFFEBF0F5)),
                    ),
                  ),
                  onChanged: (value) {
                    final marks =
                        double.tryParse(value.trim().replaceAll(',', '.'));
                    if (marks != null && marks > _maxMarks) {
                      marksController.text = _maxMarks.toStringAsFixed(0);
                      marksController.selection = TextSelection.fromPosition(
                        TextPosition(offset: marksController.text.length),
                      );
                    }
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: remarkController,
            enabled: _canManageExams && !_isLocked,
            decoration: InputDecoration(
              labelText: 'Appreciation / Observation',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultChip(String marksText) {
    final marks = double.tryParse(marksText.trim().replaceAll(',', '.'));
    if (marks == null) {
      return const SizedBox.shrink();
    }

    final passed = marks >= (_maxMarks / 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: passed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        passed ? 'ADMIS' : 'A RENFORCER',
        style: TextStyle(
          color: passed ? const Color(0xFF059669) : const Color(0xFFDC2626),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
