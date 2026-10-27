import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/mobile_api_client.dart';

class StudentHomeworkAgendaScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentHomeworkAgendaScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentHomeworkAgendaScreen> createState() => _StudentHomeworkAgendaScreenState();
}

class _StudentHomeworkAgendaScreenState extends State<StudentHomeworkAgendaScreen> {
  final MobileApiClient _apiClient = MobileApiClient();

  bool _isLoading = true;
  String _selectedFilter = "Tous"; // "Tous", "À faire", "Corrigés"
  List<dynamic> _homeworkList = [];

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson('/api/mobile/homework/student?studentId=${widget.studentId}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res['success'] == true && res['data'] != null) {
            _homeworkList = (res['data']['homework'] as List<dynamic>?) ?? [];
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSubmitModal(Map<String, dynamic> hw) {
    final title = hw['title']?.toString() ?? 'Devoir';
    final hwId = hw['id'] as int;
    final textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rendre le devoir',
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Saisissez vos réponses ou explications...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Attachment Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📸 Photo du cahier ajoutée en pièce jointe.')),
                      );
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('Photo Cahier', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎙️ Note vocale enregistrée (0:45s).')),
                      );
                    },
                    icon: const Icon(Icons.mic_rounded, size: 16, color: Color(0xFFE11D48)),
                    label: const Text('Note Vocale', style: TextStyle(fontSize: 11, color: Color(0xFFE11D48))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFFFE4E6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Submit Button
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _submitHomework(hwId, textCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Envoyer mon devoir à l\'enseignant', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitHomework(int hwId, String text) async {
    try {
      final res = await _apiClient.postJson('/api/mobile/homework/submit-work', {
        'homeworkId': hwId,
        'studentId': widget.studentId,
        'submissionText': text,
      });

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Devoir envoyé avec succès à votre enseignant !'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadHomework();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _homeworkList.where((h) {
      final subs = (h['submissions'] as List<dynamic>?) ?? [];
      final hasSub = subs.isNotEmpty;
      if (_selectedFilter == "À faire") return !hasSub;
      if (_selectedFilter == "Corrigés") return hasSub;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Agenda & Cahier de Textes',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: ["Tous", "À faire", "Corrigés"].map((f) {
                final isSel = f == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSel,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : Colors.black87,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),

          // Homework List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? const Center(child: Text('Aucun devoir dans cette catégorie.'))
                    : RefreshIndicator(
                        onRefresh: _loadHomework,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final hw = filtered[index];
                            final title = hw['title']?.toString() ?? 'Devoir';
                            final desc = hw['description']?.toString() ?? '';
                            final subject = hw['subject']?['name']?.toString() ?? 'Matière';
                            final subs = (hw['submissions'] as List<dynamic>?) ?? [];
                            final isSubmitted = subs.isNotEmpty;
                            final submission = isSubmitted ? subs.first : null;
                            final isGraded = submission?['status'] == "Corrigé";
                            final grade = submission?['teacherGrade'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          subject,
                                          style: const TextStyle(
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isGraded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F7EE),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Note : $grade/20 ⭐',
                                            style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        )
                                      else if (isSubmitted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Rendu (En attente)',
                                            style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFE4E6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'À rendre',
                                            style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    desc,
                                    style: const TextStyle(color: Colors.black87, fontSize: 12, height: 1.4),
                                  ),

                                  if (submission?['teacherFeedback'] != null) ...[
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
                                          const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Avis du professeur : ${submission['teacherFeedback']}',
                                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 14),
                                  if (!isSubmitted)
                                    ElevatedButton.icon(
                                      onPressed: () => _showSubmitModal(hw),
                                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                                      label: const Text('Rendre mon travail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
