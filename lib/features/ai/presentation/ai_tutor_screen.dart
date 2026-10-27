import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/ai_repository.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final AiRepository _aiRepo = locator<AiRepository>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedSubject = 'Mathématiques';
  String _studentName = '';
  bool _isLoading = false;

  final List<String> _subjects = [
    'Mathématiques',
    'Physique-Chimie',
    'SVT / Sciences',
    'Français / Littérature',
    'Histoire-Géo',
    'Anglais',
    'Philosophie',
    'Informatique',
  ];

  final List<Map<String, String>> _quickPrompts = [
    {'subject': 'Mathématiques', 'text': 'Explique-moi le théorème de Thalès avec un exemple concret.'},
    {'subject': 'Physique-Chimie', 'text': 'Quelle est la différence entre masse et poids ?'},
    {'subject': 'SVT / Sciences', 'text': 'Comment fonctionne la photosynthèse chez les plantes ?'},
    {'subject': 'Français / Littérature', 'text': 'Donne-moi les règles d\'accord du participe passé avec avoir.'},
    {'subject': 'Histoire-Géo', 'text': 'Résume les causes principales de la Première Guerre Mondiale.'},
  ];

  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await locator<SessionManager>().getUserName() ?? 'Élève';
    setState(() {
      _studentName = name;
      _messages.add({
        'role': 'ai',
        'content': 'Bonjour **$_studentName** ! 👋\n\nJe suis ton **Tuteur IA Edut**. Choisis une matière ci-dessus ou pose-moi directement tes questions de cours, de calculs ou demande-moi des exercices d\'entraînement !',
        'time': DateTime.now(),
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    if (presetText == null) {
      _controller.clear();
    }

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });

    _scrollToBottom();

    final answer = await _aiRepo.askAiTutor(
      question: text,
      subject: _selectedSubject,
      studentName: _studentName,
    );

    if (mounted) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'content': answer,
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuteur IA Élève',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Assistance pédagogique 24/7',
                  style: TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Subject selector bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final s = _subjects[index];
                  final isSelected = s == _selectedSubject;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedSubject = s);
                      },
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.slate700,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble();
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageItem(msg['content'] as String, isUser);
              },
            ),
          ),

          // Quick prompts suggestions if chat is short
          if (_messages.length <= 3) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.transparent,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPrompts
                      .where((p) => p['subject'] == _selectedSubject || _messages.length == 1)
                      .map((prompt) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                              label: Text(
                                prompt['text']!,
                                style: const TextStyle(fontSize: 11, color: AppColors.slate700),
                              ),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onPressed: () => _sendMessage(prompt['text']),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Pose ta question en $_selectedSubject...',
                          hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(String content, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF6366F1) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
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
                  Text(
                    content,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.slate800,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Réponse copiée dans le presse-papier'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 12, color: AppColors.slate400),
                              SizedBox(width: 4),
                              Text('Copier', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE2E8F0),
              child: Icon(Icons.person, size: 16, color: AppColors.slate600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                ),
                SizedBox(width: 10),
                Text(
                  'Le tuteur IA réfléchit...',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
