import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../data/ai_repository.dart';

class AiVoiceAssistantSheet extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final String? studentClass;

  const AiVoiceAssistantSheet({
    super.key,
    this.studentId,
    this.studentName,
    this.studentClass,
  });

  static Future<void> show(
    BuildContext context, {
    int? studentId,
    String? studentName,
    String? studentClass,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiVoiceAssistantSheet(
        studentId: studentId,
        studentName: studentName,
        studentClass: studentClass,
      ),
    );
  }

  @override
  State<AiVoiceAssistantSheet> createState() => _AiVoiceAssistantSheetState();
}

class _AiVoiceAssistantSheetState extends State<AiVoiceAssistantSheet>
    with SingleTickerProviderStateMixin {
  final AiRepository _aiRepo = locator<AiRepository>();
  final TextEditingController _queryController = TextEditingController();

  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  String _selectedLanguage = "HA"; // "HA" (Hausa), "ZA" (Zarma), "FR" (Français)
  bool _isListening = false;
  bool _isLoading = false;
  String? _lastResponse;
  String? _lastQuery;
  List<String> _suggestedQuestions = [];

  int? _resolvedStudentId;
  String _resolvedStudentName = '';
  String _resolvedStudentClass = '';

  final Map<String, Map<String, dynamic>> _langConfig = {
    'HA': {
      'name': 'Hausa 🇳🇪',
      'label': 'Harshen Hausa',
      'hint': 'Yi magana ko rubuta tambaya...',
      'greeting': 'Barka! Tambaye ni komai game da makarantar Edut.',
      'prompts': [
        'Ina motar makaranta take?',
        'Nawa ne kudin makaranta na?',
        'Wadanne darussa nake da su yau?',
        'Nawa ne sakamakon jarrabawa?',
      ],
    },
    'ZA': {
      'name': 'Zarma 🇳🇪',
      'label': 'Zarmaciine',
      'hint': 'Saalance wala hantum hãbuko...',
      'greeting': 'Fofo! Hã ka di caw hayey kulu ga.',
      'prompts': [
        'Man no lokol mobilo go?',
        'Marje no caw hayo cindi?',
        'Iri zaari caw fondo?',
        'Alhabar maki kora?',
      ],
    },
    'FR': {
      'name': 'Français 🇫🇷',
      'label': 'Français',
      'hint': 'Parlez ou tapez votre question...',
      'greeting': 'Bonjour ! Posez votre question sur la scolarité Edut.',
      'prompts': [
        'Où est le bus scolaire ?',
        'Quel est mon solde de scolarité ?',
        'Quels sont mes cours aujourd\'hui ?',
        'Quel est le dernier devoir ?',
      ],
    },
    'AR': {
      'name': 'العربية 🇸🇦',
      'label': 'اللغة العربية',
      'hint': 'تحدث أو اكتب سؤالك هنا...',
      'greeting': 'مرحباً بك! اسألني عن أي تفاصيل تخص دراسة ابنك في Edut.',
      'prompts': [
        'أين توجد الحافلة المدرسية الآن؟',
        'كم المبلغ المتبقي من الرسوم الدراسية؟',
        'ما هي الحصص الدراسية اليوم؟',
        'ما هي آخر الدرجات والواجبات؟',
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _waveAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _resolvedStudentId = widget.studentId;
    _resolvedStudentName = widget.studentName ?? '';
    _resolvedStudentClass = widget.studentClass ?? '';
    _loadSessionInfo();
    _updatePrompts();
  }

  Future<void> _loadSessionInfo() async {
    final session = locator<SessionManager>();
    if (_resolvedStudentId == null) {
      final idStr = await session.getStudentId();
      _resolvedStudentId = int.tryParse(idStr ?? '') ?? 1;
    }
    if (_resolvedStudentName.isEmpty) {
      _resolvedStudentName = await session.getStudentName() ?? 'Élève';
    }
    if (_resolvedStudentClass.isEmpty) {
      _resolvedStudentClass = await session.getStudentClass() ?? 'Terminale';
    }
  }

  void _updatePrompts() {
    final prompts = _langConfig[_selectedLanguage]?['prompts'] as List<String>? ?? [];
    setState(() {
      _suggestedQuestions = prompts;
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _sendQuery(String queryText) async {
    final q = queryText.trim();
    if (q.isEmpty) return;

    setState(() {
      _isLoading = true;
      _lastQuery = q;
      _lastResponse = null;
      _isListening = false;
    });

    try {
      final res = await _aiRepo.askVoiceAssistant(
        query: q,
        language: _selectedLanguage,
        studentId: _resolvedStudentId,
        studentName: _resolvedStudentName,
        studentClass: _resolvedStudentClass,
      );

      if (mounted) {
        setState(() {
          _lastResponse = res?['response'] ?? 'Babu amsa a yanzu.';
          if (res?['suggestedNextQuestions'] != null) {
            _suggestedQuestions = List<String>.from(res!['suggestedNextQuestions']);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResponse = "Erreur de connexion avec l'assistant vocal.";
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMic() {
    if (_isListening) {
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      // Simulate speech-to-text trigger
      Timer(const Duration(milliseconds: 1200), () {
        if (mounted && _isListening) {
          final sample = _suggestedQuestions.isNotEmpty
              ? _suggestedQuestions.first
              : (_selectedLanguage == 'HA' ? 'Ina motar makaranta take?' : 'Où est le bus scolaire ?');
          _queryController.text = sample;
          _sendQuery(sample);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentConfig = _langConfig[_selectedLanguage] ?? _langConfig['HA']!;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),

          // Header with AI Icon and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistant Vocal Edut AI 🎙️',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Hausa • Zarma • Français',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Language Selector Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: _langConfig.entries.map((entry) {
                final isSelected = _selectedLanguage == entry.key;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLanguage = entry.key;
                        _lastResponse = null;
                        _lastQuery = null;
                        _updatePrompts();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.value['name'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Response or Greeting Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _lastResponse != null ? const Color(0xFF4F46E5).withValues(alpha: 0.5) : const Color(0xFF334155),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lastQuery != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.account_circle, color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lastQuery!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                ],
                if (_isLoading)
                  const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8))),
                      SizedBox(width: 10),
                      Text('Ana bincike / Recherche en cours...', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13)),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastResponse ?? currentConfig['greeting'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Suggested Voice Prompts Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedQuestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final p = _suggestedQuestions[i];
                return ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFF475569)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    _queryController.text = p;
                    _sendQuery(p);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Glowing Wave & Mic Button
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    Container(
                      width: 80 * _waveAnimation.value,
                      height: 80 * _waveAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3 / _waveAnimation.value),
                      ),
                    ),
                  GestureDetector(
                    onTap: _toggleMic,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? const Color(0xFFEF4444) : const Color(0xFF4F46E5)).withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),
          Text(
            _isListening ? 'Ana saurare... (Écoute en cours)' : 'Danna domin yin magana (Appuyez pour parler)',
            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 16),

          // Manual Text Input Fallback
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: currentConfig['hint'] as String,
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                  onSubmitted: _sendQuery,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                onPressed: () => _sendQuery(_queryController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
