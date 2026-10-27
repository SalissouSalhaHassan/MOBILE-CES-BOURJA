import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import '../../../core/di/injection.dart';

class LiveDisciplineScreen extends StatefulWidget {
  final String? initialClass;
  const LiveDisciplineScreen({super.key, this.initialClass});

  @override
  State<LiveDisciplineScreen> createState() => _LiveDisciplineScreenState();
}

class _LiveDisciplineScreenState extends State<LiveDisciplineScreen> {
  final _teacherRepo = locator<TeacherRepository>();
  String _selectedClass = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];

  List<String> _classes = [];

  @override
  void initState() {
    super.initState();
    _initClassesAndStudents();
  }

  Future<void> _initClassesAndStudents() async {
    final list = await _teacherRepo.getTeacherClassesAndSubjects();
    final classNames = <String>{};
    for (final row in list) {
      final cName = row['school_classes']?['class_name'] ?? row['class_name'];
      if (cName != null && cName.toString().isNotEmpty) classNames.add(cName.toString());
    }

    setState(() {
      _classes = classNames.isNotEmpty ? classNames.toList() : ['6ème A', '5ème A', '4ème A', '3ème A', '2nde C', '1ère D', 'Tle D'];
      if (widget.initialClass != null && _classes.contains(widget.initialClass)) {
        _selectedClass = widget.initialClass!;
      } else {
        _selectedClass = _classes.first;
      }
    });

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final data = await _teacherRepo.getClassStudentsDiscipline(_selectedClass);
      final list = (data['students'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      setState(() {
        _students = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStudentActionDialog(Map<String, dynamic> student) {
    final studentId = student['id'] as int? ?? 1;
    final studentName = student['name'] ?? 'Élève';
    final currentScore = (student['score'] as num?)?.toInt() ?? 80;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
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
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF6D28D9), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Score de comportement actuel : $currentScore / 100', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Actions de Mérite & Participation ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857))),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.star_rounded,
                color: const Color(0xFF10B981),
                title: 'Participation Excellente',
                points: '+5 Pts',
                onTap: () => _applyPoints(studentId, 'Participation active ⭐', 5.0),
              ),
              _buildActionButton(
                icon: Icons.lightbulb_rounded,
                color: const Color(0xFF0D9488),
                title: 'Réponse Brillante & Initiative',
                points: '+3 Pts',
                onTap: () => _applyPoints(studentId, 'Réponse brillante 💡', 3.0),
              ),
              _buildActionButton(
                icon: Icons.groups_rounded,
                color: const Color(0xFF2563EB),
                title: 'Entraide & Travail d\'équipe',
                points: '+2 Pts',
                onTap: () => _applyPoints(studentId, 'Entraide et coopération 🤝', 2.0),
              ),
              const SizedBox(height: 14),
              const Text('Remarques de Discipline ⚠️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB91C1C))),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Oubli de matériel ou cahier',
                points: '-2 Pts',
                onTap: () => _applyPoints(studentId, 'Oubli de matériel ⚠️', -2.0),
              ),
              _buildActionButton(
                icon: Icons.record_voice_over_rounded,
                color: const Color(0xFFEF4444),
                title: 'Bavardage & Perturbation',
                points: '-5 Pts',
                onTap: () => _applyPoints(studentId, 'Bavardage / Perturbation ❌', -5.0),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyPoints(int studentId, String actionType, double points) async {
    Navigator.pop(context); // close sheet
    setState(() {
      final idx = _students.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        final cur = (_students[idx]['score'] as num?)?.toInt() ?? 80;
        _students[idx]['score'] = (cur + points).clamp(0, 100).toInt();
      }
    });

    try {
      await _teacherRepo.recordLiveDisciplineAction(
        studentId: studentId,
        actionType: actionType,
        pointsEffect: points,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(points > 0 ? '⭐ $actionType enregistré !' : '⚠️ Remarque $actionType enregistrée.'),
            backgroundColor: points > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Saisie Live Discipline & Mérites', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Class Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: Color(0xFF6D28D9), size: 20),
                const SizedBox(width: 10),
                const Text('Classe : ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _classes.map((c) {
                        final isSel = c == _selectedClass;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSel ? Colors.white : AppColors.slate700)),
                            selected: isSel,
                            selectedColor: const Color(0xFF6D28D9),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (_) {
                              setState(() => _selectedClass = c);
                              _loadStudents();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)))
                : _students.isEmpty
                    ? const Center(child: Text('Aucun élève trouvé dans cette classe.', style: TextStyle(color: AppColors.slate500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _students.length,
                        itemBuilder: (context, i) {
                          final s = _students[i];
                          final name = s['name'] ?? 'Élève';
                          final score = (s['score'] as num?)?.toInt() ?? 80;
                          final isTop = score >= 85;
                          final isAtRisk = score < 65;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: isTop
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isAtRisk ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFFF1F5F9)),
                                child: Text(
                                  name.isNotEmpty ? name[0] : 'E',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isTop ? const Color(0xFF10B981) : (isAtRisk ? const Color(0xFFEF4444) : const Color(0xFF6D28D9)),
                                  ),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isTop ? const Color(0xFFECFDF5) : (isAtRisk ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$score pts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isTop ? const Color(0xFF047857) : (isAtRisk ? const Color(0xFFB91C1C) : AppColors.slate700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton.filledTonal(
                                icon: const Icon(Icons.add_task_rounded, color: Color(0xFF6D28D9)),
                                onPressed: () => _showStudentActionDialog(s),
                              ),
                              onTap: () => _showStudentActionDialog(s),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String title,
    required String points,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(points, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
