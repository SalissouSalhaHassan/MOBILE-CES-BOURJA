import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/gate_security_repository.dart';

class GateScannerScreen extends StatefulWidget {
  const GateScannerScreen({super.key});

  @override
  State<GateScannerScreen> createState() => _GateScannerScreenState();
}

class _GateScannerScreenState extends State<GateScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final GateSecurityRepository _securityRepo = locator<GateSecurityRepository>();

  bool _isProcessing = false;
  bool _isFlashOn = false;
  late AnimationController _animController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final result = await _securityRepo.scanGatePass(
      qrPayload: rawValue,
      action: 'scan',
    );

    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      _showResultModal(result, rawValue);
    }
  }

  void _showResultModal(Map<String, dynamic> result, String rawPayload) {
    final bool isValid = result['valid'] == true;
    final String alertLevel = (result['alertLevel'] ?? 'green').toString();
    final student = result['student'] as Map<String, dynamic>?;
    final school = result['school'] as Map<String, dynamic>?;
    final hostelPerm = result['hostelPermission'] as Map<String, dynamic>?;

    Color badgeColor = AppColors.success;
    IconData badgeIcon = Icons.check_circle;
    String statusTitle = 'ACCÈS AUTORISÉ';

    if (alertLevel == 'yellow') {
      badgeColor = Colors.amber;
      badgeIcon = Icons.warning_rounded;
      statusTitle = 'ATTENTION • VÉRIFICATION';
    } else if (alertLevel == 'red' || !isValid) {
      badgeColor = const Color(0xFFE11D48);
      badgeIcon = Icons.cancel_rounded;
      statusTitle = 'ACCÈS BLOQUÉ / NON VALIDE';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          bool isSubmitting = false;

          Future<void> logMovement(String action) async {
            setModalState(() => isSubmitting = true);
            HapticFeedback.heavyImpact();

            final res = await _securityRepo.scanGatePass(
              qrPayload: rawPayload,
              action: action,
            );

            setModalState(() => isSubmitting = false);
            if (dialogCtx.mounted) {
              Navigator.pop(dialogCtx);
              final wa = res['whatsappAlert'] as Map<String, dynamic>?;
              final waLink = wa?['link']?.toString();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: action == 'entry' ? AppColors.success : const Color(0xFF6366F1),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  content: Row(
                    children: [
                      Icon(action == 'entry' ? Icons.login : Icons.logout, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          action == 'entry'
                              ? 'Entrée confirmée • ${student?['nom'] ?? 'Élève'}'
                              : 'Sortie confirmée • ${student?['nom'] ?? 'Élève'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  action: waLink != null
                      ? SnackBarAction(
                          label: 'Alerter WhatsApp',
                          textColor: const Color(0xFF4ADE80),
                          onPressed: () async {
                            final uri = Uri.parse(waLink);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        )
                      : null,
                ),
              );
            }
          }

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusTitle,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              result['decisionReason'] ?? (isValid ? (school?['name'] ?? 'Élève régulier') : 'Invalide'),
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (student != null) ...[
                  // Student Details Row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 64,
                          height: 74,
                          color: const Color(0xFF1E293B),
                          child: student['photoUrl'] != null && student['photoUrl'].toString().isNotEmpty
                              ? Image.network(
                                  student['photoUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white38, size: 36),
                                )
                              : const Icon(Icons.person, color: Colors.white38, size: 36),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['nom'] ?? 'Élève',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (student['nomArabe'] != null)
                              Text(
                                student['nomArabe'],
                                style: const TextStyle(color: Colors.indigoAccent, fontSize: 12),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Classe : ${student['classe'] ?? 'N/A'} • Matr: ${student['matricule'] ?? ''}',
                                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Régime : ${student['categorie'] ?? 'Externe'} • Sang : ${student['groupeSanguin'] ?? 'Inconnu'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hostel exit permission alert
                  if (hostelPerm != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hotel_outlined, color: Colors.indigoAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BON DE SORTIE INTERNAT VALIDÉ',
                                  style: TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Motif : ${hostelPerm['reason'] ?? 'Sortie'} (Retour prévu: ${hostelPerm['returnTime'] ?? 'Soir'})',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Action Buttons (Entry / Exit / Alert)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : () => logMovement('entry'),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Entrée'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : () => logMovement('exit'),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Sortie'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Not found fallback
                  Text(
                    result['message'] ?? 'Ce code QR n\'appartient à aucun élève de l\'établissement.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Scanner à nouveau'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        elevation: 0,
        title: const Text(
          'Taux de Contrôle & Portail Sécurité',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.amber : Colors.white70,
            ),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Dark Overlay with Cutout Target
          CustomPaint(
            size: Size.infinite,
            painter: ScannerOverlayPainter(),
          ),

          // Animated Scan Line
          AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (context, child) {
              final h = MediaQuery.of(context).size.height;
              final targetSize = MediaQuery.of(context).size.width * 0.72;
              final topOffset = (h - targetSize) / 2;

              return Positioned(
                top: topOffset + (_scanLineAnimation.value * targetSize),
                width: targetSize - 20,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Color(0xFF10B981), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Top helper guidance chip
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Pointez vers le QR de la carte d\'élève',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanSize = size.width * 0.72;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanSize,
      height: scanSize,
    );

    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final cutoutPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(cutoutPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final rrect = RRect.fromRectAndRadius(scanRect, const Radius.circular(20));
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
