import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class StudentHomeworkScreen extends StatefulWidget {
  final int? initialStudentId;
  final String? initialClassName;
  final String? initialStudentName;

  const StudentHomeworkScreen({
    super.key,
    this.initialStudentId,
    this.initialClassName,
    this.initialStudentName,
  });

  @override
  State<StudentHomeworkScreen> createState() => _StudentHomeworkScreenState();
}

class _StudentHomeworkScreenState extends State<StudentHomeworkScreen>
    with SingleTickerProviderStateMixin {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _homeworkList = [];

  int? _studentId;
  String _className = '';
  String _studentName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _studentId = widget.initialStudentId;
    _className = widget.initialClassName ?? '';
    _studentName = widget.initialStudentName ?? '';
    _loadHomework();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = locator<SessionManager>();
      if (_studentId == null) {
        final sIdStr = await session.getStudentId();
        _studentId = int.tryParse(sIdStr ?? '');
      }

      if (_className.isEmpty) {
        _className = await session.getStudentClass() ?? 'Terminale D';
        if (_studentName.isEmpty) {
          _studentName = await session.getStudentName() ?? 'Élève';
        }
      }

      if (_studentId == null) {
        _studentId = 1; // Fallback
      }

      final res = await _apiClient.getJson(
        '/api/mobile/family/homework?studentId=$_studentId&className=${Uri.encodeComponent(_className)}',
      );

      if (res['success'] == true && res['data'] != null) {
        _homeworkList = List<Map<String, dynamic>>.from(res['data']);
      } else {
        _homeworkList = [];
      }
    } catch (e) {
      _errorMessage = "Erreur: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitHomework(int homeworkId, String title) async {
    final textController = TextEditingController();
    String? selectedFilePath;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remettre mon Devoir 📤',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    title,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rédaction / Réponses textuelles :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Saisissez vos réponses, justifications ou liens de partage...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        selectedFilePath = 'copie_devoir_${DateTime.now().millisecondsSinceEpoch}.pdf';
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selectedFilePath != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedFilePath != null ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFilePath != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                            color: selectedFilePath != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedFilePath ?? 'Joindre un fichier / Photo du cahier (PDF, JPG)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selectedFilePath != null ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Confirmer la Remise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envoi du devoir en cours...')),
      );

      try {
        final res = await _apiClient.postJson('/api/mobile/family/homework', {
          'homeworkId': homeworkId,
          'studentId': _studentId,
          'textContent': textController.text.trim(),
          'filePath': selectedFilePath ?? 'reponse_redaction.pdf',
        });

        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Devoir remis avec succès !'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            _loadHomework();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _homeworkList.filterByStatus('À faire');
    final submitted = _homeworkList.filterByStatus('Soumis');
    final graded = _homeworkList.filterByStatus('Noté');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Devoirs & Travaux Dirigés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('$_className • $_studentName', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: AppColors.slate500,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: [
            Tab(text: 'À faire (${pending.length})'),
            Tab(text: 'Soumis (${submitted.length})'),
            Tab(text: 'Notés (${graded.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_errorMessage!, textAlign: TextAlign.center),
                ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHomeworkList(pending, isPendingTab: true),
                    _buildHomeworkList(submitted),
                    _buildHomeworkList(graded, isGradedTab: true),
                  ],
                ),
    );
  }

  Widget _buildHomeworkList(List<Map<String, dynamic>> items, {bool isPendingTab = false, bool isGradedTab = false}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, size: 48, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun devoir dans cette section',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tous vos devoirs et exercices s\'afficheront ici automatiquement dès publication par vos professeurs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomework,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final title = item['title']?.toString() ?? 'Devoir à la maison';
          final desc = item['description']?.toString() ?? '';
          final subject = item['subject_name']?.toString() ?? 'Matière';
          final dateDue = item['date_due'] != null ? DateTime.parse(item['date_due']) : null;
          final dateDueStr = dateDue != null ? DateFormat('dd/MM/yyyy • HH:mm').format(dateDue) : 'Date non spécifiée';
          final submission = item['submission'] as Map<String, dynamic>?;
          final score = submission?['score'];
          final feedback = submission?['feedback'];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subject,
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    if (isGradedTab && score != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Note : $score / 20 ⭐',
                          style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.alarm_rounded, color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            dateDueStr,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                  ),
                ],
                if (feedback != null && feedback.toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.comment_rounded, color: Color(0xFF64748B), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Remarque du professeur :',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF475569)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                feedback.toString(),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (isPendingTab)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      label: const Text('Rendre ce devoir en ligne', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _submitHomework(item['id'], title),
                    ),
                  )
                else if (submission != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          submission['submittedAt'] != null
                              ? 'Remis le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(submission['submittedAt']))}'
                              : 'Devoir remis',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension HomeworkFilter on List<Map<String, dynamic>> {
  List<Map<String, dynamic>> filterByStatus(String status) {
    return where((h) => h['status'] == status).toList();
  }
}
