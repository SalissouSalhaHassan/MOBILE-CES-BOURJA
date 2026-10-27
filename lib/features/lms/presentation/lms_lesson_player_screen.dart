import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';

class LmsLessonPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final int? studentId;
  final int? courseId;

  const LmsLessonPlayerScreen({
    super.key,
    required this.lesson,
    this.studentId,
    this.courseId,
  });

  @override
  State<LmsLessonPlayerScreen> createState() => _LmsLessonPlayerScreenState();
}

class _LmsLessonPlayerScreenState extends State<LmsLessonPlayerScreen>
    with SingleTickerProviderStateMixin {
  final LmsRepository _repo = LmsRepository();
  late TabController _tabController;
  late TextEditingController _notesController;
  final TextEditingController _questionController = TextEditingController();

  bool _isCompleted = false;
  bool _isSaving = false;
  bool _isDownloadedOffline = false;
  bool _isPlaying = false;
  double _videoPosition = 0.35; // 35% default mockup
  double _playbackSpeed = 1.0;

  List<dynamic> _discussions = [];
  bool _isLoadingDiscussions = false;
  bool _isPostingQuestion = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _isCompleted = widget.lesson['isCompleted'] == true;
    _notesController = TextEditingController(
      text: widget.lesson['personalNotes']?.toString() ?? '',
    );
    _loadLessonDiscussions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadLessonDiscussions() async {
    setState(() => _isLoadingDiscussions = true);
    final list = await _repo.getDiscussions(
      lessonId: widget.lesson['id'],
      courseId: widget.courseId ?? widget.lesson['courseId'],
    );
    if (mounted) {
      setState(() {
        _isLoadingDiscussions = false;
        _discussions = list;
      });
    }
  }

  Future<void> _postQuestion() async {
    final msg = _questionController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isPostingQuestion = true);
    final success = await _repo.postDiscussion(
      message: msg,
      lessonId: widget.lesson['id'],
      courseId: widget.courseId ?? widget.lesson['courseId'],
      studentId: widget.studentId,
    );

    if (mounted) {
      setState(() => _isPostingQuestion = false);
      if (success) {
        _questionController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Question posée avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLessonDiscussions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi de la question'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleCompleted() async {
    setState(() => _isSaving = true);
    final nextState = !_isCompleted;
    final success = await _repo.saveLessonProgress(
      lessonId: widget.lesson['id'],
      studentId: widget.studentId,
      isCompleted: nextState,
      personalNotes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isCompleted = nextState;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextState ? '🎉 Bravo ! Leçon validée avec succès !' : 'Leçon marquée comme non terminée',
            ),
            backgroundColor: nextState ? AppColors.success : AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _saveNotes() async {
    final success = await _repo.saveLessonProgress(
      lessonId: widget.lesson['id'],
      studentId: widget.studentId,
      isCompleted: _isCompleted,
      personalNotes: _notesController.text.trim(),
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 Notes personnelles sauvegardées'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleDownload() {
    setState(() {
      _isDownloadedOffline = !_isDownloadedOffline;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isDownloadedOffline
              ? '📥 Leçon & cours enregistrés pour consultation hors-ligne !'
              : '🗑️ Fichiers locaux supprimés',
        ),
      ),
    );
  }

  Future<void> _openExternalVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la vidéo externe')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lesson['title']?.toString() ?? 'Leçon';
    final contentType = widget.lesson['contentType']?.toString() ?? 'Text';
    final videoUrl = widget.lesson['videoUrl']?.toString();
    final duration = widget.lesson['duration'] ?? 15;
    final isVideo = contentType == 'Video' || videoUrl != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDownloadedOffline ? Icons.download_done_rounded : Icons.download_rounded,
              color: _isDownloadedOffline ? AppColors.success : AppColors.textSecondary,
            ),
            tooltip: 'Télécharger pour consultation hors-ligne',
            onPressed: _toggleDownload,
          ),
        ],
      ),
      body: Column(
        children: [
          // Media Player Section
          if (isVideo)
            _buildVideoPlayerSection(duration, videoUrl)
          else
            _buildAudioOrTextHeaderSection(title, duration),

          // Tabs navigation
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.slate500,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: [
                const Tab(icon: Icon(Icons.article_rounded, size: 18), text: 'Contenu'),
                const Tab(icon: Icon(Icons.folder_shared_rounded, size: 18), text: 'Supports'),
                Tab(
                  icon: const Icon(Icons.forum_rounded, size: 18),
                  text: 'Q&A (${_discussions.length})',
                ),
                const Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Mes Notes'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(),
                _buildResourcesTab(),
                _buildDiscussionsTab(),
                _buildNotesTab(),
              ],
            ),
          ),

          // Bottom Bar for Lesson Completion
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _toggleCompleted,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(_isCompleted ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded),
                label: Text(
                  _isCompleted
                      ? 'Leçon Validée (Cliquer pour annuler)'
                      : 'Valider et Marquer comme Terminée',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCompleted ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerSection(int duration, String? videoUrl) {
    return Container(
      color: Colors.black,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Gradient / Thumbnail
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Center Play / Pause
          IconButton(
            iconSize: 58,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: Colors.white.withOpacity(0.9),
            ),
            onPressed: () {
              setState(() => _isPlaying = !_isPlaying);
            },
          ),

          // External Video Link if available
          if (videoUrl != null && videoUrl.isNotEmpty)
            Positioned(
              top: 10,
              right: 12,
              child: InkWell(
                onTap: () => _openExternalVideo(videoUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Ouvrir la source',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Scrubber & Controls Bar at Bottom
          Positioned(
            bottom: 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    value: _videoPosition,
                    onChanged: (v) => setState(() => _videoPosition = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Text(
                        '${((_videoPosition * duration).toInt()).toString().padLeft(2, '0')}:00',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Text(' / ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Text(
                        '${duration.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Spacer(),
                      // Speed toggle
                      PopupMenuButton<double>(
                        initialValue: _playbackSpeed,
                        onSelected: (speed) => setState(() => _playbackSpeed = speed),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                          const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                          const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                          const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOrTextHeaderSection(String title, int duration) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
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
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Durée estimée : $duration minutes',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- TAB 1: CONTENU --------------------
  Widget _buildContentTab() {
    final rawContent = widget.lesson['content']?.toString() ??
        'Bienvenue dans cette leçon. Lisez attentivement les explications fournies par votre enseignant ci-dessous.';
    // Clean basic html tags for clear mobile reading
    final cleanContent = rawContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Objectifs & Notions Clés',
                    style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                cleanContent,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.7,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------- TAB 2: SUPPORTS & DOCUMENTS --------------------
  Widget _buildResourcesTab() {
    final filePath = widget.lesson['filePath']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (filePath != null && filePath.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Document de cours (PDF)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        filePath.split('/').last,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                  onPressed: () => _openExternalVideo(filePath),
                  tooltip: 'Télécharger le support',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Sample resources / Guide cards
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_outlined, color: AppColors.success, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiche de révision & Synthèse',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Synthèse téléchargeable pour vos révisions',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, color: AppColors.success, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------- TAB 3: FORUM Q&A --------------------
  Widget _buildDiscussionsTab() {
    return Column(
      children: [
        // Question Input Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: 'Posez une question sur cette leçon...',
                    filled: true,
                    fillColor: AppColors.slate100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: _isPostingQuestion
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                onPressed: _isPostingQuestion ? null : _postQuestion,
              ),
            ],
          ),
        ),

        // List of discussions
        Expanded(
          child: _isLoadingDiscussions
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _discussions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.forum_outlined, size: 48, color: AppColors.slate400),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune question pour l\'instant',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Soyez le premier à poser une question au professeur !',
                              style: TextStyle(color: AppColors.slate500, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _discussions.length,
                      itemBuilder: (context, index) {
                        final d = _discussions[index];
                        final isTeacher = d['isTeacher'] == true;
                        final author = d['authorName'] ?? 'Anonyme';
                        final msg = d['message'] ?? '';
                        final dateStr = d['createdAt'] != null
                            ? DateTime.tryParse(d['createdAt'])
                                    ?.toLocal()
                                    .toString()
                                    .split(' ')
                                    .first ??
                                ''
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isTeacher ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isTeacher ? AppColors.primary.withOpacity(0.3) : Colors.black12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isTeacher ? AppColors.primary : AppColors.slate300,
                                    child: Text(
                                      author.isNotEmpty ? author[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
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
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                msg,
                                style: const TextStyle(fontSize: 13, height: 1.4),
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

  // -------------------- TAB 4: MES NOTES --------------------
  Widget _buildNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Notes de révision personnelles',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _saveNotes,
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Sauvegarder'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Notez ici vos points clés, formules et rappels personnels pour cette leçon...',
                  filled: true,
                  fillColor: AppColors.slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
