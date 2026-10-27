import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/exams_repository.dart';

class ExamFormScreen extends StatefulWidget {
  const ExamFormScreen({
    super.key,
    this.initialData,
  });

  final Map<String, dynamic>? initialData;

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  final ExamsRepository _repository = locator<ExamsRepository>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dateController;
  late final TextEditingController _maxMarksController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageExams = false;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _periods = [];
  int? _classId;
  int? _subjectId;
  int? _periodId;

  bool get _isEdit => widget.initialData?['id'] != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _nameController =
        TextEditingController(text: data['exam_name']?.toString() ?? '');
    _dateController = TextEditingController(
      text: data['exam_date']?.toString().split('T').first ?? '',
    );
    _maxMarksController = TextEditingController(
      text: data['max_marks']?.toString() ?? '20',
    );
    _classId = data['class_id'] as int?;
    _subjectId = data['subject_id'] as int?;
    _periodId = data['period_id'] as int?;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _maxMarksController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    final options = await _repository.getExamFormOptions();
    if (!mounted) return;
    setState(() {
      _canManageExams =
          profile.permissions.contains(AppPermissions.examsManage);
      _classes = options['classes'] ?? [];
      _subjects = options['subjects'] ?? [];
      _periods = options['periods'] ?? [];
      _classId ??= _classes.isNotEmpty ? _classes.first['id'] as int : null;
      _subjectId ??= _subjects.isNotEmpty ? _subjects.first['id'] as int : null;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _classId == null || _subjectId == null) {
      return;
    }

    setState(() => _isSaving = true);
    final payload = {
      'exam_name': _nameController.text.trim(),
      'class_id': _classId,
      'subject_id': _subjectId,
      'period_id': _periodId,
      'exam_date': _dateController.text.trim().isEmpty
          ? null
          : _dateController.text.trim(),
      'max_marks': double.tryParse(
            _maxMarksController.text.trim().replaceAll(',', '.'),
          ) ??
          20,
    };
    final result = _isEdit
        ? await _repository.updateExam(
            examId: widget.initialData!['id'] as int,
            payload: payload,
          )
        : await _repository.createExam(payload: payload);

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Erreur creation examen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: Text(_isEdit ? 'Modifier examen' : 'Nouvel examen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_canManageExams
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Vous n avez pas la permission de gerer les examens.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFEBF0F5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Programmation', style: AppTextStyles.heading3),
                        const SizedBox(height: 14),
                        _textField(_nameController, 'Nom de l\'examen'),
                        const SizedBox(height: 12),
                        _dropdown(
                          label: 'Classe',
                          value: _classId,
                          items: _classes,
                          labelKey: 'class_name',
                          onChanged: (value) => setState(() => _classId = value),
                        ),
                        const SizedBox(height: 12),
                        _dropdown(
                          label: 'Matiere',
                          value: _subjectId,
                          items: _subjects,
                          labelKey: 'subject_name',
                          onChanged: (value) => setState(() => _subjectId = value),
                        ),
                        const SizedBox(height: 12),
                        _dropdown(
                          label: 'Periode',
                          value: _periodId,
                          items: _periods,
                          labelKey: 'name',
                          required: false,
                          onChanged: (value) => setState(() => _periodId = value),
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          _dateController,
                          'Date de l\'examen (YYYY-MM-DD)',
                          required: false,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          _maxMarksController,
                          'Note maximale',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _isSaving || !_canManageExams ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isSaving
                          ? (_isEdit ? 'Mise a jour...' : 'Creation...')
                          : (_isEdit ? 'Mettre a jour' : 'Programmer'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: required
          ? (value) => (value == null || value.trim().isEmpty) ? 'Champ requis' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
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
    );
  }

  Widget _dropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required ValueChanged<int?> onChanged,
    bool required = true,
  }) {
    final validIds = items.map((item) => item['id'] as int).toList();
    return DropdownButtonFormField<int>(
      initialValue: validIds.contains(value) ? value : null,
      validator: required ? (value) => value == null ? 'Champ requis' : null : null,
      items: [
        if (!required)
          const DropdownMenuItem<int>(
            value: null,
            child: Text('Aucune'),
          ),
        ...items.map(
          (item) => DropdownMenuItem<int>(
            value: item['id'] as int,
            child: Text((item[labelKey] ?? '-').toString()),
          ),
        ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
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
    );
  }
}
