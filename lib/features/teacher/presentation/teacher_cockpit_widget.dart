import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import 'classroom_tools_modal.dart';
import '../../../core/di/injection.dart';

class TeacherCockpitWidget extends StatefulWidget {
  const TeacherCockpitWidget({super.key});

  @override
  State<TeacherCockpitWidget> createState() => _TeacherCockpitWidgetState();
}

class _TeacherCockpitWidgetState extends State<TeacherCockpitWidget> {
  final _teacherRepo = locator<TeacherRepository>();
  bool _isLoading = true;
  Map<String, dynamic> _cockpitData = {};
  Timer? _liveClockTimer;
  String _currentTime = '08:00';

  @override
  void initState() {
    super.initState();
    _startClock();
    _load();
  }

  void _startClock() {
    _updateTime();
    _liveClockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _teacherRepo.getTeacherCockpit();
      if (mounted) {
        setState(() {
          _cockpitData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAtRiskStudentsModal(List<dynamic> atRisk, String? className) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Élèves à Risque • ${className ?? 'Classe'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: atRisk.isEmpty
                    ? const Center(child: Text('Aucun élève en situation de risque détecté.', style: TextStyle(color: AppColors.slate500)))
                    : ListView.builder(
                        itemCount: atRisk.length,
                        itemBuilder: (context, i) {
                          final student = atRisk[i];
                          final name = student['name'] ?? 'Élève';
                          final reason = student['riskReason'] ?? 'Attention requise';
                          final isHigh = student['severity'] == 'high';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isHigh ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isHigh ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isHigh ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  child: Icon(Icons.person_rounded, color: isHigh ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                      const SizedBox(height: 2),
                                      Text(reason, style: TextStyle(fontSize: 11.5, color: isHigh ? const Color(0xFF991B1B) : const Color(0xFF92400E))),
                                    ],
                                  ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
        ),
      );
    }

    final focus = _cockpitData['activeFocus'] as Map<String, dynamic>?;
    final session = focus?['session'] as Map<String, dynamic>?;
    final isHappeningNow = focus?['isHappeningNow'] == true;
    final startsIn = focus?['timeUntilNextMinutes'] ?? 10;
    final className = session?['className'] ?? '3ème B';
    final subjectName = session?['subjectName'] ?? 'Mathématiques';
    final roomName = session?['roomName'] ?? 'Salle 04';
    final startTime = session?['startTime'] ?? '08:00';
    final endTime = session?['endTime'] ?? '10:00';

    final checklist = (_cockpitData['checklist'] as List?) ?? [];
    final atRiskList = (_cockpitData['atRiskStudents'] as List?) ?? [];
    final scheduleList = (_cockpitData['todaySchedule'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Live Hero Focus Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status ribbon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHappeningNow
                          ? const Color(0xFF10B981).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isHappeningNow ? const Color(0xFF10B981) : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3.5,
                          backgroundColor: isHappeningNow ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isHappeningNow ? 'COURS EN DIRECT' : 'PROCHAIN COURS DANS ~$startsIn MIN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currentTime,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Class & Subject Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$className • $subjectName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.meeting_room_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text('${roomName.startsWith("Salle") ? roomName : "Salle $roomName"} • $startTime → $endTime', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),

              // 1-Tap Fast Actions Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(
                        '/attendance?classId=${session?['classId'] ?? 1}&className=${Uri.encodeComponent(className)}&subjectId=${session?['subjectId'] ?? ''}&subjectName=${Uri.encodeComponent(subjectName)}',
                        extra: {
                          'classId': session?['classId'] ?? 1,
                          'className': className,
                          'subjectId': session?['subjectId'],
                          'subjectName': subjectName,
                        },
                      ),
                      icon: const Icon(Icons.fact_check_rounded, size: 16, color: Color(0xFF6D28D9)),
                      label: const Text('Faire l\'appel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/pedagogie/cahier-textes'),
                      icon: const Icon(Icons.menu_book_rounded, size: 16, color: Colors.white),
                      label: const Text('Cahier Textes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _showAtRiskStudentsModal(atRiskList, className),
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                    tooltip: 'Élèves à risque',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. AI & Classroom Tools Bar
        const Text(
          'Assistant Pédagogique & Outils de Classe',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.slate900),
        ),
        const SizedBox(height: 10),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildToolCard(
                icon: Icons.casino_rounded,
                title: 'Tirage au Sort',
                subtitle: 'Participation',
                color: const Color(0xFF6D28D9),
                onTap: () => ClassroomToolsModal.show(context, className: className),
              ),
              _buildToolCard(
                icon: Icons.timer_rounded,
                title: 'Chronomètre',
                subtitle: 'Activités classe',
                color: const Color(0xFFF59E0B),
                onTap: () => ClassroomToolsModal.show(context, className: className),
              ),
              _buildToolCard(
                icon: Icons.star_rounded,
                title: 'Live Discipline',
                subtitle: 'Mérites & Notes',
                color: const Color(0xFF10B981),
                onTap: () => context.push('/teacher/live-discipline?class=${Uri.encodeComponent(className)}'),
              ),
              _buildToolCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Générateur d\'Examens',
                subtitle: 'Quiz & Devoirs IA',
                color: const Color(0xFF2563EB),
                onTap: () => context.push('/teacher/ai-exam-generator?class=${Uri.encodeComponent(className)}&subject=${Uri.encodeComponent(subjectName)}'),
              ),
              _buildToolCard(
                icon: Icons.assignment_turned_in_rounded,
                title: 'Fiche APC (IA)',
                subtitle: 'Prépa de leçon',
                color: const Color(0xFF0D9488),
                onTap: () => context.push('/teacher/ai-fiche-pedagogique?class=${Uri.encodeComponent(className)}&subject=${Uri.encodeComponent(subjectName)}'),
              ),
              _buildToolCard(
                icon: Icons.analytics_rounded,
                title: 'Diagnostic IA',
                subtitle: 'Remédiation',
                color: const Color(0xFF4F46E5),
                onTap: () => context.push('/teacher/ai-remediation?class=${Uri.encodeComponent(className)}&subject=${Uri.encodeComponent(subjectName)}'),
              ),
              _buildToolCard(
                icon: Icons.badge_rounded,
                title: 'Espace RH & Paie',
                subtitle: 'Fiches & Heures Sup',
                color: const Color(0xFF0F766E),
                onTap: () => context.push('/teacher/self-service-hr'),
              ),
              _buildToolCard(
                icon: Icons.shield_rounded,
                title: 'Bouclier DND',
                subtitle: 'Silence & Réponses',
                color: const Color(0xFF334155),
                onTap: () => context.push('/teacher/comm-protection'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. Daily Checklist
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist_rounded, color: Color(0xFF6D28D9), size: 20),
                  SizedBox(width: 8),
                  Text('Mes Tâches Pédagogiques du Jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              ...checklist.map((item) {
                final title = item['title'] ?? '';
                final isDone = item['isDone'] == true;
                final route = item['actionRoute'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: route != null ? () => context.push(route) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFFF8FAFC) : const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isDone ? const Color(0xFF10B981) : const Color(0xFF6D28D9),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone ? AppColors.slate400 : AppColors.slate800,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 4. Today's Full Schedule
        if (scheduleList.isNotEmpty) ...[
          const Text(
            'Planning de ma Journée',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.slate900),
          ),
          const SizedBox(height: 10),
          ...scheduleList.map((sc) {
            final cName = sc['className'] ?? 'Classe';
            final sName = sc['subjectName'] ?? 'Matière';
            final rName = sc['roomName'] ?? 'Salle';
            final st = sc['startTime'] ?? '';
            final et = sc['endTime'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$st\n$et', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$cName — $sName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('$rName • Cours régulier', style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.slate900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.slate500, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
