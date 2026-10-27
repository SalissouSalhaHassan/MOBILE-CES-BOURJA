import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/ai_repository.dart';

class AiExamGraderScreen extends StatefulWidget {
  final int? initialExamId;
  final String? initialExamName;

  const AiExamGraderScreen({
    super.key,
    this.initialExamId,
    this.initialExamName,
  });

  @override
  State<AiExamGraderScreen> createState() => _AiExamGraderScreenState();
}

class _AiExamGraderScreenState extends State<AiExamGraderScreen> {
  final AiRepository _aiRepo = locator<AiRepository>();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  String? _imageBase64;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _isSaved = false;

  Map<String, dynamic>? _gradingResult;
  double _score = 0.0;
  double _maxMarks = 20.0;
  String _feedback = '';
  List<dynamic> _questions = [];
  List<String> _strengths = [];
  List<String> _weaknesses = [];

  final TextEditingController _answerKeyController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        setState(() {
          _imageFile = File(picked.path);
          _imageBase64 = base64Encode(bytes);
          _gradingResult = null;
          _isSaved = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'accéder à la caméra ou galerie: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _analyzeExam() async {
    if (_imageBase64 == null) return;

    setState(() {
      _isAnalyzing = true;
      _isSaved = false;
    });

    final result = await _aiRepo.gradeExamWithCamera(
      imageBase64: _imageBase64!,
      examId: widget.initialExamId,
      answerKey: _answerKeyController.text.trim().isNotEmpty
          ? _answerKeyController.text.trim()
          : null,
      maxMarks: _maxMarks,
    );

    setState(() {
      _isAnalyzing = false;
    });

    if (result != null) {
      setState(() {
        _gradingResult = result;
        _score = (result['totalScore'] as num?)?.toDouble() ?? 0.0;
        _maxMarks = (result['maxMarks'] as num?)?.toDouble() ?? 20.0;
        _feedback = result['feedback']?.toString() ?? '';
        _questions = (result['questions'] as List<dynamic>?) ?? [];
        _strengths = ((result['strengths'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList();
        _weaknesses = ((result['weaknesses'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList();
        if (result['detectedStudentName'] != null &&
            result['detectedStudentName'].toString().isNotEmpty) {
          _studentNameController.text = result['detectedStudentName'].toString();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'analyse par l\'IA. Veuillez réessayer.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveResult() async {
    if (widget.initialExamId == null && _gradingResult?['matchedStudentId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez associer un examen pour enregistrer la note.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final studentId = (_gradingResult?['matchedStudentId'] as num?)?.toInt() ?? 1;
    final examId = widget.initialExamId ?? 1;

    final success = await _aiRepo.saveGradedExamResult(
      examId: examId,
      studentId: studentId,
      marksObtained: _score,
      remarks: _feedback.isNotEmpty ? _feedback : 'Corrigé par IA Caméra',
      notifyParent: true,
    );

    setState(() {
      _isSaving = false;
      _isSaved = success;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Note enregistrée et notifiée au parent !'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'enregistrement de la note.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _editScoreDialog() {
    final controller = TextEditingController(text: _score.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la note'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Note sur $_maxMarks',
            suffixText: '/ $_maxMarks',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final newScore = double.tryParse(controller.text);
              if (newScore != null && newScore >= 0 && newScore <= _maxMarks) {
                setState(() {
                  _score = newScore;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.initialExamName ?? 'Correcteur IA Caméra',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exam Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF4338CA)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Correction Automatique par IA',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Photographiez la copie d\'examen manuscrite ou QCM',
                          style: AppTextStyles.caption.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Camera / Image Box
            if (_imageFile == null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Numériser une copie d\'élève',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Placez la feuille bien à plat et éclairée',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Appareil Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galerie'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else ...[
              // Image Preview with Retake option
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 240,
                      width: double.infinity,
                      color: Colors.black,
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Answer key optional input
              ExpansionTile(
                title: Text(
                  'Corrigé type / Barème spécifique (Optionnel)',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: TextField(
                      controller: _answerKeyController,
                      decoration: const InputDecoration(
                        hintText: 'Ex : 1: A, 2: C, 3: Vrai, 4: x=10',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Analyze Button
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeExam,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isAnalyzing ? 'Analyse par l\'IA en cours...' : 'Corriger la copie',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Results View
            if (_gradingResult != null) ...[
              // Score Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studentNameController.text.isNotEmpty
                                  ? _studentNameController.text
                                  : 'Élève Détecté',
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Évaluation Complète',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _editScoreDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _score >= (_maxMarks / 2)
                                  ? AppColors.success.withOpacity(0.12)
                                  : AppColors.error.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${_score.toStringAsFixed(1)} / ${_maxMarks.toInt()}',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _score >= (_maxMarks / 2)
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Feedback
                    if (_feedback.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.psychology, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _feedback,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Questions List
                    if (_questions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Détail des questions (${_questions.length})',
                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._questions.map((q) {
                        final isCorrect = q['isCorrect'] == true;
                        final qNum = q['questionNumber'] ?? '';
                        final awarded = q['scoreAwarded'] ?? 0;
                        final max = q['maxScore'] ?? 0;
                        final answer = q['detectedStudentAnswer'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? AppColors.success.withOpacity(0.05)
                                : AppColors.error.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCorrect
                                  ? AppColors.success.withOpacity(0.2)
                                  : AppColors.error.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Question $qNum',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Réponse élève: $answer',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+$awarded / $max',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 16),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _isSaving || _isSaved ? null : _saveResult,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(_isSaved ? Icons.check_circle : Icons.save),
                      label: Text(_isSaved ? 'Note Enregistrée' : 'Enregistrer dans le carnet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
