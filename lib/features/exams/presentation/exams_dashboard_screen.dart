import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../ai/presentation/ai_exam_grader_screen.dart';
import '../data/exams_repository.dart';


class ExamsDashboardScreen extends StatefulWidget {
  const ExamsDashboardScreen({super.key});

  @override
  State<ExamsDashboardScreen> createState() => _ExamsDashboardScreenState();
}

class _ExamsDashboardScreenState extends State<ExamsDashboardScreen> {
  final ExamsRepository _repository = locator<ExamsRepository>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _canManageExams = false;
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _filteredExams = [];
  String _periodFilter = 'Tous';
  String _classFilter = 'Tous';
  String _subjectFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      locator<PermissionService>().getCurrentProfile(),
      _repository.getExamsList(),
    ]);
    if (!mounted) return;
    final profile = results[0] as dynamic;
    final exams = results[1] as List<Map<String, dynamic>>;
    setState(() {
      _canManageExams =
          profile.permissions.contains(AppPermissions.examsManage);
      _exams = exams;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _exams.where((exam) {
      final name = (exam['exam_name'] ?? '').toString().toLowerCase();
      final className =
          (exam['school_classes']?['class_name'] ?? '').toString().toLowerCase();
      final subjectName = (exam['school_subjects']?['subject_name'] ?? '')
          .toString()
          .toLowerCase();
      final periodName =
          (exam['academic_periods']?['name'] ?? '').toString().toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          className.contains(query) ||
          subjectName.contains(query);
      final matchesPeriod = _periodFilter == 'Tous' ||
          periodName == _periodFilter.toLowerCase();
      final matchesClass =
          _classFilter == 'Tous' || className == _classFilter.toLowerCase();
      final matchesSubject = _subjectFilter == 'Tous' ||
          subjectName == _subjectFilter.toLowerCase();
      return matchesSearch &&
          matchesPeriod &&
          matchesClass &&
          matchesSubject;
    }).toList();

    setState(() {
      _filteredExams = filtered;
    });
  }

  List<String> get _periods => [
        'Tous',
        ..._exams
            .map((exam) => exam['academic_periods']?['name']?.toString())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
      ];

  List<String> get _classes => [
        'Tous',
        ..._exams
            .map((exam) => exam['school_classes']?['class_name']?.toString())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
      ];

  List<String> get _subjects => [
        'Tous',
        ..._exams
            .map((exam) => exam['school_subjects']?['subject_name']?.toString())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _canManageExams
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push('/exams/form');
                if (!mounted) return;
                if (created == true) {
                  _load();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Liste des examens mise a jour.'),
                    ),
                  );
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Programmer'),
            )
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Examens'),
        actions: [
          IconButton(
            tooltip: 'Correcteur IA Caméra',
            icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiExamGraderScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consultez les examens, filtrez-les et ouvrez la saisie des resultats.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.slate500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildStats(),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => _applyFilters(),
                            decoration: InputDecoration(
                              hintText:
                                  'Rechercher par examen, classe ou matiere',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEBF0F5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEBF0F5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _periods.contains(_periodFilter)
                                ? _periodFilter
                                : _periods.first,
                            items: _periods
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _periodFilter = value ?? 'Tous');
                              _applyFilters();
                            },
                            decoration: InputDecoration(
                              labelText: 'Periode',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEBF0F5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEBF0F5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _classes.contains(_classFilter)
                                      ? _classFilter
                                      : _classes.first,
                                  items: _classes
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _classFilter = value ?? 'Tous');
                                    _applyFilters();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Classe',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEBF0F5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEBF0F5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _subjects.contains(_subjectFilter)
                                      ? _subjectFilter
                                      : _subjects.first,
                                  items: _subjects
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(
                                      () => _subjectFilter = value ?? 'Tous',
                                    );
                                    _applyFilters();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Matiere',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEBF0F5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFEBF0F5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_filteredExams.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Aucun examen trouve',
                          style: AppTextStyles.bodyBold,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildExamCard(_filteredExams[index]),
                          ),
                          childCount: _filteredExams.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildStats() {
    final total = _exams.length;
    final classes = _exams
        .map((exam) => exam['school_classes']?['class_name']?.toString())
        .whereType<String>()
        .toSet()
        .length;
    final subjects = _exams
        .map((exam) => exam['school_subjects']?['subject_name']?.toString())
        .whereType<String>()
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Examens',
            '$total',
            Icons.assignment_rounded,
            const Color(0xFFEEF2FF),
            const Color(0xFF4338CA),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Classes',
            '$classes',
            Icons.class_rounded,
            const Color(0xFFECFDF5),
            const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Matieres',
            '$subjects',
            Icons.menu_book_rounded,
            const Color(0xFFFFF7ED),
            const Color(0xFFEA580C),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: fg),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.heading2),
          Text(title, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final examId = exam['id'] as int?;
    final date = exam['exam_date']?.toString();
    return InkWell(
      onTap: examId == null
          ? null
          : () => context.push('/exams/results', extra: exam),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEBF0F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: Color(0xFF4338CA),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (exam['exam_name'] ?? 'Examen').toString(),
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exam['school_classes']?['class_name'] ?? '-'} • ${exam['school_subjects']?['subject_name'] ?? '-'}',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${exam['academic_periods']?['name'] ?? '-'} • Note max ${exam['max_marks'] ?? 20}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.slate400,
                  ),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final updated =
                          await context.push('/exams/form', extra: exam);
                      if (updated == true) {
                        _load();
                      }
                    } else if (value == 'delete' && examId != null) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Supprimer cet examen'),
                          content: Text(
                            'Voulez-vous supprimer "${exam['exam_name'] ?? 'cet examen'}" ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final result = await _repository.deleteExam(examId);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['success'] == true
                                  ? 'Examen supprime.'
                                  : (result['error']?.toString() ??
                                      'Erreur suppression'),
                            ),
                          ),
                        );
                        if (result['success'] == true) {
                          _load();
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Modifier'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                ),
                Text(
                  date == null || date.isEmpty ? '-' : date.split('T').first,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.slate400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
