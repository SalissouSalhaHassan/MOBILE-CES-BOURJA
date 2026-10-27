import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ReceiptQrDialog extends StatelessWidget {
  final Map<String, dynamic> payment;
  final String studentName;
  final String? matricule;

  const ReceiptQrDialog({
    super.key,
    required this.payment,
    required this.studentName,
    this.matricule,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> payment,
    required String studentName,
    String? matricule,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ReceiptQrDialog(
        payment: payment,
        studentName: studentName,
        matricule: matricule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final refRaw = payment['reference']?.toString().trim();
    final pId = payment['id'];
    final reference = (refRaw != null && refRaw.isNotEmpty)
        ? refRaw
        : (pId != null
            ? 'REC-$pId'
            : 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    final paymentMode = payment['payment_mode']?.toString() ?? payment['paymentMode']?.toString() ?? 'Espèces / Mobile Money';
    final month = payment['month_concerned']?.toString() ?? payment['monthConcerned']?.toString() ?? 'Frais de scolarité';
    final date = payment['date_paid']?.toString() ?? payment['datePaid']?.toString() ?? DateTime.now().toIso8601String();

    final verifyUrl = '${MobileApiConfig.baseUrl}/verify?type=recu&ref=$reference';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Certified Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'REÇU OFFICIEL CERTIFIÉ',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Amount Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'MONTANT ENCAISSÉ',
                    style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${amount.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: QrImageView(
                data: verifyUrl,
                version: QrVersions.auto,
                size: 160.0,
              ),
            ),
            const SizedBox(height: 14),

            // Details
            Text(
              studentName,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'Réf: $reference • $month',
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'Reçu officiel Edut pour $studentName : $amount FCFA ($month). Vérification : $verifyUrl',
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Partager'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
