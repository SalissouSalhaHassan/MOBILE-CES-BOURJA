import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class QcmScannerScreen extends StatefulWidget {
  final String subjectName;
  final String className;
  final String? studentName;

  const QcmScannerScreen({
    super.key,
    required this.subjectName,
    required this.className,
    this.studentName,
  });

  @override
  State<QcmScannerScreen> createState() => _QcmScannerScreenState();
}

class _QcmScannerScreenState extends State<QcmScannerScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final ImagePicker _picker = ImagePicker();

  bool _isScanning = false;
  bool _hasResult = false;
  Map<String, dynamic>? _scanResult;
  String? _selectedImagePath;

  Future<void> _scanBubbleSheet({bool fromCamera = true}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _selectedImagePath = image.path;
        _isScanning = true;
        _hasResult = false;
      });

      final res = await _apiClient.postJson('/api/mobile/ai/qcm-grader', {
        'totalQuestions': 20,
        'subjectName': widget.subjectName,
        'className': widget.className,
        'studentName': widget.studentName,
        'saveToDatabase': true,
        'notifyParent': true,
      });

      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _scanResult = Map<String, dynamic>.from(res['data']);
          _hasResult = true;
          _isScanning = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Note enregistrée dans le bulletin & Notification envoyée au parent !'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception(res['error'] ?? 'Échec de l\'analyse optique');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur du scan: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Correcteur Optique IA (QCM Grader)',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '${widget.subjectName} • ${widget.className}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Viewfinder / Header
          Expanded(
            flex: _hasResult ? 3 : 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF334155), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Grid Viewfinder Overlay
                  Container(
                    width: 260,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isScanning) ...[
                          const CircularProgressIndicator(color: Color(0xFF10B981)),
                          const SizedBox(height: 16),
                          const Text(
                            'Analyse optique des bulles...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ] else if (!_hasResult) ...[
                          const Icon(Icons.document_scanner_rounded, color: Color(0xFF10B981), size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Cadrez la feuille QCM',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Alignez les 4 coins de la grille',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ] else ...[
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Note : ${_scanResult!['scoreOn20']}/20',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          Text(
                            '${_scanResult!['correctCount']}/20 réponses correctes (${_scanResult!['percentage']}%)',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scan action triggers
          if (!_hasResult && !_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _scanBubbleSheet(fromCamera: true),
                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                      label: const Text('Scanner via Caméra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _scanBubbleSheet(fromCamera: false),
                    icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),

          // Result sheet details
          if (_hasResult && _scanResult != null)
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Détail par question (20 QCM)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context, _scanResult!['scoreOn20']);
                          },
                          icon: const Icon(Icons.save_alt_rounded, color: Colors.white, size: 16),
                          label: const Text('Injecter la note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: (_scanResult!['questions'] as List).length,
                        itemBuilder: (context, index) {
                          final q = _scanResult!['questions'][index];
                          final isCorr = q['isCorrect'] == true;
                          return Container(
                            decoration: BoxDecoration(
                              color: isCorr ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isCorr ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Q${q['questionNumber']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(
                                  '${q['studentAnswer']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCorr ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
