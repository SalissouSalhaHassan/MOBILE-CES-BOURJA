import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class VoiceNotePlayerCard extends StatefulWidget {
  final int studentId;

  const VoiceNotePlayerCard({super.key, required this.studentId});

  @override
  State<VoiceNotePlayerCard> createState() => _VoiceNotePlayerCardState();
}

class _VoiceNotePlayerCardState extends State<VoiceNotePlayerCard> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _voiceNotes = [];
  int? _playingNoteId;
  int _currentSeconds = 0;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    _loadVoiceNotes();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVoiceNotes() async {
    try {
      final res = await _apiClient.getJson('/api/mobile/voice-notes?studentId=${widget.studentId}');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _voiceNotes = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlay(int id, int duration) {
    if (_playingNoteId == id) {
      _playTimer?.cancel();
      setState(() {
        _playingNoteId = null;
        _currentSeconds = 0;
      });
    } else {
      _playTimer?.cancel();
      setState(() {
        _playingNoteId = id;
        _currentSeconds = 0;
      });
      _playTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_currentSeconds >= duration) {
          t.cancel();
          setState(() {
            _playingNoteId = null;
            _currentSeconds = 0;
          });
        } else {
          setState(() => _currentSeconds++);
        }
      });
    }
  }

  String _getLanguageFlag(String lang) {
    switch (lang.toLowerCase()) {
      case 'hausa':
        return '🇳🇪 Hausa';
      case 'zarma':
        return '🇳🇪 Zarma';
      case 'arabe':
        return '🇸🇦 Arabe';
      case 'français':
      default:
        return '🇫🇷 Français';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_voiceNotes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Color(0xFFEF4444), size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Remarques Vocales des Professeurs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._voiceNotes.map((note) {
            final id = note['id'] as int? ?? 0;
            final isPlaying = _playingNoteId == id;
            final duration = note['durationSeconds'] as int? ?? 15;
            final teacher = note['teacherName'] ?? 'Enseignant';
            final subject = note['subjectName'] ?? 'Matière';
            final lang = note['language'] ?? 'Français';
            final transcript = note['transcript'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPlaying ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPlaying ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _togglePlay(id, duration),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$subject • $teacher',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPlaying
                                  ? 'Lecture... 00:${_currentSeconds.toString().padLeft(2, '0')}s / 00:${duration.toString().padLeft(2, '0')}s'
                                  : 'Durée : 00:${duration.toString().padLeft(2, '0')}s',
                              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getLanguageFlag(lang),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  if (transcript.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '« $transcript »',
                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.slate700),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
