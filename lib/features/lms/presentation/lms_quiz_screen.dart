import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/lms_repository.dart';
import 'widgets/lms_certificate_pdf_generator.dart';

class LmsQuizScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final int? studentId;
  final String? studentName;

  const LmsQuizScreen({
    super.key,
    required this.quiz,
    this.studentId,
    this.studentName,
  });

  @override
  State<LmsQuizScreen> createState() => _LmsQuizScreenState();
}

class _LmsQuizScreenState extends State<LmsQuizScreen> {
  final LmsRepository _repo = LmsRepository();

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // questionId -> answerId
  bool _isSubmitting = false;
  Map<String, dynamic>? _quizResult;

  int _remainingSeconds = 1200; // 20 minutes default
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final duration = widget.quiz['durationMin'] ?? 20;
    _remainingSeconds = duration * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitQuiz();
      }
    });
  }

  void _confirmSubmit() {
    final questions = (widget.quiz['questions'] as List<dynamic>?) ?? [];
    final unanswered = questions.length - _selectedAnswers.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Soumettre l\'évaluation ?'),
        content: Text(
          unanswered > 0
              ? 'Attention, il vous reste $unanswered question(s) sans réponse. Voulez-vous vraiment terminer et envoyer vos réponses maintenant ?'
              : 'Toutes les questions ont été répondues. Prêt à soumettre pour obtenir votre note et attestation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vérifier mes réponses'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitQuiz();
            },
            child: const Text('Confirmer l\'envoi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _quizResult != null) return;
    _timer?.cancel();
    setState(() => _isSubmitting = true);

    final res = await _repo.submitQuiz(
      quizId: widget.quiz['id'],
      answers: _selectedAnswers,
      studentId: widget.studentId,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _quizResult = res;
      });
    }
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.quiz['title']?.toString() ?? 'Évaluation';
    final questions = (widget.quiz['questions'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (_quizResult == null) {
              _confirmExit();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_quizResult == null)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300
                    ? AppColors.error.withOpacity(0.15)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _remainingSeconds < 300 ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _remainingSeconds < 300 ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Correction et calcul des résultats en cours...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : _quizResult != null
              ? _buildResultsView()
              : questions.isEmpty
                  ? const Center(child: Text('Aucune question disponible dans ce quiz.'))
                  : _buildQuizQuestionsView(questions),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le quiz ?'),
        content: const Text('Si vous quittez maintenant, vos réponses en cours ne seront pas enregistrées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuer le test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Quitter', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizQuestionsView(List<dynamic> questions) {
    final q = questions[_currentQuestionIndex];
    final qId = q['id'];
    final qText = q['questionText']?.toString() ?? 'Question';
    final answers = (q['answers'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Navigation Pills
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: questions.length,
              itemBuilder: (context, idx) {
                final targetQId = questions[idx]['id'];
                final isAnswered = _selectedAnswers.containsKey(targetQId);
                final isCurrent = idx == _currentQuestionIndex;

                return GestureDetector(
                  onTap: () => setState(() => _currentQuestionIndex = idx),
                  child: Container(
                    width: 38,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary
                          : isAnswered
                              ? AppColors.success.withOpacity(0.15)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary
                            : isAnswered
                                ? AppColors.success
                                : Colors.black12,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? Colors.white
                              : isAnswered
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Progress indicator
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            backgroundColor: const Color(0xFFE2E8F0),
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),

          // Question Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} / ${questions.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${q['points'] ?? 2.0} pts',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  qText,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Answer Choices List
          Expanded(
            child: ListView.builder(
              itemCount: answers.length,
              itemBuilder: (context, index) {
                final ans = answers[index];
                final ansId = ans['id'];
                final ansText = ans['answerText']?.toString() ?? '';
                final isSelected = _selectedAnswers[qId] == ansId;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAnswers[qId] = ansId;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.black12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ansText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation buttons
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _currentQuestionIndex--);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Précédent'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentQuestionIndex < questions.length - 1
                      ? () {
                          setState(() => _currentQuestionIndex++);
                        }
                      : _confirmSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentQuestionIndex < questions.length - 1 ? 'Suivant' : 'Terminer & Valider',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final isPassed = _quizResult?['isPassed'] == true;
    final percentage = _quizResult?['percentage'] ?? 0;
    final scoreOn20 = _quizResult?['scoreOn20'] ?? 0.0;
    final certCode = _quizResult?['certificateCode']?.toString();
    final quizTitle = _quizResult?['quizTitle']?.toString() ?? widget.quiz['title'] ?? 'Formation';
    final breakdown = (_quizResult?['questions'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trophy / Result Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPassed
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  isPassed ? Icons.emoji_events_rounded : Icons.cancel_rounded,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  isPassed ? 'Félicitations ! Vous avez réussi !' : 'Score insuffisant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '$scoreOn20 / 20 ($percentage%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (certCode != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🎓 Certificat débloqué : $certCode',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Button to download / print PDF certificate directly
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text(
                      'Télécharger mon Certificat (PDF)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      LmsCertificatePdfGenerator.printCertificate(
                        studentName: widget.studentName ?? 'Élève Edut',
                        courseTitle: quizTitle,
                        certificateCode: certCode,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Question Breakdown
          Text(
            'Détail des Réponses & Corrections',
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...breakdown.map((item) {
            final isCorrect = item['isCorrect'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCorrect ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['questionText']?.toString() ?? 'Question',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        if (!isCorrect && item['correctAnswerText'] != null)
                          Text(
                            'Bonne réponse : ${item['correctAnswerText']}',
                            style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        if (item['explanation'] != null && item['explanation'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Explication : ${item['explanation']}',
                              style: const TextStyle(color: AppColors.slate600, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Terminer et Retourner au cours'),
          ),
        ],
      ),
    );
  }
}
