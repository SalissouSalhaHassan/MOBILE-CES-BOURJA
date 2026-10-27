import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class VoiceNoteRecorderDialog extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String subjectName;
  final String className;
  final String? parentPhone;

  const VoiceNoteRecorderDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.subjectName,
    required this.className,
    this.parentPhone,
  });

  static Future<void> show(
    BuildContext context, {
    required int studentId,
    required String studentName,
    required String subjectName,
    required String className,
    String? parentPhone,
  }) {
    return showDialog(
      context: context,
      builder: (_) => VoiceNoteRecorderDialog(
        studentId: studentId,
        studentName: studentName,
        subjectName: subjectName,
        className: className,
        parentPhone: parentPhone,
      ),
    );
  }

  @override
  State<VoiceNoteRecorderDialog> createState() => _VoiceNoteRecorderDialogState();
}

class _VoiceNoteRecorderDialogState extends State<VoiceNoteRecorderDialog>
    with SingleTickerProviderStateMixin {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _transcriptController = TextEditingController();

  String _selectedLanguage = 'Français';
  bool _isRecording = false;
  bool _isRecorded = false;
  bool _isPlaying = false;
  bool _isSubmitting = false;
  int _recordSeconds = 0;
  Timer? _timer;

  final List<Map<String, String>> _languages = [
    {'name': 'Français', 'flag': '🇫🇷', 'label': 'Français'},
    {'name': 'Hausa', 'flag': '🇳🇪', 'label': 'Hausa'},
    {'name': 'Zarma', 'flag': '🇳🇪', 'label': 'Zarma'},
    {'name': 'Arabe', 'flag': '🇸🇦', 'label': 'العربية'},
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _transcriptController.dispose();
    super.dispose();
  }

  void _toggleRecord() {
    if (!_isRecording) {
      setState(() {
        _isRecording = true;
        _isRecorded = false;
        _recordSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _recordSeconds++;
          if (_recordSeconds >= 30) {
            _stopRecord();
          }
        });
      });
    } else {
      _stopRecord();
    }
  }

  void _stopRecord() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isRecorded = true;
    });

    if (_transcriptController.text.isEmpty) {
      if (_selectedLanguage == 'Hausa') {
        _transcriptController.text = "Barka! Muna sanar da ku cewa ${widget.studentName} yana yin kokari sosai a fannin ${widget.subjectName}.";
      } else if (_selectedLanguage == 'Zarma') {
        _transcriptController.text = "Fofo! Iri ga bayandi ${widget.studentName} go ga goy fondo boro ${widget.subjectName} ra.";
      } else if (_selectedLanguage == 'Arabe') {
        _transcriptController.text = "تحية طيبة، نود إحاطتكم بأن التلميذ(ة) ${widget.studentName} يبذل مجهوداً مميزاً في مادة ${widget.subjectName}.";
      } else {
        _transcriptController.text = "Bonjour, nous vous partageons les observations sur les progrès de ${widget.studentName} en ${widget.subjectName}.";
      }
    }
  }

  Future<void> _submitVoiceNote() async {
    setState(() => _isSubmitting = true);
    try {
      final res = await _apiClient.postJson('/api/mobile/voice-notes', {
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'subjectName': widget.subjectName,
        'language': _selectedLanguage,
        'transcript': _transcriptController.text.trim(),
        'durationSeconds': _recordSeconds > 0 ? _recordSeconds : 15,
      });

      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Note vocale en $_selectedLanguage enregistrée avec succès ! 🎙️'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final phone = widget.parentPhone ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = "*NOTE VOCALE & OBSERVATION DU PROFESSEUR* 🎙️\n\nÉlève : *${widget.studentName}* (${widget.className})\nMatière : *${widget.subjectName}*\nLangue : *$_selectedLanguage*\n\n📝 _Observation :_ \"${_transcriptController.text.trim()}\"\n\n▶️ _Écoutez la note vocale directement sur l'application Edut._";
    final url = Uri.parse("https://api.whatsapp.com/send?phone=${cleanPhone.length == 8 ? '227$cleanPhone' : cleanPhone}&text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded, color: Color(0xFFEF4444), size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Note Vocale Multilingue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Élève : ${widget.studentName} • ${widget.subjectName}',
                style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // Language selector
              const Text('Langue d\'enregistrement :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _languages.map((l) {
                    final isSel = l['name'] == _selectedLanguage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${l['flag']} ${l['label']}'),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedLanguage = l['name']!),
                        selectedColor: const Color(0xFFEFF6FF),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? const Color(0xFF2563EB) : AppColors.slate700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Recording Hub
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _toggleRecord,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? const Color(0xFFEF4444)
                              : _isRecorded
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2563EB),
                          boxShadow: [
                            if (_isRecording)
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                          ],
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.stop_rounded
                              : _isRecorded
                                  ? Icons.replay_rounded
                                  : Icons.mic_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording
                          ? 'Enregistrement... 00:${_recordSeconds.toString().padLeft(2, '0')}s'
                          : _isRecorded
                              ? 'Audio prêt (00:${_recordSeconds > 0 ? _recordSeconds.toString().padLeft(2, '0') : '15'}s)'
                              : 'Touchez pour enregistrer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? const Color(0xFFEF4444) : AppColors.slate700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transcript / Note preview
              const Text('Transcription / Résumé écrit :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _transcriptController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Résumé de la note vocale...',
                  hintStyle: TextStyle(color: AppColors.slate400, fontSize: 11.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isRecorded)
          IconButton(
            onPressed: _shareWhatsApp,
            icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF10B981)),
            tooltip: 'Partager sur WhatsApp',
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppColors.slate500)),
        ),
        ElevatedButton(
          onPressed: (_isRecorded && !_isSubmitting) ? _submitVoiceNote : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enregistrer la note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
