import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';
import 'lms_lesson_player_screen.dart';
import 'lms_quiz_screen.dart';

class LmsCoursesScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;

  const LmsCoursesScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  State<LmsCoursesScreen> createState() => _LmsCoursesScreenState();
}

class _LmsCoursesScreenState extends State<LmsCoursesScreen> {
  final LmsRepository _repo = LmsRepository();

  bool _isLoading = true;
  List<dynamic> _courses = [];
  Map<String, dynamic>? _selectedCourseDetails;
  int? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    final res = await _repo.getCourses(studentId: widget.studentId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _courses = (res?['data'] as List<dynamic>?) ?? [];
        if (_courses.isNotEmpty && _selectedCourseId == null) {
          _selectCourse(_courses.first['id']);
        }
      });
    }
  }

  Future<void> _selectCourse(int courseId) async {
    setState(() {
      _selectedCourseId = courseId;
    });
    final res = await _repo.getCourses(
      studentId: widget.studentId,
      courseId: courseId,
    );
    if (mounted && res?['data'] != null) {
      setState(() {
        _selectedCourseDetails = Map<String, dynamic>.from(res!['data']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Formation & E-Learning',
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
          : _courses.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Course Selector Horizontal Carousel
                    Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.white,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _courses.length,
                        itemBuilder: (context, index) {
                          final c = _courses[index];
                          final isSelected = c['id'] == _selectedCourseId;
                          final subjectName = c['subject']?['subjectName'] ?? 'Général';

                          return GestureDetector(
                            onTap: () => _selectCourse(c['id']),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.black12,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  c['title'] ?? subjectName,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Active Course Content
                    Expanded(
                      child: _selectedCourseDetails == null
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : _buildCourseDetailsView(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Aucun cours en ligne disponible',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Les modules d\'apprentissage en ligne seront publiés prochainement par vos professeurs.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDetailsView() {
    final title = _selectedCourseDetails!['title']?.toString() ?? 'Cours';
    final desc = _selectedCourseDetails!['description']?.toString() ?? '';
    final percentage = _selectedCourseDetails!['completionPercentage'] ?? 0;
    final totalLessons = _selectedCourseDetails!['totalLessons'] ?? 0;
    final completedLessons = _selectedCourseDetails!['completedLessons'] ?? 0;
    final modules = (_selectedCourseDetails!['modules'] as List<dynamic>?) ?? [];
    final quizzes = (_selectedCourseDetails!['quizzes'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '$completedLessons sur $totalLessons leçons terminées',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Circular percentage
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                      strokeWidth: 5,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Modules & Lessons List
        ...modules.map((mod) {
          final modTitle = mod['title']?.toString() ?? 'Module';
          final lessons = (mod['lessons'] as List<dynamic>?) ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  modTitle,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${lessons.length} leçons',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                children: lessons.map((l) {
                  final isDone = l['isCompleted'] == true;
                  final type = l['contentType']?.toString() ?? 'Text';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isDone
                          ? AppColors.success.withOpacity(0.15)
                          : const Color(0xFFF1F5F9),
                      child: Icon(
                        isDone
                            ? Icons.check
                            : type == 'Video'
                                ? Icons.play_arrow_rounded
                                : Icons.article_rounded,
                        color: isDone ? AppColors.success : AppColors.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      l['title']?.toString() ?? 'Leçon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${l['duration'] ?? 15} min · $type',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black26),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LmsLessonPlayerScreen(
                            lesson: Map<String, dynamic>.from(l),
                            studentId: widget.studentId,
                            courseId: _selectedCourseId,
                          ),
                        ),
                      );
                      if (_selectedCourseId != null) {
                        _selectCourse(_selectedCourseId!);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          );
        }),

        // Course Quizzes & Assessments
        if (quizzes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Évaluations & Quiz du Cours',
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...quizzes.map((q) {
            final qTitle = q['title']?.toString() ?? 'Quiz';
            final duration = q['durationMin'] ?? 20;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.quiz_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          qTitle,
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Durée : $duration minutes · Obtention du Certificat',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LmsQuizScreen(
                            quiz: Map<String, dynamic>.from(q),
                            studentId: widget.studentId,
                            studentName: widget.studentName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Passer'),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
