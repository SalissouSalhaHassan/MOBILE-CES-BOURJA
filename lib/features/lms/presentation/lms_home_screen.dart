import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';
import 'lms_lesson_player_screen.dart';
import 'lms_quiz_screen.dart';
import 'widgets/lms_certificate_pdf_generator.dart';

class LmsHomeScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;

  const LmsHomeScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  State<LmsHomeScreen> createState() => _LmsHomeScreenState();
}

class _LmsHomeScreenState extends State<LmsHomeScreen> with SingleTickerProviderStateMixin {
  final LmsRepository _repo = LmsRepository();
  late TabController _tabController;

  bool _isLoading = true;
  String _searchQuery = '';
  String _assignmentFilter = 'all'; // 'all', 'pending', 'submitted', 'graded'

  List<dynamic> _courses = [];
  List<dynamic> _virtualClasses = [];
  List<dynamic> _assignments = [];
  List<dynamic> _certificates = [];
  List<dynamic> _discussions = [];

  int? _selectedCourseId;
  Map<String, dynamic>? _selectedCourseDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getCourses(studentId: widget.studentId),
        _repo.getVirtualClasses(studentId: widget.studentId),
        _repo.getAssignments(studentId: widget.studentId),
        _repo.getCertificates(studentId: widget.studentId),
        _repo.getDiscussions(),
      ]);

      if (mounted) {
        final coursesRes = results[0] as Map<String, dynamic>?;
        final virtualClassesRes = results[1] as List<dynamic>;
        final assignmentsRes = results[2] as List<dynamic>;
        final certificatesRes = results[3] as List<dynamic>;
        final discussionsRes = results[4] as List<dynamic>;

        setState(() {
          _isLoading = false;
          _courses = (coursesRes?['data'] as List<dynamic>?) ?? [];
          _virtualClasses = virtualClassesRes;
          _assignments = assignmentsRes;
          _certificates = certificatesRes;
          _discussions = discussionsRes;

          if (_courses.isNotEmpty && _selectedCourseId == null) {
            _selectCourse(_courses.first['id']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectCourse(int courseId) async {
    setState(() => _selectedCourseId = courseId);
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

  Future<void> _launchMeetingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien de la classe virtuelle')),
        );
      }
    }
  }

  void _showSubmitAssignmentDialog(Map<String, dynamic> assignment) {
    final sub = assignment['submission'];
    final textController = TextEditingController(text: sub?['comment'] ?? '');
    final fileController = TextEditingController(text: sub?['fileReponsePath'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.upload_file_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remettre le devoir',
                style: AppTextStyles.titleMedium,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment['title'] ?? 'Devoir',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre réponse écrite :',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Rédigez ici votre réponse ou explication...',
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Lien vers votre document / travail (Optionnel) :',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: fileController,
                decoration: InputDecoration(
                  hintText: 'https://... ou chemin du fichier',
                  prefixIcon: const Icon(Icons.link, color: AppColors.primary, size: 18),
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final text = textController.text.trim();
              final link = fileController.text.trim();
              if (text.isEmpty && link.isEmpty) return;
              Navigator.pop(ctx);
              final success = await _repo.submitAssignment(
                assignmentId: assignment['id'],
                studentId: widget.studentId,
                textResponse: text,
                fileReponsePath: link.isNotEmpty ? link : null,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '✅ Devoir remis avec succès !' : 'Erreur lors de la remise'),
                    backgroundColor: success ? AppColors.success : AppColors.danger,
                  ),
                );
                if (success) _loadAllData();
              }
            },
            child: const Text('Confirmer l\'envoi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewDiscussionDialog() {
    final messageController = TextEditingController();
    int? selectedCourse = _courses.isNotEmpty ? _courses.first['id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.forum_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Nouvelle Question', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_courses.isNotEmpty) ...[
                const Text('Choisir le cours :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: selectedCourse,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.slate100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _courses.map<DropdownMenuItem<int>>((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(
                        c['title'] ?? 'Cours',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedCourse = val),
                ),
                const SizedBox(height: 14),
              ],
              const Text('Votre question ou remarque :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Posez clairement votre question...',
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final msg = messageController.text.trim();
                if (msg.isEmpty) return;
                Navigator.pop(ctx);
                final success = await _repo.postDiscussion(
                  message: msg,
                  courseId: selectedCourse,
                  studentId: widget.studentId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '✅ Question publiée sur le forum !' : 'Erreur lors de la publication'),
                      backgroundColor: success ? AppColors.success : AppColors.danger,
                    ),
                  );
                  if (success) _loadAllData();
                }
              },
              child: const Text('Publier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeacherGradingSheet(Map<String, dynamic> assignment) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeacherGradingModal(
        assignment: assignment,
        repo: _repo,
        onGraded: () => _loadAllData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'E-Learning & LMS',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
            ),
            if (widget.studentName != null)
              Text(
                widget.studentName!,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadAllData,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.slate500,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              text: 'Cours (${_courses.length})',
            ),
            Tab(
              icon: const Icon(Icons.videocam_rounded, size: 18),
              text: 'Directs (${_virtualClasses.length})',
            ),
            Tab(
              icon: const Icon(Icons.assignment_rounded, size: 18),
              text: 'Devoirs (${_assignments.length})',
            ),
            Tab(
              icon: const Icon(Icons.quiz_rounded, size: 18),
              text: 'Quiz',
            ),
            Tab(
              icon: const Icon(Icons.forum_rounded, size: 18),
              text: 'Forum (${_discussions.length})',
            ),
            Tab(
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              text: 'Certificats (${_certificates.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCoursesTab(),
                _buildVirtualClassesTab(),
                _buildAssignmentsTab(),
                _buildQuizzesTab(),
                _buildForumTab(),
                _buildCertificatesTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 4
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Poser une question'),
              onPressed: _showNewDiscussionDialog,
            )
          : null,
    );
  }

  // -------------------- TAB 1: COURS --------------------
  Widget _buildCoursesTab() {
    if (_courses.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.menu_book_rounded,
        title: 'Aucun cours disponible',
        subtitle: 'Les cours en ligne et modules de formation seront ajoutés prochainement.',
      );
    }

    final filtered = _courses.filterByQuery(_searchQuery);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Rechercher un cours, une matière...',
              prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black12),
              ),
            ),
          ),
        ),

        // Courses List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final course = filtered[index];
              final isSelected = course['id'] == _selectedCourseId;
              final modulesCount = (course['modules'] as List?)?.length ?? 0;
              final subjectName = course['subject']?['subjectName'] ?? 'Général';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.black12,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  key: PageStorageKey('course_${course['id']}'),
                  initiallyExpanded: isSelected,
                  onExpansionChanged: (expanded) {
                    if (expanded) _selectCourse(course['id']);
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 24),
                  ),
                  title: Text(
                    course['title'] ?? 'Cours',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subjectName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$modulesCount modules',
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                    ],
                  ),
                  children: [
                    if (_selectedCourseDetails != null && _selectedCourseDetails!['id'] == course['id'])
                      _buildCourseModulesContent(_selectedCourseDetails!)
                    else
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCourseModulesContent(Map<String, dynamic> details) {
    final modules = (details['modules'] as List<dynamic>?) ?? [];
    final completionPercentage = details['completionPercentage'] ?? 0;
    final totalLessons = details['totalLessons'] ?? 0;
    final completedLessons = details['completedLessons'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: totalLessons > 0 ? completedLessons / totalLessons : 0,
                    minHeight: 8,
                    backgroundColor: AppColors.slate100,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedLessons/$totalLessons ($completionPercentage%)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.slate600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Modules list
          ...modules.map((mod) {
            final modTitle = mod['title'] ?? 'Module';
            final lessons = (mod['lessons'] as List<dynamic>?) ?? [];

            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  modTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${lessons.length} leçons',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
                children: lessons.map((l) {
                  final isDone = l['isCompleted'] == true;
                  final type = l['contentType']?.toString() ?? 'Text';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isDone ? Icons.check_circle : (type == 'Video' ? Icons.play_circle_fill : Icons.article),
                      color: isDone ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      l['title'] ?? 'Leçon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                        color: isDone ? AppColors.slate800 : AppColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LmsLessonPlayerScreen(
                            lesson: l,
                            studentId: widget.studentId,
                            courseId: details['id'],
                          ),
                        ),
                      );
                      _selectCourse(_selectedCourseId!);
                    },
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------- TAB 2: DIRECTS & LIVES --------------------
  Widget _buildVirtualClassesTab() {
    if (_virtualClasses.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.videocam_off_rounded,
        title: 'Aucun direct en cours ou programmé',
        subtitle: 'Les liens des classes virtuelles (Jitsi Meet, Teams, Google Meet) apparaîtront ici.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _virtualClasses.length,
      itemBuilder: (context, index) {
        final v = _virtualClasses[index];
        final isUpcoming = v['status'] == 'À venir';
        final hasAttended = v['hasAttended'] == true;
        final dateStr = v['sessionDate'] != null
            ? DateTime.tryParse(v['sessionDate'])?.toLocal().toString().split('.').first ?? ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUpcoming ? AppColors.primary.withOpacity(0.3) : Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                      color: isUpcoming ? AppColors.success.withOpacity(0.12) : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUpcoming)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                        Text(
                          v['status'] ?? 'Statut',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUpcoming ? AppColors.success : AppColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      v['platform'] ?? 'En direct',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                v['title'] ?? 'Séance en direct',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Matière : ${v['subjectName']} | Enseignant : ${v['teacherName']}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate600),
              ),
              const SizedBox(height: 4),
              Text(
                '📅 $dateStr (${v['duration'] ?? 45} min)',
                style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUpcoming ? AppColors.primary : AppColors.slate700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.launch_rounded, size: 16, color: Colors.white),
                      label: Text(
                        isUpcoming ? 'Rejoindre la séance' : 'Ouvrir l\'enregistrement',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        final url = v['meetingUrl'] ?? v['recordingUrl'] ?? '';
                        if (url.isNotEmpty) _launchMeetingUrl(url);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: hasAttended ? AppColors.success : AppColors.slate300,
                      ),
                    ),
                    icon: Icon(
                      hasAttended ? Icons.check_circle : Icons.how_to_reg,
                      size: 16,
                      color: hasAttended ? AppColors.success : AppColors.slate700,
                    ),
                    label: Text(
                      hasAttended ? 'Présent' : 'Valider',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasAttended ? AppColors.success : AppColors.slate700,
                      ),
                    ),
                    onPressed: hasAttended
                        ? null
                        : () async {
                            final success = await _repo.markVirtualClassAttendance(
                              virtualClassId: v['id'],
                              studentId: widget.studentId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? '✅ Présence confirmée !' : 'Erreur enregistrement'),
                                  backgroundColor: success ? AppColors.success : AppColors.danger,
                                ),
                              );
                              if (success) _loadAllData();
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- TAB 3: DEVOIRS --------------------
  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Aucun devoir pour le moment',
        subtitle: 'Les exercices et travaux maison de vos enseignants seront répertoriés ici.',
      );
    }

    final filtered = _assignments.where((a) {
      final sub = a['submission'];
      if (_assignmentFilter == 'pending') return sub == null;
      if (_assignmentFilter == 'submitted') return sub != null && sub['isGraded'] != true;
      if (_assignmentFilter == 'graded') return sub != null && sub['isGraded'] == true;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips Bar
        Container(
          height: 48,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('Tous (${_assignments.length})', 'all'),
              _buildFilterChip('À rendre', 'pending'),
              _buildFilterChip('Soumis', 'submitted'),
              _buildFilterChip('Notés', 'graded'),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final a = filtered[index];
              final sub = a['submission'];
              final isGraded = sub?['isGraded'] == true;
              final hasSubmitted = sub != null;
              final dueDateStr = a['dueDate'] != null
                  ? DateTime.tryParse(a['dueDate'])?.toLocal().toString().split(' ').first ?? ''
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            a['subjectName'] ?? 'Matière',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isGraded
                                ? AppColors.success.withOpacity(0.12)
                                : hasSubmitted
                                    ? AppColors.info.withOpacity(0.12)
                                    : AppColors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isGraded
                                ? 'Note : ${sub['score']}/${a['maxScore']}'
                                : hasSubmitted
                                    ? '⏳ En attente de correction'
                                    : 'À rendre',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isGraded
                                  ? AppColors.success
                                  : hasSubmitted
                                      ? AppColors.info
                                      : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      a['title'] ?? 'Devoir',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    if (a['description'] != null && a['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        a['description'],
                        style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(
                          'Date limite : $dueDateStr',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          'Barème : /${a['maxScore'] ?? 20}',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (isGraded && sub['comment'] != null && sub['comment'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.feedback_outlined, size: 16, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Remarque de l\'enseignant : ${sub['comment']}',
                                style: const TextStyle(fontSize: 11, color: AppColors.slate800, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Actions: Student Submit & Teacher Grading button
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasSubmitted ? AppColors.slate800 : AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(hasSubmitted ? Icons.edit_note : Icons.file_upload_outlined, size: 16, color: Colors.white),
                            label: Text(
                              hasSubmitted ? 'Modifier ma réponse' : 'Remettre mon devoir',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            onPressed: () => _showSubmitAssignmentDialog(a),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.slate100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.rate_review_rounded, color: AppColors.primary, size: 18),
                          tooltip: 'Copies reçues & Notation',
                          onPressed: () => _showTeacherGradingSheet(a),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _assignmentFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _assignmentFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.black12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // -------------------- TAB 4: QUIZ & TESTS --------------------
  Widget _buildQuizzesTab() {
    final allQuizzes = <Map<String, dynamic>>[];
    for (final c in _courses) {
      final qList = c['quizzes'] as List?;
      if (qList != null) {
        for (final q in qList) {
          allQuizzes.add({
            ...Map<String, dynamic>.from(q),
            'courseTitle': c['title'],
          });
        }
      }
    }

    if (allQuizzes.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.quiz_rounded,
        title: 'Aucun quiz actif',
        subtitle: 'Les évaluations et QCM en ligne seront affichés dès leur activation par les professeurs.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allQuizzes.length,
      itemBuilder: (context, index) {
        final q = allQuizzes[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      q['courseTitle'] ?? 'Formation',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Requis : ${q['passingScore'] ?? 10}/20',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                q['title'] ?? 'Quiz',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              if (q['description'] != null && q['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  q['description'],
                  style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Text(
                    'Durée : ${q['durationMin'] ?? 20} minutes',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Commencer le test',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LmsQuizScreen(
                          quiz: q,
                          studentId: widget.studentId,
                          studentName: widget.studentName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- TAB 5: FORUM & QUESTIONS --------------------
  Widget _buildForumTab() {
    if (_discussions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.forum_outlined, size: 54, color: AppColors.slate400),
              const SizedBox(height: 16),
              const Text(
                'Forum d\'entraide & Questions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Échangez avec vos enseignants et vos camarades de classe sur tous les modules de formation.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_comment_rounded, size: 18),
                label: const Text('Poser la première question'),
                onPressed: _showNewDiscussionDialog,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _discussions.length,
      itemBuilder: (context, index) {
        final d = _discussions[index];
        final isTeacher = d['isTeacher'] == true;
        final author = d['authorName'] ?? 'Anonyme';
        final msg = d['message'] ?? '';
        final courseTitle = d['courseTitle'] ?? 'Formation';
        final lessonTitle = d['lessonTitle'];
        final dateStr = d['createdAt'] != null
            ? DateTime.tryParse(d['createdAt'])?.toLocal().toString().split(' ').first ?? ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isTeacher ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTeacher ? AppColors.primary.withOpacity(0.3) : Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isTeacher ? AppColors.primary : const Color(0xFF64748B),
                    child: Text(
                      author.isNotEmpty ? author[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              author,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isTeacher ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            if (isTeacher) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Enseignant',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '$courseTitle ${lessonTitle != null ? '• $lessonTitle' : ''}',
                          style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                msg,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- TAB 6: CERTIFICATS --------------------
  Widget _buildCertificatesTab() {
    if (_certificates.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.workspace_premium_rounded,
        title: 'Aucun certificat obtenu',
        subtitle: 'Terminez vos cours et réussissez vos examens pour débloquer vos attestations officielles.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        final code = cert['certificateCode'] ?? 'CERT-LMS';
        final courseTitle = cert['courseTitle'] ?? 'Formation complète';
        final dateStr = cert['issueDate'] != null
            ? DateTime.tryParse(cert['issueDate'])?.toLocal().toString().split(' ').first ?? ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1B4B).withOpacity(0.35),
                blurRadius: 14,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
                  ),
                  Text(
                    'Délivré le : $dateStr',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'CERTIFICAT OFFICIEL DE RÉUSSITE',
                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                courseTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Code de vérification : $code',
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.amber, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code du certificat copié !')),
                        );
                      },
                      tooltip: 'Copier le code',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Download PDF and Share buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text(
                        'Télécharger (PDF)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        LmsCertificatePdfGenerator.printCertificate(
                          studentName: widget.studentName ?? 'Élève Edut',
                          courseTitle: courseTitle,
                          certificateCode: code,
                          issueDate: dateStr,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    tooltip: 'Partager le certificat',
                    onPressed: () {
                      LmsCertificatePdfGenerator.shareCertificate(
                        studentName: widget.studentName ?? 'Élève Edut',
                        courseTitle: courseTitle,
                        certificateCode: code,
                        issueDate: dateStr,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyWidget({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- TEACHER GRADING MODAL --------------------
class _TeacherGradingModal extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final LmsRepository repo;
  final VoidCallback onGraded;

  const _TeacherGradingModal({
    required this.assignment,
    required this.repo,
    required this.onGraded,
  });

  @override
  State<_TeacherGradingModal> createState() => _TeacherGradingModalState();
}

class _TeacherGradingModalState extends State<_TeacherGradingModal> {
  bool _isLoading = true;
  List<dynamic> _submissions = [];

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    final list = await widget.repo.getAssignmentSubmissions(assignmentId: widget.assignment['id']);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _submissions = list;
      });
    }
  }

  void _showGradeDialog(Map<String, dynamic> sub) {
    final scoreCtrl = TextEditingController(text: sub['score']?.toString() ?? '');
    final commentCtrl = TextEditingController(text: sub['comment']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Noter : ${sub['studentName']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Note attribuée (/20) :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: scoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Ex: 16.5',
                filled: true,
                fillColor: AppColors.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Commentaire / Remarques du professeur :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Très bon travail...',
                filled: true,
                fillColor: AppColors.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final scoreVal = double.tryParse(scoreCtrl.text.trim());
              if (scoreVal == null) return;
              Navigator.pop(ctx);
              final ok = await widget.repo.gradeAssignmentSubmission(
                submissionId: sub['id'],
                score: scoreVal,
                comment: commentCtrl.text.trim(),
              );
              if (mounted && ok) {
                _fetchSubmissions();
                widget.onGraded();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Note enregistrée avec succès !'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Enregistrer la note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Copies reçues (Notation)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(
                      widget.assignment['title'] ?? 'Devoir',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _submissions.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune copie remise par les élèves pour ce devoir.',
                          style: TextStyle(color: AppColors.slate500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _submissions.length,
                        itemBuilder: (context, idx) {
                          final s = _submissions[idx];
                          final isGraded = s['isGraded'] == true;
                          final dateStr = s['submittedAt'] != null
                              ? DateTime.tryParse(s['submittedAt'])?.toLocal().toString().split(' ').first ?? ''
                              : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isGraded ? const Color(0xFFF0FDF4) : AppColors.slate50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isGraded ? AppColors.success.withOpacity(0.4) : Colors.black12,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      s['studentName'] ?? 'Élève',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isGraded ? AppColors.success : AppColors.warning,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isGraded ? '${s['score']}/20' : 'À noter',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Soumis le : $dateStr',
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                ),
                                if (s['comment'] != null && s['comment'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Réponse : ${s['comment']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate800),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (s['fileReponsePath'] != null && s['fileReponsePath'].toString().isNotEmpty)
                                      TextButton.icon(
                                        icon: const Icon(Icons.attachment, size: 16),
                                        label: const Text('Voir pièce jointe', style: TextStyle(fontSize: 12)),
                                        onPressed: () async {
                                          final uri = Uri.tryParse(s['fileReponsePath']);
                                          if (uri != null && await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                      ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.grade_rounded, size: 16),
                                      label: Text(
                                        isGraded ? 'Modifier la note' : 'Attribuer une note',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () => _showGradeDialog(s),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

extension CourseFilterExtension on List<dynamic> {
  List<dynamic> filterByQuery(String query) {
    if (query.trim().isEmpty) return this;
    final q = query.toLowerCase().trim();
    return where((c) {
      final title = c['title']?.toString().toLowerCase() ?? '';
      final subject = c['subject']?['subjectName']?.toString().toLowerCase() ?? '';
      return title.contains(q) || subject.contains(q);
    }).toList();
  }
}
