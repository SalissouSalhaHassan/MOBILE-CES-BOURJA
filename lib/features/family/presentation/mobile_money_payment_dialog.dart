import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/payment_gateway_service.dart';

class MobileMoneyPaymentDialog extends StatefulWidget {
  final int studentId;
  final String studentName;
  final double defaultAmount;
  final int? feeId;
  final Function(MobileMoneyPaymentResult result) onPaymentSuccess;

  const MobileMoneyPaymentDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.defaultAmount,
    this.feeId,
    required this.onPaymentSuccess,
  });

  @override
  State<MobileMoneyPaymentDialog> createState() => _MobileMoneyPaymentDialogState();
}

class _MobileMoneyPaymentDialogState extends State<MobileMoneyPaymentDialog> {
  final PaymentGatewayService _service = PaymentGatewayService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedProviderId = 'AIRTEL_MONEY';
  String _selectedProviderName = 'Airtel Money 🇳🇪';
  String _selectedUssd = '*155#';
  Color _selectedColor = const Color(0xFFDC2626);
  String _selectedPurpose = 'Scolarité';
  bool _isProcessing = false;
  MobileMoneyPaymentResult? _successResult;

  final List<Map<String, dynamic>> _providers = [
    {
      'id': 'AIRTEL_MONEY',
      'name': 'Airtel Money 🇳🇪',
      'sub': 'Paiement direct Airtel (*155#)',
      'ussd': '*155#',
      'color': const Color(0xFFDC2626),
      'icon': Icons.phone_android_rounded,
    },
    {
      'id': 'MOOV_MONEY',
      'name': 'Moov / Flooz 🇳🇪',
      'sub': 'Moov Money Niger (*156#)',
      'ussd': '*156#',
      'color': const Color(0xFF0284C7),
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'id': 'WAVE',
      'name': 'Wave Mobile 🌊',
      'sub': 'Transfert direct sans frais',
      'ussd': 'In-App',
      'color': const Color(0xFF1E40AF),
      'icon': Icons.waves_rounded,
    },
    {
      'id': 'ORANGE_MONEY',
      'name': 'Orange Money 🌍',
      'sub': 'Portefeuille Orange (*144#)',
      'ussd': '*144#',
      'color': const Color(0xFFEA580C),
      'icon': Icons.toll_rounded,
    },
    {
      'id': 'AL_IZZA',
      'name': 'Al-Izza / Nita 🇳🇪',
      'sub': 'Transfert express national (*800#)',
      'ussd': '*800#',
      'color': const Color(0xFF059669),
      'icon': Icons.local_convenience_store_rounded,
    },
    {
      'id': 'BANK_CARD',
      'name': 'Carte Bancaire 💳',
      'sub': 'Visa / Mastercard 3D-Secure',
      'ussd': '3D Secure',
      'color': const Color(0xFF4F46E5),
      'icon': Icons.credit_card_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.defaultAmount > 0
        ? widget.defaultAmount.toStringAsFixed(0)
        : '25000';
    _phoneController.text = '90123456';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide supérieur à 0 FCFA.')),
      );
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre numéro de téléphone pour le débit.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _service.executeMobileMoneyPayment(
        studentId: widget.studentId,
        amount: amount,
        providerId: _selectedProviderId,
        providerName: _selectedProviderName,
        phoneNumber: _phoneController.text.trim(),
        purpose: _selectedPurpose,
        feeId: widget.feeId,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _successResult = result;
        });
        widget.onPaymentSuccess(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du paiement: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: _successResult != null
              ? _buildSuccessView()
              : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.payments_rounded, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paiement Mobile Money',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      widget.studentName,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Provider Selector
        const Text(
          '1. Choisissez votre opérateur Mobile Money',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemCount: _providers.length,
          itemBuilder: (ctx, idx) {
            final p = _providers[idx];
            final isSelected = _selectedProviderId == p['id'];
            final color = p['color'] as Color;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedProviderId = p['id'];
                  _selectedProviderName = p['name'];
                  _selectedUssd = p['ussd'];
                  _selectedColor = color;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(p['icon'] as IconData, size: 20, color: isSelected ? color : const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p['name'],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? color : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p['ussd'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? color.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Purpose Dropdown
        const Text(
          '2. Motif du paiement',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedPurpose,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(value: 'Scolarité', child: Text('Frais de Scolarité / Mensualités', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'COGES', child: Text('Cotisation Annuelle COGES', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'Inscription', child: Text('Frais d\'Inscription & Réinscription', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'Autre', child: Text('Cantine, Transport & Activités', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedPurpose = val);
          },
        ),
        const SizedBox(height: 16),

        // Amount Field & Quick chips
        const Text(
          '3. Montant à verser (FCFA)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.money_rounded, color: Color(0xFF0F766E)),
            suffixText: 'FCFA',
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 8),

        // Quick amount chips
        Wrap(
          spacing: 6,
          children: [10000, 25000, 50000, 100000].map((amt) {
            return ActionChip(
              label: Text('${(amt / 1000).toStringAsFixed(0)}k FCFA', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: () => setState(() => _amountController.text = amt.toString()),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Phone Field
        const Text(
          '4. Numéro de téléphone Mobile Money',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF0F766E)),
            hintText: 'Ex: 90 12 34 56 ou 80 12 34 56',
            helperText: 'Vous recevrez une invite USSD ($_selectedUssd) sur votre téléphone pour valider le code secret.',
            helperMaxLines: 2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 22),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isProcessing ? null : _processPayment,
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Traitement du paiement en cours...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Payer ${_amountController.text} FCFA via $_selectedProviderName',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final res = _successResult!;
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(res.timestamp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFFD1FAE5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 44),
        ),
        const SizedBox(height: 12),
        const Text(
          'Paiement Validé & Quittance Émise !',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          res.message ?? 'Votre transaction a été enregistrée avec succès.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(height: 16),

        // QR Code Container for Digital Verification
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              QrImageView(
                data: res.qrVerificationData.isNotEmpty
                    ? res.qrVerificationData
                    : 'EDUT|REF:${res.reference}|REC:${res.receiptNumber}|AMT:${res.amount}',
                version: QrVersions.auto,
                size: 110,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 6),
              const Text(
                'Scannez pour vérifier l\'authenticité de la quittance',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Receipt Details Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _receiptRow('N° Quittance:', res.receiptNumber),
              const Divider(height: 12),
              _receiptRow('Réf. Transaction:', res.reference),
              const Divider(height: 12),
              _receiptRow('Montant Réglé:', '${res.amount.toStringAsFixed(0)} FCFA', isHighlight: true),
              const Divider(height: 12),
              _receiptRow('Opérateur:', res.providerName),
              const Divider(height: 12),
              _receiptRow('Motif:', res.purpose),
              const Divider(height: 12),
              _receiptRow('Date & Heure:', formattedDate),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PDF Receipt Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          onPressed: () => _printOfficialReceiptPdf(res, formattedDate),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF0F766E)),
          label: const Text('Télécharger Quittance Officielle PDF', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
        const SizedBox(height: 10),

        // Close Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer et Actualiser le Solde', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<void> _printOfficialReceiptPdf(MobileMoneyPaymentResult res, String formattedDate) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RÉPUBLIQUE DU NIGER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('MINISTÈRE DE L\'ÉDUCATION NATIONALE', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('COMPLEXE SCOLAIRE PRIVÉ EDUT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal800)),
                        pw.Text('Caisse Numérique & FinTech Mobile Money', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.teal800, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('QUITTANCE OFFICIELLE DE PAIEMENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.teal900)),
                          pw.Text('N° ${res.receiptNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.teal800)),
                          pw.Text('Réf: ${res.reference}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.teal800),
                pw.SizedBox(height: 10),

                // Payment Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Élève Bénéficiaire : ${widget.studentName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 3),
                          pw.Text('Motif / Rubrique : ${res.purpose}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 3),
                          pw.Text('Opérateur Mobile : ${res.providerName}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Date : $formattedDate', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('Statut : Payé & Validé', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.teal800)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // Amount Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.teal700, width: 1.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('MONTANT TOTAL PAYÉ :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.teal900)),
                      pw.Text('${res.amount.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.teal900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),

                // QR Code and Signature Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Vérification Numérique QR :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.SizedBox(height: 6),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: res.qrVerificationData.isNotEmpty
                              ? res.qrVerificationData
                              : 'EDUT|REF:${res.reference}|REC:${res.receiptNumber}|AMT:${res.amount}',
                          width: 70,
                          height: 70,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Pour la Direction & Caisse EDUT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          width: 100,
                          height: 40,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.teal700, style: pw.BorderStyle.dashed),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('[ Cachet Numérique M.Money ]', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.teal800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Quittance_Paiement_${res.receiptNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération reçu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
            fontSize: isHighlight ? 13.5 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
