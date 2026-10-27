import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/educational_level_helper.dart';

class JournalDeCaissePdfGenerator {
  static Future<Uint8List> generatePdfBytes({
    required List<Map<String, dynamic>> payments,
    required double totalCollected,
    required double totalReductions,
    required double totalExpected,
    required String periodOrFilterDesc,
    String? levelFilter,
    String? classFilter,
    String? cashierFilter,
    Map<String, dynamic>? headerConfig,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();
    final isA5 = pageFormat == PdfPageFormat.a5;

    // Load custom fonts to support Arabic/Unicode text with offline fallback
    pw.Font amiriFont;
    pw.Font amiriBold;
    try {
      amiriFont = await PdfGoogleFonts.amiriRegular().timeout(const Duration(seconds: 2));
      amiriBold = await PdfGoogleFonts.amiriBold().timeout(const Duration(seconds: 2));
    } catch (_) {
      amiriFont = pw.Font.helvetica();
      amiriBold = pw.Font.helveticaBold();
    }
    final currencyFmt = NumberFormat('#,##0', 'fr_FR');

    final effectiveLevel = (levelFilter != null && levelFilter != 'Tous')
        ? levelFilter
        : (classFilter != null && classFilter != 'Tous')
            ? classFilter
            : null;

    final stage = EducationalLevelHelper.inferEducationalStage(
      educationalLevel: effectiveLevel,
      className: effectiveLevel,
    );

    final resolvedHeader = EducationalLevelHelper.getActiveLevelHeaderConfig(
      headerConfig,
      targetLevel: effectiveLevel,
    );

    // Decode Logos
    pw.MemoryImage? centerLogoImage;
    final logoSource = resolvedHeader['centerLogo'] ??
        resolvedHeader['leftLogo'] ??
        resolvedHeader['customLogo'] ??
        resolvedHeader['logoPath'] ??
        headerConfig?['centerLogo'] ??
        headerConfig?['leftLogo'];
    if (logoSource != null && logoSource.toString().startsWith('data:image/')) {
      try {
        final base64Str = logoSource.toString().split(',').last;
        centerLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (e) {
        debugPrint("Error decoding journal logo: $e");
      }
    }

    const darkNavy = PdfColor.fromInt(0xFF0F172A);
    const primaryIndigo = PdfColor.fromInt(0xFF4F46E5);
    const emeraldGreen = PdfColor.fromInt(0xFF059669);
    const greyColor = PdfColor.fromInt(0xFF64748B);
    const lightBorder = PdfColor.fromInt(0xFFE2E8F0);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);

    final country = resolvedHeader['country']?.toString() ?? 'RÉPUBLIQUE DU NIGER';
    final ministry = resolvedHeader['ministry']?.toString() ??
        EducationalLevelHelper.getDefaultMinistry(stage, isArabic: false);
    final school = resolvedHeader['schoolName']?.toString() ??
        (stage == EducationalStage.universite ? 'UNIVERSITÉ EXCELLENCE' : 'ÉCOLE EXCELLENCE');
    final service = resolvedHeader['service']?.toString() ??
        EducationalLevelHelper.getDefaultService(stage, isArabic: false);
    final phone = resolvedHeader['phone']?.toString() ??
        resolvedHeader['schoolPhone']?.toString() ??
        '+227 90 12 34 56';
    final email = resolvedHeader['email']?.toString() ??
        resolvedHeader['schoolEmail']?.toString() ??
        'contact@edutacademy.ne';

    final countryAr = resolvedHeader['countryAr']?.toString() ?? 'جمهورية النيجر';
    final ministryAr = resolvedHeader['ministryAr']?.toString() ??
        EducationalLevelHelper.getDefaultMinistry(stage, isArabic: true);
    final schoolAr = resolvedHeader['schoolNameAr']?.toString() ?? school;

    final datePrinted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Multi-page document support
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(isA5 ? 16 : 24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Top Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: French
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(country, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: darkNavy)),
                        pw.Text(ministry, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 7, color: greyColor)),
                        pw.SizedBox(height: 1),
                        pw.Text(school, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy)),
                        if (service.isNotEmpty)
                          pw.Text(service, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor)),
                        pw.Text('Tél: $phone | Email: $email', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                      ],
                    ),
                  ),

                  // Center Logo
                  if (centerLogoImage != null)
                    pw.Container(
                      margin: pw.EdgeInsets.symmetric(horizontal: isA5 ? 6 : 10),
                      width: isA5 ? 36 : 46,
                      height: isA5 ? 36 : 46,
                      child: pw.Image(centerLogoImage),
                    )
                  else
                    pw.Container(width: isA5 ? 36 : 46, height: isA5 ? 36 : 46),

                  // Right: Arabic
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(countryAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: darkNavy)),
                        pw.Text(ministryAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 7, color: greyColor)),
                        pw.SizedBox(height: 1),
                        pw.Text(schoolAr, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: isA5 ? 5 : 8),

              // Title Banner: JOURNAL DE CAISSE
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 8 : 12, vertical: isA5 ? 5 : 7),
                decoration: const pw.BoxDecoration(
                  color: darkNavy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'JOURNAL DE CAISSE — ENCAISSEMENTS',
                          style: pw.TextStyle(
                            font: amiriBold,
                            fontSize: isA5 ? 9 : 11,
                            color: PdfColors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.Text(
                          'Historique chronologique détaillé de tous les encaissements',
                          style: pw.TextStyle(
                            font: amiriFont,
                            fontSize: isA5 ? 5.5 : 6.5,
                            color: const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 6 : 8, vertical: isA5 ? 2 : 3),
                      decoration: const pw.BoxDecoration(
                        color: primaryIndigo,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Text(
                        'OFFICIEL',
                        style: pw.TextStyle(
                          font: amiriBold,
                          fontSize: isA5 ? 5.5 : 7,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              // Sub-info bar (Filters & Print date)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  border: pw.Border.all(color: lightBorder),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Filtres : $periodOrFilterDesc',
                      style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6.5, color: darkNavy),
                    ),
                    pw.Text(
                      'Édité le : $datePrinted',
                      style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6.5, color: greyColor),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (context) {
          final recoveryRate = totalExpected > 0
              ? ((totalCollected / totalExpected) * 100).toStringAsFixed(1)
              : '0.0';

          return [
            // KPI Summary Row (Matching the web cards)
            pw.Row(
              children: [
                _buildKpiPdfCard(
                  label: 'ENCAISSÉ FILTRÉ',
                  value: '${currencyFmt.format(totalCollected)} CFA',
                  color: emeraldGreen,
                  amiriBold: amiriBold,
                  isA5: isA5,
                ),
                pw.SizedBox(width: 6),
                _buildKpiPdfCard(
                  label: 'REMISES FILTRÉES',
                  value: '${currencyFmt.format(totalReductions)} CFA',
                  color: const PdfColor.fromInt(0xFFF59E0B),
                  amiriBold: amiriBold,
                  isA5: isA5,
                ),
                pw.SizedBox(width: 6),
                _buildKpiPdfCard(
                  label: 'TRANSACTIONS',
                  value: '${payments.length}',
                  color: primaryIndigo,
                  amiriBold: amiriBold,
                  isA5: isA5,
                ),
                pw.SizedBox(width: 6),
                _buildKpiPdfCard(
                  label: 'RECOUVREMENT',
                  value: '$recoveryRate %',
                  color: darkNavy,
                  amiriBold: amiriBold,
                  isA5: isA5,
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Transactions Table
            if (payments.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Aucune transaction enregistrée avec ces filtres.',
                  style: pw.TextStyle(font: amiriFont, fontSize: 8, color: greyColor),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: [
                  'N°',
                  'Date',
                  'Référence',
                  'Élève',
                  'Classe',
                  'Mode',
                  'Caissier',
                  'Montant (CFA)',
                ],
                data: payments.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final p = entry.value;
                  final pDate = p['date_paid'] != null
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date_paid'].toString()))
                      : '-';
                  final pRef = p['reference']?.toString() ?? 'REC-${p['id']}';
                  final pStudent = p['student_name']?.toString() ?? p['nom_etudiant']?.toString() ?? 'Élève';
                  final pClass = p['classe']?.toString() ?? '-';
                  final pMode = p['payment_mode']?.toString() ?? 'Espèces';
                  final pRecordedBy = p['recorded_by']?.toString() ?? 'Admin';
                  final pAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;

                  return [
                    '$idx',
                    pDate,
                    pRef,
                    pStudent,
                    pClass,
                    pMode,
                    pRecordedBy,
                    currencyFmt.format(pAmount),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: darkNavy),
                cellStyle: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 7),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.centerRight,
                },
                headerAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.centerRight,
                },
                cellPadding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 3 : 5, vertical: isA5 ? 2.5 : 3.5),
              ),

            // Table Footer (Total Encaissé)
            if (payments.isNotEmpty)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightBorder),
                  color: lightBg,
                ),
                padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 6 : 8, vertical: isA5 ? 3 : 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL ENCAISSÉ FILTRÉ :', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: darkNavy)),
                    pw.Text('${currencyFmt.format(totalCollected)} CFA', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: emeraldGreen)),
                  ],
                ),
              ),

            pw.SizedBox(height: 14),

            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Le Caissier / Agent Comptable', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5)),
                    pw.SizedBox(height: 24),
                    pw.Text('(Signature)', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Le Chef des Services Financiers', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5)),
                    pw.SizedBox(height: 24),
                    pw.Text('(Visa & Cachet)', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('La Direction Générale', style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5)),
                    pw.SizedBox(height: 24),
                    pw.Text('(Sceau Officiel)', style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  ],
                ),
              ],
            ),
          ];
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} sur ${context.pagesCount} — Edut Pro Mobile',
              style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiPdfCard({
    required String label,
    required String value,
    required PdfColor color,
    required pw.Font amiriBold,
    required bool isA5,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 4 : 6, vertical: isA5 ? 3 : 5),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: amiriBold,
                fontSize: isA5 ? 4.5 : 5.5,
                color: const PdfColor.fromInt(0xFF64748B),
              ),
            ),
            pw.SizedBox(height: 1.5),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: amiriBold,
                fontSize: isA5 ? 6.5 : 8,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
