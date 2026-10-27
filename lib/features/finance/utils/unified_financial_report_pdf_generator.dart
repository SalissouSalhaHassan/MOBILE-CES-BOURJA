import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/educational_level_helper.dart';

class UnifiedFinancialReportPdfGenerator {
  /// Format CFA amount with dots as thousands separator (e.g. 10.000 CFA)
  static String formatCfa(num amount) {
    final rounded = amount.round();
    final str = rounded.abs().toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    final prefix = rounded < 0 ? '-' : '';
    return '$prefix${buffer.toString()} CFA';
  }

  static String getPeriodLabel(String period, DateTime selectedDate) {
    final d = selectedDate;
    if (period == "daily") {
      final formatted = DateFormat('dd/MM/yyyy').format(d);
      return 'Bilan Journalier du $formatted';
    }
    if (period == "monthly") {
      final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(d);
      final cap = monthName.isNotEmpty
          ? monthName[0].toUpperCase() + monthName.substring(1)
          : monthName;
      return 'Bilan Mensuel — $cap';
    }
    if (period == "yearly") {
      return 'Bilan Annuel (${d.year})';
    }
    return 'Bilan Global Consolidé (Toutes périodes)';
  }

  static Future<Uint8List> generatePdfBytes({
    required Map<String, dynamic> report,
    required String period,
    required DateTime selectedDate,
    Map<String, dynamic>? headerConfig,
    String? sessionName,
    String? targetLevel,
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

    // Determine effective target level: if targetLevel is provided and specific use it,
    // otherwise attempt to detect level from the first recent payments or classes in the report
    String? effectiveTargetLevel = (targetLevel != null &&
            !EducationalLevelHelper.hasAllEducationalLevels(targetLevel))
        ? targetLevel
        : null;

    if (effectiveTargetLevel == null) {
      final recentPayments = (report['recentPayments'] as List?) ?? [];
      for (final p in recentPayments) {
        if (p is Map) {
          final pLvl = p['educational_level']?.toString() ??
              p['educationalLevel']?.toString() ??
              p['niveau']?.toString();
          if (pLvl != null &&
              pLvl.trim().isNotEmpty &&
              !EducationalLevelHelper.hasAllEducationalLevels(pLvl)) {
            effectiveTargetLevel = pLvl;
            break;
          }
          final pCls = p['classe']?.toString();
          if (pCls != null && pCls.trim().isNotEmpty && pCls != '-') {
            effectiveTargetLevel = pCls;
            break;
          }
        }
      }
    }

    final stage = EducationalLevelHelper.inferEducationalStage(
      educationalLevel: effectiveTargetLevel,
      className: effectiveTargetLevel,
    );

    final resolvedHeader = EducationalLevelHelper.getActiveLevelHeaderConfig(
      headerConfig,
      targetLevel: effectiveTargetLevel,
    );

    // Decode School Logo (checking profile-specific logos first, then global)
    pw.MemoryImage? centerLogoImage;
    final logoSource = resolvedHeader['centerLogo'] ??
        resolvedHeader['leftLogo'] ??
        resolvedHeader['customLogo'] ??
        resolvedHeader['logoPath'] ??
        headerConfig?['centerLogo'] ??
        headerConfig?['leftLogo'] ??
        headerConfig?['logoPath'];
    if (logoSource != null && logoSource.toString().startsWith('data:image/')) {
      try {
        final base64Str = logoSource.toString().split(',').last;
        centerLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (e) {
        debugPrint("Error decoding unified report logo: $e");
      }
    }

    const darkNavy = PdfColor.fromInt(0xFF0F172A);
    const primaryIndigo = PdfColor.fromInt(0xFF4F46E5);
    const emeraldGreen = PdfColor.fromInt(0xFF059669);
    const roseRed = PdfColor.fromInt(0xFFE11D48);
    const amberOrange = PdfColor.fromInt(0xFFD97706);
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
        '+227 90 00 00 00';
    final email = resolvedHeader['email']?.toString() ??
        resolvedHeader['schoolEmail']?.toString() ??
        'contact@edut.pro';

    final countryAr = resolvedHeader['countryAr']?.toString() ?? 'جمهورية النيجر';
    final ministryAr = resolvedHeader['ministryAr']?.toString() ??
        EducationalLevelHelper.getDefaultMinistry(stage, isArabic: true);
    final schoolAr = resolvedHeader['schoolNameAr']?.toString() ??
        (stage == EducationalStage.universite ? 'جامعة التميز' : 'مدرسة التميز');
    final serviceAr = resolvedHeader['serviceAr']?.toString() ??
        EducationalLevelHelper.getDefaultService(stage, isArabic: true);

    final activeSession = sessionName ?? resolvedHeader['sessionName']?.toString() ?? 'Année Académique En Cours';
    final datePrinted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalCollected = (report['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (report['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final netBalance = (report['netBalance'] as num?)?.toDouble() ?? (totalCollected - totalExpenses);
    final totalDebts = (report['totalDebts'] as num?)?.toDouble() ?? 0.0;
    final expenseRatio = (report['expenseRatio'] as num?)?.toInt() ??
        (totalCollected > 0 ? ((totalExpenses / totalCollected) * 100).round() : 0);

    final rawCat = report['expensesByCategory'];
    final Map<String, double> expensesByCategory = {};
    if (rawCat is Map) {
      rawCat.forEach((k, v) {
        expensesByCategory[k.toString()] = (v as num?)?.toDouble() ?? 0.0;
      });
    }

    final rawModes = report['paymentsByMode'];
    final Map<String, double> paymentsByMode = {};
    if (rawModes is Map) {
      rawModes.forEach((k, v) {
        paymentsByMode[k.toString()] = (v as num?)?.toDouble() ?? 0.0;
      });
    }

    final List recentPayments = (report['recentPayments'] as List?) ?? [];
    final List recentExpenses = (report['recentExpenses'] as List?) ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(isA5 ? 14 : 20),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Institutional Bilingual Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left (French)
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          country.toUpperCase(),
                          style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy),
                        ),
                        pw.Text(
                          ministry,
                          style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 7, color: greyColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          school.toUpperCase(),
                          style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 8 : 10, color: darkNavy),
                        ),
                        if (service.isNotEmpty)
                          pw.Text(
                            service,
                            style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.5, color: greyColor),
                          ),
                        pw.Text(
                          'Tél: $phone | Email: $email',
                          style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor),
                        ),
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

                  // Right (Session & Period Info - Matching Web without Arabic)
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SESSION : $activeSession',
                          style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6.5 : 8, color: primaryIndigo),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Édité le : $datePrinted',
                          style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5.5 : 6.8, color: greyColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          getPeriodLabel(period, selectedDate),
                          style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 5.5 : 6.8, color: darkNavy),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Container(height: 0.5, color: lightBorder),
              pw.SizedBox(height: 6),

              // Title Banner: RAPPORT FINANCIER UNIFIÉ
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 8 : 12, vertical: isA5 ? 5 : 7),
                decoration: const pw.BoxDecoration(
                  color: primaryIndigo,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RAPPORT FINANCIER UNIFIÉ (RECETTES VS DÉPENSES)',
                          style: pw.TextStyle(
                            font: amiriBold,
                            fontSize: isA5 ? 8.5 : 10.5,
                            color: PdfColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.Text(
                          getPeriodLabel(period, selectedDate).toUpperCase(),
                          style: pw.TextStyle(
                            font: amiriFont,
                            fontSize: isA5 ? 5.5 : 6.8,
                            color: const PdfColor.fromInt(0xFFE0E7FF),
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 6 : 8, vertical: isA5 ? 2 : 3),
                      decoration: const pw.BoxDecoration(
                        color: darkNavy,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        'ÉDITION OFFICIELLE',
                        style: pw.TextStyle(
                          font: amiriBold,
                          fontSize: isA5 ? 5 : 6.5,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              // Date Printed bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  border: pw.Border.all(color: lightBorder),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Période : ${getPeriodLabel(period, selectedDate)}',
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
          final isPositive = netBalance >= 0;

          return [
            // ── 4 KPI CARDS ──
            pw.Row(
              children: [
                _buildKpiCard(
                  label: 'RECETTES ENCAISSÉES',
                  amount: formatCfa(totalCollected),
                  sublabel: 'Scolarités perçues',
                  color: emeraldGreen,
                  amiriBold: amiriBold,
                  amiriFont: amiriFont,
                  isA5: isA5,
                ),
                pw.SizedBox(width: 5),
                _buildKpiCard(
                  label: 'CHARGES & DÉPENSES',
                  amount: formatCfa(totalExpenses),
                  sublabel: 'Taux absorp: $expenseRatio%',
                  color: roseRed,
                  amiriBold: amiriBold,
                  amiriFont: amiriFont,
                  isA5: isA5,
                ),
                pw.SizedBox(width: 5),
                _buildKpiCard(
                  label: 'SOLDE NET TRÉSORERIE',
                  amount: formatCfa(netBalance),
                  sublabel: isPositive ? 'Excédent caisse' : 'Déficit exploitat.',
                  color: isPositive ? primaryIndigo : roseRed,
                  amiriBold: amiriBold,
                  amiriFont: amiriFont,
                  isA5: isA5,
                ),
                pw.SizedBox(width: 5),
                _buildKpiCard(
                  label: 'CRÉANCES / IMPAYÉS',
                  amount: formatCfa(totalDebts),
                  sublabel: 'Reste à recouvrer',
                  color: amberOrange,
                  amiriBold: amiriBold,
                  amiriFont: amiriFont,
                  isA5: isA5,
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // ── REPARTITION TABLES (Dépenses par catégorie & Recettes par mode) ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Table 1: Dépenses par catégorie
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const pw.BoxDecoration(
                          color: roseRed,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          'RÉPARTITION DES DÉPENSES PAR CATÉGORIE',
                          style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 5.5 : 7, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      _buildBreakdownTable(
                        items: expensesByCategory,
                        total: totalExpenses,
                        primaryColor: roseRed,
                        amiriBold: amiriBold,
                        amiriFont: amiriFont,
                        isA5: isA5,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                // Table 2: Recettes par mode de paiement
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const pw.BoxDecoration(
                          color: emeraldGreen,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          "CANAUX D'ENCAISSEMENT DES RECETTES",
                          style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 5.5 : 7, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      _buildBreakdownTable(
                        items: paymentsByMode,
                        total: totalCollected,
                        primaryColor: emeraldGreen,
                        amiriBold: amiriBold,
                        amiriFont: amiriFont,
                        isA5: isA5,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 12),

            // ── RECENT REVENUES JOURNAL TABLE ──
            pw.Text(
              'EXTRAIT DU JOURNAL DES RECETTES (DERNIERS ENCAISSEMENTS)',
              style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy),
            ),
            pw.SizedBox(height: 3),
            _buildPaymentsTable(
              payments: recentPayments,
              stage: stage,
              amiriBold: amiriBold,
              amiriFont: amiriFont,
              isA5: isA5,
            ),

            pw.SizedBox(height: 10),

            // ── RECENT EXPENSES JOURNAL TABLE ──
            if (recentExpenses.isNotEmpty) ...[
              pw.Text(
                'EXTRAIT DU JOURNAL DES CHARGES & DÉPENSES (SORTIES)',
                style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 7 : 8.5, color: darkNavy),
              ),
              pw.SizedBox(height: 3),
              _buildExpensesTable(
                expenses: recentExpenses,
                amiriBold: amiriBold,
                amiriFont: amiriFont,
                isA5: isA5,
              ),
              pw.SizedBox(height: 10),
            ],

            pw.SizedBox(height: 8),

            // ── SIGNATURES BLOCK ──
            pw.Container(height: 0.5, color: lightBorder),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("L'Intendant / Caissier",
                        style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5, color: darkNavy)),
                    pw.SizedBox(height: 22),
                    pw.Text('(Signature & Nom)',
                        style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Le Chef des Services Financiers',
                        style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5, color: darkNavy)),
                    pw.SizedBox(height: 22),
                    pw.Text('(Visa & Cachet)',
                        style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('La Direction Générale',
                        style: pw.TextStyle(font: amiriBold, fontSize: isA5 ? 6 : 7.5, color: darkNavy)),
                    pw.SizedBox(height: 22),
                    pw.Text('(Sceau Officiel)',
                        style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor)),
                  ],
                ),
              ],
            ),
          ];
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              'Page ${context.pageNumber} sur ${context.pagesCount} — Edut Pro Mobile Système Financier Unifié',
              style: pw.TextStyle(font: amiriFont, fontSize: isA5 ? 5 : 6, color: greyColor),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiCard({
    required String label,
    required String amount,
    required String sublabel,
    required PdfColor color,
    required pw.Font amiriBold,
    required pw.Font amiriFont,
    required bool isA5,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: isA5 ? 4 : 6, vertical: isA5 ? 4 : 6),
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
            pw.SizedBox(height: 2),
            pw.Text(
              amount,
              style: pw.TextStyle(
                font: amiriBold,
                fontSize: isA5 ? 6.5 : 8.5,
                color: color,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              sublabel,
              style: pw.TextStyle(
                font: amiriFont,
                fontSize: isA5 ? 4 : 5,
                color: const PdfColor.fromInt(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildBreakdownTable({
    required Map<String, double> items,
    required double total,
    required PdfColor primaryColor,
    required pw.Font amiriBold,
    required pw.Font amiriFont,
    required bool isA5,
  }) {
    const lightBorder = PdfColor.fromInt(0xFFE2E8F0);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);

    final entries = items.entries.toList();

    return pw.Table(
      border: pw.TableBorder.all(color: lightBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: lightBg),
          children: [
            _cellHeader('Désignation', amiriBold, isA5, align: pw.TextAlign.left),
            _cellHeader('Montant', amiriBold, isA5, align: pw.TextAlign.right),
            _cellHeader('Part', amiriBold, isA5, align: pw.TextAlign.center),
          ],
        ),
        if (entries.isEmpty)
          pw.TableRow(
            children: [
              _cellData('Aucune opération', amiriFont, isA5),
              _cellData(formatCfa(0), amiriBold, isA5, align: pw.TextAlign.right),
              _cellData('0%', amiriFont, isA5, align: pw.TextAlign.center),
            ],
          )
        else
          ...entries.map((e) {
            final part = total > 0 ? '${((e.value / total) * 100).round()}%' : '0%';
            return pw.TableRow(
              children: [
                _cellData(e.key, amiriFont, isA5),
                _cellData(formatCfa(e.value), amiriBold, isA5, align: pw.TextAlign.right, color: primaryColor),
                _cellData(part, amiriFont, isA5, align: pw.TextAlign.center),
              ],
            );
          }),
      ],
    );
  }

  static pw.Widget _buildPaymentsTable({
    required List payments,
    EducationalStage stage = EducationalStage.college,
    required pw.Font amiriBold,
    required pw.Font amiriFont,
    required bool isA5,
  }) {
    const darkNavy = PdfColor.fromInt(0xFF0F172A);
    const lightBorder = PdfColor.fromInt(0xFFE2E8F0);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const emeraldGreen = PdfColor.fromInt(0xFF059669);

    final displayList = payments.take(20).toList();
    final studentLabel = stage == EducationalStage.universite ? 'Étudiant' : 'Élève';
    final classLabel = stage == EducationalStage.universite ? 'Filière' : 'Classe';

    return pw.Table(
      border: pw.TableBorder.all(color: lightBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(16),
        1: pw.FixedColumnWidth(38),
        2: pw.FixedColumnWidth(44),
        3: pw.FlexColumnWidth(2.5),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(2.2),
        6: pw.FlexColumnWidth(1.2),
        7: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: darkNavy),
          children: [
            _cellHeaderWhite('N°', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Date', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Référence', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite(studentLabel, amiriBold, isA5, align: pw.TextAlign.left),
            _cellHeaderWhite(classLabel, amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Motif / Description', amiriBold, isA5, align: pw.TextAlign.left),
            _cellHeaderWhite('Mode', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Montant Encaissé', amiriBold, isA5, align: pw.TextAlign.right),
          ],
        ),
        if (displayList.isEmpty)
          pw.TableRow(
            children: [
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('Aucun encaissement sur cette période', amiriFont, isA5),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData(formatCfa(0), amiriBold, isA5, align: pw.TextAlign.right),
            ],
          )
        else
          ...displayList.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final p = entry.value as Map;
            final dateStr = p['date']?.toString().split('T')[0] ?? '-';
            final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
            final isEven = entry.key % 2 == 1;
            final month = p['monthConcerned']?.toString();
            final motif = month != null && month.isNotEmpty
                ? 'Scolarité ($month)'
                : (p['description']?.toString() ?? p['motif']?.toString() ?? 'Frais scolaires');

            return pw.TableRow(
              decoration: isEven ? const pw.BoxDecoration(color: lightBg) : null,
              children: [
                _cellData('$idx', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(dateStr, amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(p['reference']?.toString() ?? 'REC-${p['id'] ?? ''}', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(p['studentName']?.toString() ?? p['title']?.toString() ?? 'Élève', amiriBold, isA5),
                _cellData(p['classe']?.toString() ?? '-', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(motif, amiriFont, isA5),
                _cellData(p['mode']?.toString() ?? 'Espèces', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData('+${formatCfa(amt)}', amiriBold, isA5, align: pw.TextAlign.right, color: emeraldGreen),
              ],
            );
          }),
      ],
    );
  }

  static pw.Widget _buildExpensesTable({
    required List expenses,
    required pw.Font amiriBold,
    required pw.Font amiriFont,
    required bool isA5,
  }) {
    const darkNavy = PdfColor.fromInt(0xFF0F172A);
    const lightBorder = PdfColor.fromInt(0xFFE2E8F0);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const roseRed = PdfColor.fromInt(0xFFE11D48);

    final displayList = expenses.take(15).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: lightBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(16),
        1: pw.FixedColumnWidth(42),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: darkNavy),
          children: [
            _cellHeaderWhite('N°', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Date', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Motif / Description', amiriBold, isA5, align: pw.TextAlign.left),
            _cellHeaderWhite('Catégorie', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Mode', amiriBold, isA5, align: pw.TextAlign.center),
            _cellHeaderWhite('Montant Dépensé', amiriBold, isA5, align: pw.TextAlign.right),
          ],
        ),
        if (displayList.isEmpty)
          pw.TableRow(
            children: [
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('Aucune dépense enregistrée', amiriFont, isA5),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData('-', amiriFont, isA5, align: pw.TextAlign.center),
              _cellData(formatCfa(0), amiriBold, isA5, align: pw.TextAlign.right),
            ],
          )
        else
          ...displayList.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final e = entry.value as Map;
            final dateStr = e['date']?.toString().split('T')[0] ?? '-';
            final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
            final isEven = entry.key % 2 == 1;
            final desc = e['description']?.toString() ?? e['title']?.toString() ?? e['category']?.toString() ?? 'Dépense';

            return pw.TableRow(
              decoration: isEven ? const pw.BoxDecoration(color: lightBg) : null,
              children: [
                _cellData('$idx', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(dateStr, amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(desc, amiriBold, isA5),
                _cellData(e['category']?.toString() ?? 'Général', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData(e['paymentMode']?.toString() ?? 'Espèces', amiriFont, isA5, align: pw.TextAlign.center),
                _cellData('-${formatCfa(amt)}', amiriBold, isA5, align: pw.TextAlign.right, color: roseRed),
              ],
            );
          }),
      ],
    );
  }

  static pw.Widget _cellHeader(String text, pw.Font font, bool isA5, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: isA5 ? 2.5 : 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isA5 ? 5.5 : 6.8,
          color: const PdfColor.fromInt(0xFF1E293B),
        ),
      ),
    );
  }

  static pw.Widget _cellHeaderWhite(String text, pw.Font font, bool isA5, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: isA5 ? 2.5 : 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isA5 ? 5.5 : 6.8,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _cellData(
    String text,
    pw.Font font,
    bool isA5, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = const PdfColor.fromInt(0xFF1E293B),
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: isA5 ? 2 : 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isA5 ? 5.5 : 6.8,
          color: color,
        ),
      ),
    );
  }
}
