import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/educational_level_helper.dart';

export '../../../core/utils/educational_level_helper.dart' show EducationalStage;

class OfficialBulletinPdfGenerator {
  /// Detect the educational stage from student data or class name
  static EducationalStage detectStage({
    String? educationalLevel,
    String? className,
    String? sectionName,
    String? filiere,
  }) {
    return EducationalLevelHelper.inferEducationalStage(
      educationalLevel: educationalLevel,
      className: className,
      sectionName: sectionName,
      filiere: filiere,
    );
  }

  /// Generate Official Multi-Stage Bulletin PDF
  static Future<Uint8List> generateBulletinBytes({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> summary,
    required String period,
    required String sessionName,
    Map<String, dynamic>? headerConfig,
  }) async {
    final pdf = pw.Document();

    // Fonts for Unicode / Arabic
    final amiriBold = await PdfGoogleFonts.amiriBold();

    final studentName = student['nom_etudiant']?.toString() ?? 'Sans Nom';
    final matricule = student['num_admission']?.toString() ??
        student['matricule']?.toString() ??
        'N/A';
    final className = student['classe']?.toString() ?? 'Classe';
    final rawLevel = student['educational_level']?.toString() ?? '';
    final birthDate = student['date_naissance']?.toString() ?? '-';
    final birthPlace = student['lieu_naissance']?.toString() ?? '-';
    final gender = student['sexe']?.toString() ?? 'M';

    final stage = detectStage(
      educationalLevel: rawLevel,
      className: className,
      sectionName: student['section']?.toString(),
      filiere: student['filiere']?.toString(),
    );

    // Resolve matching level profile from headerConfig
    final resolvedHeader = EducationalLevelHelper.getActiveLevelHeaderConfig(
      headerConfig,
      targetLevel: rawLevel.isNotEmpty ? rawLevel : className,
    );

    // School Header Logos
    pw.MemoryImage? leftLogoImage;
    final logoSource = resolvedHeader['leftLogo'] ??
        resolvedHeader['centerLogo'] ??
        resolvedHeader['customLogo'] ??
        headerConfig?['leftLogo'];
    if (logoSource != null && logoSource.toString().startsWith('data:image/')) {
      try {
        final base64Str = logoSource.toString().split(',').last;
        leftLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (_) {}
    }

    final schoolName = resolvedHeader['schoolName']?.toString() ??
        (stage == EducationalStage.universite ? 'UNIVERSITÉ EXCELLENCE' : 'ÉCOLE EXCELLENCE');
    final country = resolvedHeader['country']?.toString() ?? 'RÉPUBLIQUE DU NIGER';
    final ministry = resolvedHeader['ministry']?.toString() ??
        EducationalLevelHelper.getDefaultMinistry(stage);
    final address = resolvedHeader['address']?.toString() ?? '';
    final phone = resolvedHeader['phone']?.toString() ?? '';

    if (stage == EducationalStage.universite) {
      return _generateUniversityReleveBytes(
        student: student,
        grades: grades,
        summary: summary,
        period: period,
        sessionName: sessionName,
        headerConfig: resolvedHeader,
        amiriBold: amiriBold,
      );
    }

    if (stage == EducationalStage.primaire) {
      return _generatePrimaireBulletinBytes(
        student: student,
        grades: grades,
        summary: summary,
        period: period,
        sessionName: sessionName,
        headerConfig: resolvedHeader,
        amiriBold: amiriBold,
      );
    }

    // 0. Compute accurate Totals and Coefficients from grades
    int sumCoef = 0;
    double sumPoints = 0.0;
    for (final g in grades) {
      final rawDevoir = (g['class_work_score'] as num?)?.toDouble() ??
          (g['devoir_score'] as num?)?.toDouble();
      final rawCompo = (g['exam_score'] as num?)?.toDouble();
      final rawTotal = (g['total_score'] as num?)?.toDouble();

      double s = 0.0;
      if (rawDevoir != null && rawCompo != null && rawDevoir > 0 && rawCompo > 0) {
        final d = rawDevoir <= 20.0 ? rawDevoir : (rawDevoir / 2.0);
        final c = rawCompo <= 20.0 ? rawCompo : (rawCompo / 2.0);
        s = (d + c) / 2.0;
      } else if (rawTotal != null && rawTotal > 0) {
        s = rawTotal <= 20.0 ? rawTotal : (rawTotal <= 40.0 ? rawTotal / 2.0 : (rawTotal / 100.0) * 20.0);
      } else {
        s = (rawCompo != null && rawCompo > 0) ? (rawCompo <= 20.0 ? rawCompo : rawCompo / 2.0) : 0.0;
      }
      s = s.clamp(0.0, 20.0);

      int c = (g['coefficient'] as num?)?.toInt() ??
          (g['coef'] as num?)?.toInt() ?? 0;
      if (c <= 0) {
        final sub = (g['school_subjects']?['subject_name'] ?? g['subject_name'] ?? g['discipline'] ?? '').toString().toLowerCase();
        if (sub.contains('arabe') || sub.contains('français') || sub.contains('islam') || sub.contains('physique') || sub.contains('eps') || sub.contains('anglais')) {
          c = 4;
        } else if (sub.contains('math') || sub.contains('hist') || sub.contains('géo')) {
          c = 3;
        } else if (sub.contains('conduite')) {
          c = 1;
        } else {
          c = 2;
        }
      }

      sumPoints += s * c;
      sumCoef += c;
    }

    final computedAvg = sumCoef > 0 ? (sumPoints / sumCoef) : 0.0;
    final Map<String, dynamic> resolvedSummary = Map<String, dynamic>.from(summary);
    if (resolvedSummary['average'] == null || (resolvedSummary['average'] as num) == 0) {
      resolvedSummary['average'] = computedAvg;
    }
    resolvedSummary['totalPoints'] = sumPoints;
    resolvedSummary['totalCoef'] = sumCoef;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Background Watermark: DUPLICATA NON ORIGINAL
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.45,
                    child: pw.Text(
                      'DUPLICATA NON ORIGINAL\nDOCUMENT INFORMATIF',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: const PdfColor(0.90, 0.90, 0.90),
                        fontSize: 34,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content Column
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. Header (School & Republic)
                  _buildHeader(
                    country: country,
                    ministry: ministry,
                    schoolName: schoolName,
                    address: address,
                    phone: phone,
                    sessionName: sessionName,
                    logo: leftLogoImage,
                    amiriBold: amiriBold,
                  ),

                  pw.SizedBox(height: 6),

                  // 2. Stage Specific Title Banner
                  _buildStageTitleBanner(stage, period),

                  pw.SizedBox(height: 4),

                  // 2b. Warning Banner: Non-Original Duplicata
                  _buildNonOriginalBanner(),

                  pw.SizedBox(height: 6),

                  // 3. Student Identification Card
                  _buildStudentInfoBox(
                    name: studentName,
                    matricule: matricule,
                    className: className,
                    rawLevel: rawLevel,
                    birthDate: birthDate,
                    birthPlace: birthPlace,
                    gender: gender,
                    sessionName: sessionName,
                    stage: stage,
                  ),

                  pw.SizedBox(height: 8),

                  // 4. Stage Specific Grades Table
                  _buildGradesTable(stage, grades),

                  pw.SizedBox(height: 8),

                  // 5. Summary & Decision Box
                  _buildSummaryAndDecisionBox(stage, resolvedSummary),

                  pw.Spacer(),

                  // 6. Signatures, Official Seals and Legal Disclaimer
                  _buildSignaturesBlock(stage),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  OFFICIAL UNIVERSITY RELEVE DE NOTES (LMD) - EXACT MATCH WITH WEB
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> _generateUniversityReleveBytes({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> summary,
    required String period,
    required String sessionName,
    Map<String, dynamic>? headerConfig,
    required pw.Font amiriBold,
  }) async {
    final pdf = pw.Document();

    final studentName = student['nom_etudiant']?.toString() ??
        student['nomEtudiant']?.toString() ??
        student['name']?.toString() ??
        'Sans Nom';
    final matricule = student['num_admission']?.toString() ??
        student['numAdmission']?.toString() ??
        student['matricule']?.toString() ??
        'N/A';
    final className = student['classe']?.toString() ??
        student['className']?.toString() ??
        'Licence';
    final rawLevel = student['educational_level']?.toString() ??
        student['educationalLevel']?.toString() ??
        '';

    final rawDob = student['date_naissance']?.toString() ??
        student['dateNaissance']?.toString() ??
        student['dateOfBirth']?.toString() ??
        student['birthDate']?.toString() ??
        student['dob']?.toString();
    final rawPob = student['lieu_naissance']?.toString() ??
        student['lieuNaissance']?.toString() ??
        student['placeOfBirth']?.toString() ??
        student['pob']?.toString() ??
        student['lieu']?.toString();

    String formattedDob = '-';
    if (rawDob != null && rawDob.trim().isNotEmpty && rawDob != '-') {
      String str = rawDob.trim();
      if (str.contains('T')) str = str.split('T').first;
      final parts = str.split('-');
      if (parts.length == 3 && parts[0].length == 4) {
        formattedDob = '${parts[2]}/${parts[1]}/${parts[0]}';
      } else {
        formattedDob = str;
      }
    }
    final birthInfo = (rawPob != null && rawPob.trim().isNotEmpty && rawPob != '-')
        ? '$formattedDob à ${rawPob.trim()}'
        : formattedDob;

    final resolvedHeader = EducationalLevelHelper.getActiveLevelHeaderConfig(
      headerConfig,
      targetLevel: rawLevel.isNotEmpty ? rawLevel : className,
    );

    // School Header Logos
    pw.MemoryImage? leftLogoImage;
    final logoSource = resolvedHeader['leftLogo'] ??
        resolvedHeader['centerLogo'] ??
        resolvedHeader['customLogo'] ??
        headerConfig?['leftLogo'];
    if (logoSource != null && logoSource.toString().startsWith('data:image/')) {
      try {
        final base64Str = logoSource.toString().split(',').last;
        leftLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (_) {}
    }

    final schoolName = resolvedHeader['schoolName']?.toString() ?? 'UNIVERSITÉ EXCELLENCE';
    final country = resolvedHeader['country']?.toString() ?? 'RÉPUBLIQUE DU NIGER';
    final ministry = resolvedHeader['ministry']?.toString() ??
        EducationalLevelHelper.getDefaultMinistry(EducationalStage.universite);
    final address = resolvedHeader['address']?.toString() ?? '';
    final phone = resolvedHeader['phone']?.toString() ?? '';

    // Determine Semesters (Semestre 1 & 2, or 3 & 4, or 5 & 6)
    final pLower = period.toLowerCase();
    final isDoctorate = rawLevel.toLowerCase().contains('doc') ||
        className.toLowerCase().contains('doc') ||
        pLower.contains('ann') ||
        pLower.contains('annee');

    String firstSemesterName = isDoctorate ? 'ANNEE 1' : 'SEMESTRE 1';
    String secondSemesterName = isDoctorate ? 'ANNEE 2' : 'SEMESTRE 2';
    String suffix1 = '1';
    String suffix2 = '2';

    if (pLower.contains('3') || pLower.contains('4') || pLower.contains('l2') || pLower.contains('s3') || pLower.contains('s4')) {
      firstSemesterName = isDoctorate ? 'ANNEE 3' : 'SEMESTRE 3';
      secondSemesterName = isDoctorate ? 'ANNEE 4' : 'SEMESTRE 4';
      suffix1 = '3';
      suffix2 = '4';
    } else if (pLower.contains('5') || pLower.contains('6') || pLower.contains('l3') || pLower.contains('s5') || pLower.contains('s6')) {
      firstSemesterName = isDoctorate ? 'ANNEE 5' : 'SEMESTRE 5';
      secondSemesterName = isDoctorate ? 'ANNEE 6' : 'SEMESTRE 6';
      suffix1 = '5';
      suffix2 = '6';
    }

    // Split grades into First Semester and Second Semester
    final s1Grades = <Map<String, dynamic>>[];
    final s2Grades = <Map<String, dynamic>>[];

    for (final g in grades) {
      final term = (g['term']?.toString() ?? '').toLowerCase();
      if (term.contains(suffix2) || term.contains('s$suffix2') || term.contains('semestre $suffix2') || term.contains('f$suffix2')) {
        s2Grades.add(g);
      } else {
        s1Grades.add(g);
      }
    }

    // Mention helper
    String getMention(double avg) {
      if (avg >= 18) return 'Excellent';
      if (avg >= 16) return 'Très Bien';
      if (avg >= 14) return 'Bien';
      if (avg >= 12) return 'Assez Bien';
      if (avg >= 10) return 'Passable';
      return 'Ajourné';
    }

    // Decision helper
    String getDecision(double avg, [String? savedDecision]) {
      if (avg < 10) return 'Ajourné';
      if (savedDecision != null &&
          savedDecision.isNotEmpty &&
          !savedDecision.toLowerCase().contains('ajourn')) {
        return savedDecision;
      }
      if (avg >= 18) return 'Admis avec la mention Excellent';
      if (avg >= 16) return 'Admis avec la mention Très Bien';
      if (avg >= 14) return 'Admis avec la mention Bien';
      if (avg >= 12) return 'Admis avec la mention Assez Bien';
      if (avg >= 10) return 'Admis avec la mention Passable';
      return 'Ajourné';
    }

    // Helper to build Semester Table with colSpan matching Web
    pw.Widget buildSemesterTable(String semesterTitle, List<Map<String, dynamic>> semesterGrades, String sfx) {
      double totalPoints = 0.0;
      int totalCredits = 0;

      final rows = semesterGrades.map((g) {
        final subName = g['school_subjects']?['subject_name']?.toString() ??
            g['subject']?['subject_name']?.toString() ??
            g['subject_name']?.toString() ??
            g['name']?.toString() ??
            'Matière';

        final rawCode = g['school_subjects']?['subject_code']?.toString() ??
            g['subject_code']?.toString() ??
            g['subject']?['subject_code']?.toString() ??
            g['code']?.toString();

        String subCode;
        if (rawCode != null && rawCode.trim().isNotEmpty) {
          subCode = rawCode.trim();
        } else {
          final clean = subName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
          final prefix = clean.length >= 4 ? clean.substring(0, 4) : clean.padRight(4, 'X');
          subCode = '$prefix $sfx';
        }

        final rawCw = (g['class_work_score'] as num?)?.toDouble() ?? (g['cc_score'] as num?)?.toDouble();
        final rawEx = (g['exam_score'] as num?)?.toDouble();
        final rawTot = (g['total_score'] as num?)?.toDouble() ?? (g['average'] as num?)?.toDouble();

        double score = 0.0;
        if (rawCw != null && rawEx != null && rawCw > 0 && rawEx > 0) {
          score = (rawCw + rawEx) / 2.0;
        } else if (rawTot != null && rawTot > 0) {
          score = rawTot;
        } else if (rawEx != null && rawEx > 0) {
          score = rawEx;
        } else if (rawCw != null && rawCw > 0) {
          score = rawCw;
        }

        final credits = (g['credits'] as num?)?.toInt() ??
            (g['coefficient'] as num?)?.toInt() ??
            (g['coef'] as num?)?.toInt() ??
            4;

        final mention = getMention(score);

        totalPoints += (score * credits);
        totalCredits += credits;

        final scoreColor = score >= 14
            ? PdfColors.blue800
            : (score < 10 ? PdfColors.red800 : PdfColors.black);

        return [
          subCode,
          subName,
          credits.toString(),
          score.toStringAsFixed(2),
          mention,
          scoreColor,
        ];
      }).toList();

      final semesterAvg = totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
      final semesterDecision = getDecision(semesterAvg);

      final isDense = semesterGrades.length > 7;
      final matiereFontSize = isDense ? 8.5 : 10.0;

      const headerBg = PdfColor(0.824, 0.902, 0.824); // #D2E6D2
      const borderColor = PdfColors.black;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              semesterTitle,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5, color: PdfColors.black),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.8),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(4.2),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                    child: pw.Text('Code', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: const PdfColor(0, 0.2, 0))),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                    child: pw.Text('Matières', textAlign: pw.TextAlign.left, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: const PdfColor(0, 0.2, 0))),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                    child: pw.Text('Crédits', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: const PdfColor(0, 0.2, 0))),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                    child: pw.Text('Notes/20', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: const PdfColor(0, 0.2, 0))),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                    child: pw.Text('Mention', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: const PdfColor(0, 0.2, 0))),
                  ),
                ],
              ),
              // Data Rows
              if (rows.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: pw.Text('Aucune note saisie pour ce semestre', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                  ],
                )
              else
                ...rows.map(
                  (r) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                        child: pw.Text(r[0] as String, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.black)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
                        child: pw.Text(r[1] as String, style: pw.TextStyle(fontSize: matiereFontSize, color: PdfColors.black)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                        child: pw.Text(r[2] as String, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                        child: pw.Text(
                          r[3] as String,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: r[5] as PdfColor),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                        child: pw.Text(r[4] as String, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Clean Footer Block Matching Web ColSpan Exactly (flex: 55 = 13+42, 11, 28 = 13+15)
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: headerBg,
              border: pw.Border(
                left: pw.BorderSide(color: borderColor, width: 0.8),
                right: pw.BorderSide(color: borderColor, width: 0.8),
                bottom: pw.BorderSide(color: borderColor, width: 0.8),
              ),
            ),
            child: pw.Column(
              children: [
                // Row 1: TOTAL
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 55,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: borderColor, width: 0.8)),
                        ),
                        child: pw.Text('TOTAL', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                    ),
                    pw.Expanded(
                      flex: 11,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: borderColor, width: 0.8)),
                        ),
                        child: pw.Text(rows.isNotEmpty ? totalCredits.toString() : '-', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                    ),
                    pw.Expanded(
                      flex: 28,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(rows.isNotEmpty ? totalPoints.toStringAsFixed(2) : '-', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                    ),
                  ],
                ),
                pw.Container(height: 0.8, color: borderColor),
                // Row 2: Moyenne Semestrielle
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 55,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: borderColor, width: 0.8)),
                        ),
                        child: pw.Text('Moyenne Semestrielle', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.0)),
                      ),
                    ),
                    pw.Expanded(
                      flex: 39,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text(
                          rows.isNotEmpty ? semesterAvg.toStringAsFixed(2) : '-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9.5,
                            color: rows.isNotEmpty
                                ? (semesterAvg >= 10 ? PdfColors.green800 : PdfColors.red800)
                                : PdfColors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Container(height: 0.8, color: borderColor),
                // Row 3: DECISION DU JURY
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 55,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: borderColor, width: 0.8)),
                        ),
                        child: pw.Text('DECISION DU JURY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                    ),
                    pw.Expanded(
                      flex: 39,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: pw.Text(
                          rows.isNotEmpty ? semesterDecision : '-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8.5,
                            color: rows.isNotEmpty
                                ? (semesterAvg >= 10 ? const PdfColor(0.0, 0.4, 0.0) : PdfColors.red900)
                                : PdfColors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    final studentMatricule = matricule.isNotEmpty && matricule != 'N/A' ? matricule : (student['id']?.toString() ?? 'RELEVE');
    final qrData = 'https://niger.edut.pro/verify/${Uri.encodeComponent(studentMatricule)}';

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          buildBackground: (context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  if (leftLogoImage != null)
                    pw.Center(
                      child: pw.Opacity(
                        opacity: 0.10,
                        child: pw.Image(leftLogoImage, width: 360, height: 360),
                      ),
                    ),
                  // Diagonal Non-Original Watermark across the document
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.45,
                      child: pw.Text(
                        'DUPLICATA NON ORIGINAL\nDOCUMENT INFORMATIF',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: const PdfColor(0.88, 0.88, 0.88),
                          fontSize: 34,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Header (School & Republic)
              _buildHeader(
                country: country,
                ministry: ministry,
                schoolName: schoolName,
                address: address,
                phone: phone,
                sessionName: sessionName,
                logo: leftLogoImage,
                amiriBold: amiriBold,
              ),

              pw.SizedBox(height: 4),

              // 2. Green Title Bar: RELEVE DE NOTES
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
                decoration: const pw.BoxDecoration(
                  color: PdfColor(0.824, 0.902, 0.824), // #D2E6D2
                ),
                child: pw.Center(
                  child: pw.Text(
                    'RELEVE DE NOTES',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: const PdfColor(0.0, 0.2, 0.0), // dark green
                    ),
                  ),
                ),
              ),

              // 2b. Warning Banner: Non-Original Duplicata (Édition Mobile)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 2, bottom: 4),
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(0.99, 0.94, 0.94),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFDC2626), width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '⚠️  DUPLICATA NUMÉRIQUE NON ORIGINAL — DOCUMENT INFORMATIF (ÉDITION MOBILE)',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7.5,
                        color: const PdfColor.fromInt(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 2),

              // 3. Student Info Section & QR Code
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('Etudiant: ', style: const pw.TextStyle(fontSize: 8.5)),
                            pw.Text(studentName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.SizedBox(width: 14),
                            pw.Text('Né(e) le : ', style: const pw.TextStyle(fontSize: 8.5)),
                            pw.Text(birthInfo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          children: [
                            pw.Text('Matricule: ', style: const pw.TextStyle(fontSize: 8.5)),
                            pw.Text(matricule, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          children: [
                            pw.Text('Parcours: ', style: const pw.TextStyle(fontSize: 8.5)),
                            pw.Text(className, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          ],
                        ),
                        pw.SizedBox(height: 3.5),
                        pw.Row(
                          children: [
                            pw.Text('Première session  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.Text(sessionName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 65,
                    height: 65,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 5),

              // 4. Semestre 1 Table
              buildSemesterTable(firstSemesterName, s1Grades, suffix1),

              pw.SizedBox(height: 6),

              // 5. Semestre 2 Table
              buildSemesterTable(secondSemesterName, s2Grades, suffix2),

              pw.Spacer(),

              // 6. Signature: Le Doyen
              pw.Center(
                child: pw.Text(
                  'Le Doyen',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 6),

              // 7. Disclaimer Box for Mobile Digital Copy (Non-Original / غير أصل)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(0.97, 0.97, 0.97),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'AVIS IMPORTANT : Le présent document est un DUPLICATA NUMÉRIQUE NON ORIGINAL généré via l\'application mobile Edut pour information consultative de l\'étudiant.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      'Il ne remplace en aucun cas le relevé officiel original. Seul le document physique délivré par la scolarité de l\'Université, signé par le Doyen et revêtu du sceau académique authentique fait foi.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6.0, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      'Il ne sera pas délivré de duplicata officiel de ce relevé. Il vous appartient d\'en faire des copies et de les faire certifier conformes.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 6.0, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  OFFICIAL PRIMARY SCHOOL BULLETIN (CARNET DE NOTES PRIMAIRE - BILINGUE)
  // ───────────────────────────────────────────────────────────────────────────
  static String _computePrimaryNextClass(String currentClass) {
    final upper = currentClass.toUpperCase().trim();
    if (upper.contains('CI')) return 'CP';
    if (upper.contains('CP1')) return 'CP2';
    if (upper.contains('CP2') || upper.contains('CP')) return 'CE1';
    if (upper.contains('CE1')) return 'CE2';
    if (upper.contains('CE2')) return 'CM1';
    if (upper.contains('CM1')) return 'CM2';
    if (upper.contains('CM2')) return '6ème';
    if (upper.contains('SIL')) return 'CP';
    return 'Classe Supérieure';
  }

  static String _getQualitativeMention(double sc) {
    if (sc >= 16) return 'Très Bien';
    if (sc >= 14) return 'Bien';
    if (sc >= 12) return 'A.Bien';
    if (sc >= 10) return 'Passable';
    return 'Insuffisant';
  }

  static String _inferPrimaryTrack(
    Map<String, dynamic> student,
    List<Map<String, dynamic>> grades,
    Map<String, dynamic>? headerConfig,
  ) {
    final explicit = student['primary_track'] ??
        student['primaryTrack'] ??
        student['track'] ??
        headerConfig?['primaryTrack'];
    if (explicit != null) {
      final expLower = explicit.toString().toLowerCase();
      if (expLower.contains('fa') || expLower.contains('arabe')) return 'franco_arabe';
      if (expLower.contains('gen') || expLower.contains('fran')) return 'general';
    }

    final text = '${student['section'] ?? ''} ${student['sectionName'] ?? ''} ${student['filiere'] ?? ''} ${student['classe'] ?? ''} ${student['className'] ?? ''} ${student['educationalLevel'] ?? ''}'
        .toLowerCase();

    if (RegExp(r'\bfa\b|franco[-_ ]?arabe|medersa|islamique').hasMatch(text)) {
      return 'franco_arabe';
    }
    if (RegExp(r'\bgen\b|g[eé]n[eé]ral|classique|fran[cç]ais[e]?\s*g[eé]n[eé]ral').hasMatch(text)) {
      return 'general';
    }

    final hasIslamic = grades.any((g) {
      final name = (g['subject_name'] ?? g['name'] ?? g['matiere'] ?? '').toString().toLowerCase();
      return RegExp(r'coran|quran|kouran|hadith|hadit|tawhid|fikh|fiqh|sira|nahw').hasMatch(name);
    });
    if (hasIslamic) return 'franco_arabe';

    if (text.contains('arabe')) return 'franco_arabe';

    return 'general';
  }

  static final List<Map<String, dynamic>> _primaryFrancoArabeSubjects = [
    {'nameFr': "Al-Kour'Ane", 'nameAr': 'القرآن الكريم', 'sur': 20, 'isAr': true, 'keys': ['coran', 'quran', 'kourane', 'kouran']},
    {'nameFr': 'Al-Hadith', 'nameAr': 'الحديث', 'sur': 10, 'isAr': true, 'keys': ['hadith', 'hadit']},
    {'nameFr': 'Attawhide', 'nameAr': 'التوحيد', 'sur': 10, 'isAr': true, 'keys': ['tawhid', 'tawhide', 'attawhid']},
    {'nameFr': 'Al-Fikhou', 'nameAr': 'الفقه', 'sur': 10, 'isAr': true, 'keys': ['fikh', 'fikhou', 'fiqh']},
    {'nameFr': 'Assira', 'nameAr': 'السيرة', 'sur': 10, 'isAr': true, 'keys': ['sira', 'assira']},
    {'nameFr': 'Annahwou', 'nameAr': 'النحو', 'sur': 10, 'isAr': true, 'keys': ['nahw', 'nahwou', 'annahwou']},
    {'nameFr': 'Etude de texte', 'nameAr': 'دراسة النص', 'sur': 20, 'isAr': false, 'keys': ['texte', 'etude de texte']},
    {'nameFr': 'Mathématique', 'nameAr': 'الحساب/الرياضيات', 'sur': 50, 'isAr': false, 'keys': ['math', 'calcul', 'arithmetique', 'arithmétique']},
    {'nameFr': 'Sciences', 'nameAr': 'العلوم', 'sur': 20, 'isAr': false, 'keys': ['science', 'eveil', 'éveil', 'observation']},
    {'nameFr': 'Lecture', 'nameAr': 'القراءة', 'sur': 20, 'isAr': false, 'keys': ['lecture']},
    {'nameFr': 'Langage', 'nameAr': 'المحادثة', 'sur': 10, 'isAr': false, 'keys': ['langage', 'expression orale', 'communication']},
    {'nameFr': 'Rédaction', 'nameAr': 'التعبير', 'sur': 20, 'isAr': false, 'keys': ['redaction', 'rédaction', 'expression ecrite']},
    {'nameFr': 'Récitation/Chant', 'nameAr': 'المحفوظات/الأناشيد', 'sur': 10, 'isAr': false, 'keys': ['recitation', 'récitation', 'chant', 'poesie', 'poésie']},
    {'nameFr': 'Dictée', 'nameAr': 'الإملاء', 'sur': 20, 'isAr': false, 'keys': ['dictee', 'dictée', 'orthographe']},
    {'nameFr': 'Histoire', 'nameAr': 'التاريخ', 'sur': 10, 'isAr': false, 'keys': ['histoire']},
    {'nameFr': 'Géographie', 'nameAr': 'الجغرافية', 'sur': 10, 'isAr': false, 'keys': ['geographie', 'géographie']},
    {'nameFr': 'Ecriture', 'nameAr': 'الخط', 'sur': 10, 'isAr': true, 'keys': ['ecriture', 'écriture', 'khatt', 'khat']},
    {'nameFr': 'Dessin', 'nameAr': 'الرسم', 'sur': 10, 'isAr': false, 'keys': ['dessin', 'arts']},
    {'nameFr': 'EPS', 'nameAr': 'الرياضة البدنية', 'sur': 10, 'isAr': false, 'keys': ['eps', 'sport', 'physique']},
  ];

  static final List<Map<String, dynamic>> _primaryGeneralSubjects = [
    {'nameFr': 'Étude de texte', 'nameAr': 'دراسة النص', 'sur': 20, 'keys': ['etude de texte', 'texte', 'comprehension']},
    {'nameFr': 'Lecture', 'nameAr': 'القراءة', 'sur': 20, 'keys': ['lecture']},
    {'nameFr': 'Expression écrite / Rédaction', 'nameAr': 'التعبير والإنشاء', 'sur': 20, 'keys': ['redaction', 'rédaction', 'expression', 'production']},
    {'nameFr': 'Vocabulaire', 'nameAr': 'المفردات', 'sur': 10, 'keys': ['vocabulaire', 'lexique']},
    {'nameFr': 'Grammaire / Conjugaison', 'nameAr': 'القواعد والصرف', 'sur': 20, 'keys': ['grammaire', 'conjugaison']},
    {'nameFr': 'Dictée & Orthographe', 'nameAr': 'الإملاء', 'sur': 20, 'keys': ['dictee', 'dictée', 'orthographe']},
    {'nameFr': 'Écriture', 'nameAr': 'الخط', 'sur': 10, 'keys': ['ecriture', 'écriture', 'graphisme']},
    {'nameFr': 'Poésie & Récitation', 'nameAr': 'المحفوظات', 'sur': 10, 'keys': ['poesie', 'poésie', 'recitation', 'récitation']},
    {'nameFr': 'Calcul & Opérations', 'nameAr': 'الحساب والعمليات', 'sur': 30, 'keys': ['calcul', 'arithmetique', 'arithmétique', 'math']},
    {'nameFr': 'Problèmes', 'nameAr': 'المسائل', 'sur': 20, 'keys': ['probleme', 'problème', 'resolution']},
    {'nameFr': 'Géométrie & Mesures', 'nameAr': 'الهندسة والقياس', 'sur': 10, 'keys': ['geometrie', 'géométrie', 'mesure']},
    {'nameFr': "Sciences d'observation", 'nameAr': 'العلوم والملاحظة', 'sur': 20, 'keys': ['science', 'eveil', 'éveil', 'observation']},
    {'nameFr': 'Hygiène & Environnement', 'nameAr': 'الصحة والبيئة', 'sur': 10, 'keys': ['hygiene', 'hygiène', 'environnement', 'sante', 'santé']},
    {'nameFr': 'Histoire', 'nameAr': 'التاريخ', 'sur': 10, 'keys': ['histoire']},
    {'nameFr': 'Géographie', 'nameAr': 'الجغرافية', 'sur': 10, 'keys': ['geographie', 'géographie']},
    {'nameFr': 'Éducation civique / Morale', 'nameAr': 'التربية المدنية', 'sur': 10, 'keys': ['civique', 'morale', 'ecm', 'civisme']},
    {'nameFr': 'Dessin & Travaux manuels', 'nameAr': 'الرسم والأشغال', 'sur': 10, 'keys': ['dessin', 'arts', 'manuelle', 'bricolage']},
    {'nameFr': 'EPS / Sport', 'nameAr': 'الرياضة البدنية', 'sur': 10, 'keys': ['eps', 'sport', 'physique']},
  ];

  static Future<Uint8List> _generatePrimaireBulletinBytes({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> grades,
    required Map<String, dynamic> summary,
    required String period,
    required String sessionName,
    Map<String, dynamic>? headerConfig,
    required pw.Font amiriBold,
  }) async {
    final pdf = pw.Document();

    final studentName = student['nom_etudiant']?.toString() ??
        student['nomEtudiant']?.toString() ??
        student['name']?.toString() ??
        'Sans Nom';
    final className = student['classe']?.toString() ??
        student['className']?.toString() ??
        'CP';

    final track = _inferPrimaryTrack(student, grades, headerConfig);
    final isFrancoArabe = track == 'franco_arabe';

    // School Header Logos
    pw.MemoryImage? centerLogoImage;
    final logoSource = headerConfig?['centerLogo'] ??
        headerConfig?['customLogo'] ??
        headerConfig?['leftLogo'];
    if (logoSource != null && logoSource.toString().startsWith('data:image/')) {
      try {
        final base64Str = logoSource.toString().split(',').last;
        centerLogoImage = pw.MemoryImage(base64.decode(base64Str));
      } catch (_) {}
    }

    // Determine current active composition index
    int currentCompIndex = 1;
    final lowerPeriod = period.toLowerCase();
    if (lowerPeriod.contains('2') || lowerPeriod.contains('deux')) {
      currentCompIndex = 2;
    } else if (lowerPeriod.contains('3') || lowerPeriod.contains('trois')) {
      currentCompIndex = 3;
    }

    // Find grades mapped to standard subjects based on track
    double totalFr1 = 0, totalAr1 = 0;
    int countFr1 = 0, countAr1 = 0;

    final List<List<dynamic>> rowsData = [];

    if (isFrancoArabe) {
      for (final s in _primaryFrancoArabeSubjects) {
        final nameFr = s['nameFr'] as String;
        final nameAr = s['nameAr'] as String;
        final sur = s['sur'] as int;
        final isAr = s['isAr'] as bool;
        final keys = s['keys'] as List<String>;

        Map<String, dynamic>? matchedGrade;
        for (final g in grades) {
          final gName = (g['subject_name'] ?? g['name'] ?? g['matiere'] ?? '').toString().toLowerCase();
          if (keys.any((k) => gName.contains(k))) {
            matchedGrade = g;
            break;
          }
        }

        double? score;
        if (matchedGrade != null) {
          final rawVal = matchedGrade['exam_score'] ?? matchedGrade['total_score'] ?? matchedGrade['note'];
          if (rawVal != null) {
            score = (rawVal as num).toDouble();
          }
        }

        String comp1Fr = '', comp1Ar = '';
        if (score != null) {
          final formattedScore = score.toStringAsFixed(1);
          if (isAr) {
            comp1Ar = formattedScore;
            totalAr1 += score;
            countAr1++;
          } else {
            comp1Fr = formattedScore;
            totalFr1 += score;
            countFr1++;
          }
        }

        rowsData.add([
          nameFr,
          nameAr,
          sur.toString(),
          currentCompIndex == 1 ? comp1Fr : '',
          currentCompIndex == 1 ? comp1Ar : '',
          currentCompIndex == 2 ? comp1Fr : '',
          currentCompIndex == 2 ? comp1Ar : '',
          currentCompIndex == 3 ? comp1Fr : '',
          currentCompIndex == 3 ? comp1Ar : '',
        ]);
      }
    } else {
      // General Primary (Français Général)
      for (final s in _primaryGeneralSubjects) {
        final nameFr = s['nameFr'] as String;
        final nameAr = s['nameAr'] as String;
        final sur = s['sur'] as int;
        final keys = s['keys'] as List<String>;

        Map<String, dynamic>? matchedGrade;
        for (final g in grades) {
          final gName = (g['subject_name'] ?? g['name'] ?? g['matiere'] ?? '').toString().toLowerCase();
          if (keys.any((k) => gName.contains(k))) {
            matchedGrade = g;
            break;
          }
        }

        String col1 = '', col2 = '';
        if (matchedGrade != null) {
          final cw = matchedGrade['classwork_score'] ?? matchedGrade['devoir'] ?? matchedGrade['cw'];
          final ex = matchedGrade['exam_score'] ?? matchedGrade['examen'] ?? matchedGrade['ex'];
          final tot = matchedGrade['total_score'] ?? matchedGrade['note'] ?? matchedGrade['score'];

          if (cw != null && ex != null) {
            final cwNum = (cw as num).toDouble();
            final exNum = (ex as num).toDouble();
            col1 = cwNum.toStringAsFixed(1);
            col2 = exNum.toStringAsFixed(1);
            totalFr1 += (cwNum + exNum) / 2;
            countFr1++;
          } else if (tot != null) {
            final totNum = (tot as num).toDouble();
            col1 = totNum.toStringAsFixed(1);
            col2 = _getQualitativeMention(totNum);
            totalFr1 += totNum;
            countFr1++;
          } else if (ex != null) {
            final exNum = (ex as num).toDouble();
            col1 = exNum.toStringAsFixed(1);
            col2 = _getQualitativeMention(exNum);
            totalFr1 += exNum;
            countFr1++;
          }
        }

        rowsData.add([
          nameFr,
          nameAr,
          sur.toString(),
          currentCompIndex == 1 ? col1 : '',
          currentCompIndex == 1 ? col2 : '',
          currentCompIndex == 2 ? col1 : '',
          currentCompIndex == 2 ? col2 : '',
          currentCompIndex == 3 ? col1 : '',
          currentCompIndex == 3 ? col2 : '',
        ]);
      }
    }

    // Totals and averages
    final moyFr1 = countFr1 > 0 ? (totalFr1 / countFr1).toStringAsFixed(2) : '-';
    final moyAr1 = countAr1 > 0 ? (totalAr1 / countAr1).toStringAsFixed(2) : '-';

    final annAvg = (summary['annual_average'] as num?)?.toDouble() ??
        (summary['average'] as num?)?.toDouble() ??
        (summary['moyenne_annuelle'] as num?)?.toDouble() ??
        (summary['moyenne'] as num?)?.toDouble() ??
        0.0;
    final annRank = summary['annual_rank']?.toString() ??
        summary['rank']?.toString() ??
        summary['rang']?.toString() ??
        '-';
    final isAdmis = annAvg >= 10.0;
    final isRedouble = annAvg >= 8.0 && annAvg < 10.0;
    final isExclu = annAvg > 0.0 && annAvg < 8.0;

    final nextClass = _computePrimaryNextClass(className);
    String nextYear = '2025';
    if (sessionName.contains('-')) {
      final p = sessionName.split('-').last.trim();
      if (int.tryParse(p) != null) nextYear = p;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('ANNÉE SCOLAIRE : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(sessionName.isNotEmpty ? sessionName : '2024-2025', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Text(
                            isFrancoArabe
                                ? 'ENSEIGNEMENT PRIMAIRE FRANCO-ARABE (F.A)'
                                : 'ENSEIGNEMENT PRIMAIRE GÉNÉRAL (FRANÇAIS)',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Text("NOM DE L'ÉLÈVE : ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(studentName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        ],
                      ),
                    ],
                  ),
                  // Center Logo / Badge
                  pw.Column(
                    children: [
                      if (centerLogoImage != null)
                        pw.Image(centerLogoImage, width: 44, height: 44)
                      else
                        pw.Container(
                          width: 44,
                          height: 44,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(color: PdfColors.black, width: 1.2),
                          ),
                          child: pw.Center(
                            child: pw.Text('ÉCOLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          ),
                        ),
                    ],
                  ),
                  // Right info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('COURS : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(className.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text('TENU PAR : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          pw.Text('Mr : ................... ET Mr : ...................', style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 7),

              // 2. Main Content Split: Left Table (Notes) + Right Panel (Evaluation + Résultat)
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // LEFT PANEL: GRADES TABLE
                    pw.Expanded(
                      flex: 54,
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(3.4), // Matière
                          1: pw.FlexColumnWidth(0.9), // SUR
                          2: pw.FlexColumnWidth(1.1), // C1 Col1
                          3: pw.FlexColumnWidth(1.1), // C1 Col2
                          4: pw.FlexColumnWidth(1.1), // C2 Col1
                          5: pw.FlexColumnWidth(1.1), // C2 Col2
                          6: pw.FlexColumnWidth(1.1), // C3 Col1
                          7: pw.FlexColumnWidth(1.1), // C3 Col2
                        },
                        children: [
                          // Header 1
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.white),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                child: pw.Column(
                                  children: [
                                    pw.Text('Compositions', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                                    pw.Text('الامتحانات', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7.5)),
                                  ],
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Center(child: pw.Text('SUR\nعلى', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: amiriBold, fontSize: 6.5))),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Center(child: pw.Text('Composition N° 1', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              ),
                              pw.Container(), // Placeholder for visual span
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Center(child: pw.Text('Composition N° 2', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              ),
                              pw.Container(),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Center(child: pw.Text('Composition N° 3', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              ),
                              pw.Container(),
                            ],
                          ),
                          // Header 2
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Matières', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                    pw.Text('المواد', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                  ],
                                ),
                              ),
                              pw.Center(child: pw.Text('', style: const pw.TextStyle(fontSize: 6))),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? 'FR' : 'Devoir',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? 'العربية' : 'Compo',
                                  textDirection: isFrancoArabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                                  style: isFrancoArabe
                                      ? pw.TextStyle(font: amiriBold, fontSize: 6.5)
                                      : pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? 'FR' : 'Devoir',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? 'العربية' : 'Compo',
                                  textDirection: isFrancoArabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                                  style: isFrancoArabe
                                      ? pw.TextStyle(font: amiriBold, fontSize: 6.5)
                                      : pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? 'FR' : 'Devoir',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? 'العربية' : 'Compo',
                                  textDirection: isFrancoArabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                                  style: isFrancoArabe
                                      ? pw.TextStyle(font: amiriBold, fontSize: 6.5)
                                      : pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
                                ),
                              ),
                            ],
                          ),
                          // Subject rows
                          ...rowsData.map((row) {
                            return pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 3),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(row[0] as String, style: const pw.TextStyle(fontSize: 6.5)),
                                      pw.Text(row[1] as String, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                    ],
                                  ),
                                ),
                                pw.Center(child: pw.Text(row[2] as String, style: const pw.TextStyle(fontSize: 6.5))),
                                pw.Center(child: pw.Text(row[3] as String, style: const pw.TextStyle(fontSize: 6.5))),
                                pw.Center(child: pw.Text(row[4] as String, style: const pw.TextStyle(fontSize: 6.5))),
                                pw.Center(child: pw.Text(row[5] as String, style: const pw.TextStyle(fontSize: 6.5))),
                                pw.Center(child: pw.Text(row[6] as String, style: const pw.TextStyle(fontSize: 6.5))),
                                pw.Center(child: pw.Text(row[7] as String, style: const pw.TextStyle(fontSize: 6.5))),
                                pw.Center(child: pw.Text(row[8] as String, style: const pw.TextStyle(fontSize: 6.5))),
                              ],
                            );
                          }),
                          // Foot 1: Total / المجموع
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      isFrancoArabe ? 'Total' : 'Total Points',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                    ),
                                    pw.Text(
                                      isFrancoArabe ? 'المجموع' : 'مجموع النقاط',
                                      textDirection: pw.TextDirection.rtl,
                                      style: pw.TextStyle(font: amiriBold, fontSize: 7),
                                    ),
                                  ],
                                ),
                              ),
                              pw.Center(child: pw.Text('', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(
                                child: pw.Text(
                                  totalFr1 > 0 ? totalFr1.toStringAsFixed(1) : '-',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe
                                      ? (totalAr1 > 0 ? totalAr1.toStringAsFixed(1) : '-')
                                      : '-',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                ),
                              ),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                            ],
                          ),
                          // Foot 2: Moyenne / المعدل
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      isFrancoArabe ? 'Moyenne' : 'Moyenne / 20',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                    ),
                                    pw.Text('المعدل', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                  ],
                                ),
                              ),
                              pw.Center(child: pw.Text('', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text(moyFr1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? moyAr1 : '-',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                ),
                              ),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                            ],
                          ),
                          // Foot 3: Rang / الترتيب
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Rang', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                    pw.Text('الترتيب', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                  ],
                                ),
                              ),
                              pw.Center(child: pw.Text('', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text(summary['rank']?.toString() ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? (summary['rank']?.toString() ?? '-') : '-',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                ),
                              ),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                            ],
                          ),
                          // Foot 4: Moyenne Générale / معدل عام
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Moyenne Générale', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                    pw.Text('معدل عام', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                  ],
                                ),
                              ),
                              pw.Center(child: pw.Text('', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text(annAvg > 0 ? annAvg.toStringAsFixed(2) : '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? (annAvg > 0 ? annAvg.toStringAsFixed(2) : '-') : '-',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                ),
                              ),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                            ],
                          ),
                          // Foot 5: Rang Général / ترتيب عام
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Rang Général', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                    pw.Text('ترتيب عام', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                  ],
                                ),
                              ),
                              pw.Center(child: pw.Text('', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text(annRank, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5))),
                              pw.Center(
                                child: pw.Text(
                                  isFrancoArabe ? annRank : '-',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                                ),
                              ),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                              pw.Center(child: pw.Text('-', style: const pw.TextStyle(fontSize: 6.5))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(width: 14),

                    // RIGHT PANEL: EVALUATION TABLE & RESULTAT DE FIN D'ANNÉE
                    pw.Expanded(
                      flex: 46,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // 1. Evaluations Table
                          pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(2.0),
                              1: pw.FlexColumnWidth(2.6),
                              2: pw.FlexColumnWidth(1.8),
                              3: pw.FlexColumnWidth(1.8),
                            },
                            children: [
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(3),
                                    child: pw.Column(
                                      children: [
                                        pw.Text('التقويم والتوقيع', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7.5)),
                                        pw.Text('Composition', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                      ],
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(3),
                                    child: pw.Text('Observation\nDes enseignants', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(3),
                                    child: pw.Text('Visa du\nDirecteur', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(3),
                                    child: pw.Text('Visa du\nParents', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                  ),
                                ],
                              ),
                              ...List.generate(3, (i) {
                                final compNum = i + 1;
                                final obs = compNum == currentCompIndex ? (summary['appreciation'] ?? summary['observation'] ?? '') : '';
                                return pw.TableRow(
                                  children: [
                                    pw.Container(
                                      height: 38,
                                      padding: const pw.EdgeInsets.all(2),
                                      child: pw.Column(
                                        mainAxisAlignment: pw.MainAxisAlignment.center,
                                        children: [
                                          pw.Text('Composition N° $compNum', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5)),
                                          pw.Text('الشهر $compNum', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 7)),
                                        ],
                                      ),
                                    ),
                                    pw.Container(
                                      height: 38,
                                      padding: const pw.EdgeInsets.all(3),
                                      child: pw.Text(obs.isNotEmpty ? obs.toString() : '............................', style: const pw.TextStyle(fontSize: 6.5)),
                                    ),
                                    pw.Container(height: 38),
                                    pw.Container(height: 38),
                                  ],
                                );
                              }),
                            ],
                          ),

                          pw.SizedBox(height: 10),

                          // 2. RESULTAT DE FIN D'ANNÉE / نتيجة نهاية السنة
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.black, width: 1.2),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  // Title
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('RESULTAT DE FIN D\'ANNÉE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                      pw.Text('نتيجة نهاية السنة', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 11)),
                                    ],
                                  ),
                                  pw.Divider(color: PdfColors.black, thickness: 0.8),

                                  // Line 1: Stats
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Row(
                                        children: [
                                          pw.Text('Moyenne Annuelle : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                                          pw.Text(annAvg > 0 ? annAvg.toStringAsFixed(2) : '.......', style: const pw.TextStyle(fontSize: 8)),
                                          pw.SizedBox(width: 8),
                                          pw.Text('Rang : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                                          pw.Text(annRank, style: const pw.TextStyle(fontSize: 8)),
                                          pw.SizedBox(width: 8),
                                          pw.Text('Sur : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                                          pw.Text('30', style: const pw.TextStyle(fontSize: 8)),
                                        ],
                                      ),
                                      pw.Row(
                                        children: [
                                          pw.Text('على : 30', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 8.5)),
                                          pw.SizedBox(width: 6),
                                          pw.Text('الترتيب : $annRank', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 8.5)),
                                          pw.SizedBox(width: 6),
                                          pw.Text('معدل سنوي : ${annAvg > 0 ? annAvg.toStringAsFixed(2) : "......."}', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: amiriBold, fontSize: 8.5)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),

                                  // Line 2: Admis
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        '${isAdmis ? "[X]" : "[  ]"} Admis au ${isAdmis ? nextClass : "......."} à la rentrée de l\'année $nextYear',
                                        style: pw.TextStyle(fontWeight: isAdmis ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 8),
                                      ),
                                      pw.Text(
                                        'نجح إلى : ${isAdmis ? nextClass : "......."}',
                                        textDirection: pw.TextDirection.rtl,
                                        style: pw.TextStyle(font: amiriBold, fontSize: 8.5),
                                      ),
                                    ],
                                  ),
                                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),

                                  // Line 3: Redouble
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        '${isRedouble ? "[X]" : "[  ]"} Redouble La classe de : ${isRedouble ? className : "......."}',
                                        style: pw.TextStyle(fontWeight: isRedouble ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 8),
                                      ),
                                      pw.Text(
                                        'راسب في فصل : ${isRedouble ? className : "......."}',
                                        textDirection: pw.TextDirection.rtl,
                                        style: pw.TextStyle(font: amiriBold, fontSize: 8.5),
                                      ),
                                    ],
                                  ),
                                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),

                                  // Line 4: Exclu
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        '${isExclu ? "[X]" : "[  ]"} Exclu de l\'école pour : ${isExclu ? "Insuffisance" : "......................."}',
                                        style: pw.TextStyle(fontWeight: isExclu ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 8),
                                      ),
                                      pw.Text(
                                        'طُرد من المدرسة من أجل : .......................',
                                        textDirection: pw.TextDirection.rtl,
                                        style: pw.TextStyle(font: amiriBold, fontSize: 8.5),
                                      ),
                                    ],
                                  ),
                                  pw.Divider(color: PdfColors.grey400, thickness: 0.6),

                                  // Signatures
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('Fait à ........................, le ................', style: const pw.TextStyle(fontSize: 7.5)),
                                      pw.Text('Visa & Cachet du Directeur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 3),

              // Bottom Duplicata Notice
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(
                  'DUPLICATA NUMÉRIQUE NON ORIGINAL GÉNÉRÉ VIA L\'APPLICATION EDUT — SEUL LE BULLETIN PHYSIQUE REVÊTU DU CACHET ET DE LA SIGNATURE FAIT FOI',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HEADER
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String country,
    required String ministry,
    required String schoolName,
    required String address,
    required String phone,
    required String sessionName,
    pw.MemoryImage? logo,
    required pw.Font amiriBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo900, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 50,
              height: 50,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  country.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  ministry.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  schoolName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (address.isNotEmpty || phone.isNotEmpty)
                  pw.Text(
                    [address, phone.isNotEmpty ? 'Tél: $phone' : ''].where((e) => e.isNotEmpty).join(' | '),
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                  ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.indigo200),
            ),
            child: pw.Column(
              children: [
                pw.Text('ANNÉE ACADÉMIQUE', style: const pw.TextStyle(fontSize: 6, color: PdfColors.indigo900)),
                pw.Text(sessionName.isNotEmpty ? sessionName : '2024-2025',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  STAGE SPECIFIC TITLE BANNER
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildStageTitleBanner(EducationalStage stage, String period) {
    String title;
    String subTitle;
    PdfColor bannerColor;

    switch (stage) {
      case EducationalStage.maternelle:
        title = 'CARNET DE SUIVI & ÉVALUATIONS (MATERNELLE)';
        subTitle = 'PÉRIODE : ${period.toUpperCase()}';
        bannerColor = PdfColors.pink800;
        break;
      case EducationalStage.primaire:
        title = 'CARNET DE NOTES & COMPÉTENCES (PRIMAIRE)';
        subTitle = 'PÉRIODE : ${period.toUpperCase()}';
        bannerColor = PdfColors.teal800;
        break;
      case EducationalStage.college:
        title = 'BULLETIN DE NOTES DU PREMIER CYCLE (COLLÈGE)';
        subTitle = 'ÉVALUATION : ${period.toUpperCase()}';
        bannerColor = PdfColors.indigo900;
        break;
      case EducationalStage.lycee:
        title = 'BULLETIN DE NOTES DU SECOND CYCLE (LYCÉE)';
        subTitle = 'BILAN SEMESTRIEL / TRIMESTRIEL : ${period.toUpperCase()}';
        bannerColor = PdfColors.blue900;
        break;
      case EducationalStage.universite:
        title = 'RELEVÉ DE NOTES & RÉSULTATS ACADÉMIQUES (LMD)';
        subTitle = 'SEMESTRE : ${period.toUpperCase()}';
        bannerColor = PdfColors.purple900;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bannerColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10, letterSpacing: 0.8),
          ),
          pw.Text(
            subTitle,
            style: pw.TextStyle(color: PdfColors.amber200, fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  STUDENT INFO BOX
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildStudentInfoBox({
    required String name,
    required String matricule,
    required String className,
    required String rawLevel,
    required String birthDate,
    required String birthPlace,
    required String gender,
    required String sessionName,
    required EducationalStage stage,
  }) {
    final String levelLabel = stage == EducationalStage.universite
        ? 'Parcours / Filière'
        : stage == EducationalStage.lycee
            ? 'Série / Niveau'
            : 'Niveau d\'études';

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Nom & Prénom(s) : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.Text(name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.indigo900)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text('Matricule / ID : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(matricule, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(width: 12),
                    pw.Text('Sexe : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(gender, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(width: 1, height: 30, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Classe : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.Text(className, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.indigo900)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text('$levelLabel : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(rawLevel.isNotEmpty ? rawLevel : className, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  GRADES TABLES BY STAGE
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildGradesTable(EducationalStage stage, List<Map<String, dynamic>> grades) {
    switch (stage) {
      case EducationalStage.maternelle:
      case EducationalStage.primaire:
        return _buildPrimaireTable(grades);
      case EducationalStage.college:
        return _buildCollegeTable(grades);
      case EducationalStage.lycee:
        return _buildLyceeTable(grades);
      case EducationalStage.universite:
        return _buildUniversiteTable(grades);
    }
  }

  static pw.Widget _buildNonOriginalBanner() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFEF2F2), // red 50
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFDC2626), width: 0.8), // red 600
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            '⚠️  DUPLICATA NUMÉRIQUE NON ORIGINAL — DOCUMENT INFORMATIF (ÉDITION MOBILE)',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7.5,
              color: const PdfColor.fromInt(0xFF991B1B), // red 800
            ),
          ),
        ],
      ),
    );
  }

  /// 1. PRIMAIRE TABLE
  static pw.Widget _buildPrimaireTable(List<Map<String, dynamic>> grades) {
    final headers = ['Discipline / Domaine', 'Note / 20', 'Moy. Classe', 'Compétences & Appréciations'];

    final rows = grades.map((g) {
      final subject = g['school_subjects']?['subject_name']?.toString() ??
          g['subject_name']?.toString() ??
          g['discipline']?.toString() ??
          'Discipline';
      final score = (g['total_score'] as num?)?.toDouble() ?? 0.0;
      final classAvg = (g['class_avg'] as num?)?.toDouble() ?? 12.5;
      final appreciation = g['appreciation']?.toString() ?? (score >= 16
          ? 'Très bien acquis'
          : score >= 13
              ? 'Bien acquis'
              : score >= 10
                  ? 'Acquis'
                  : 'En voie d\'acquisition');

      return [
        subject,
        score.toStringAsFixed(2),
        classAvg.toStringAsFixed(1),
        appreciation,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['Aucune matière', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(3.5),
      },
    );
  }

  /// 2. COLLÈGE TABLE
  static pw.Widget _buildCollegeTable(List<Map<String, dynamic>> grades) {
    final headers = ['Discipline', 'Devoir /20', 'Compo /20', 'Moy /20', 'Coef', 'Total', 'Rang', 'Appréciation Professeur'];

    int sumCoef = 0;
    double sumPoints = 0.0;
    final rows = <List<String>>[];

    for (final g in grades) {
      final subject = g['school_subjects']?['subject_name']?.toString() ??
          g['subject_name']?.toString() ??
          g['discipline']?.toString() ??
          g['matiere']?.toString() ??
          'Discipline';

      final rawDevoir = (g['class_work_score'] as num?)?.toDouble() ??
          (g['devoir_score'] as num?)?.toDouble();
      final rawCompo = (g['exam_score'] as num?)?.toDouble();
      final rawTotal = (g['total_score'] as num?)?.toDouble();

      double devoir = 0.0;
      double compo = 0.0;
      double score = 0.0;

      if (rawDevoir != null && rawCompo != null && rawDevoir > 0 && rawCompo > 0) {
        devoir = rawDevoir <= 20.0 ? rawDevoir : (rawDevoir / 2.0);
        compo = rawCompo <= 20.0 ? rawCompo : (rawCompo / 2.0);
        score = (devoir + compo) / 2.0;
      } else if (rawTotal != null && rawTotal > 0) {
        if (rawTotal <= 20.0) {
          score = rawTotal;
        } else if (rawTotal <= 40.0) {
          score = rawTotal / 2.0;
        } else {
          score = (rawTotal / 100.0) * 20.0;
        }
        if (rawDevoir != null && rawDevoir > 0) {
          devoir = rawDevoir <= 20.0 ? rawDevoir : (rawDevoir / 2.0);
          compo = (score * 2.0) - devoir;
          if (compo < 0) compo = score;
        } else if (rawCompo != null && rawCompo > 0) {
          compo = rawCompo <= 20.0 ? rawCompo : (rawCompo / 2.0);
          devoir = (score * 2.0) - compo;
          if (devoir < 0) devoir = score;
        } else {
          devoir = score;
          compo = score;
        }
      } else if (rawCompo != null && rawCompo > 0) {
        compo = rawCompo <= 20.0 ? rawCompo : (rawCompo / 2.0);
        devoir = compo;
        score = compo;
      } else if (rawDevoir != null && rawDevoir > 0) {
        devoir = rawDevoir <= 20.0 ? rawDevoir : (rawDevoir / 2.0);
        compo = devoir;
        score = devoir;
      }

      score = score.clamp(0.0, 20.0);
      devoir = devoir.clamp(0.0, 20.0);
      compo = compo.clamp(0.0, 20.0);

      // Resolve coefficient: read coefficient or coef, else use official national curriculum coefficients
      int coef = (g['coefficient'] as num?)?.toInt() ??
          (g['coef'] as num?)?.toInt() ?? 0;

      if (coef <= 0) {
        final subLower = subject.toLowerCase();
        if (subLower.contains('arabe') ||
            subLower.contains('français') ||
            subLower.contains('islam') ||
            subLower.contains('physique') ||
            subLower.contains('eps') ||
            subLower.contains('anglais')) {
          coef = 4;
        } else if (subLower.contains('math') ||
            subLower.contains('hist') ||
            subLower.contains('géo')) {
          coef = 3;
        } else if (subLower.contains('conduite')) {
          coef = 1;
        } else {
          coef = 2;
        }
      }

      final points = score * coef;
      sumCoef += coef;
      sumPoints += points;

      final rank = g['rank']?.toString() ?? '-';
      final appreciation = g['appreciation']?.toString() ??
          (score >= 16
              ? 'Excellent'
              : score >= 14
                  ? 'Bien'
                  : score >= 12
                      ? 'Assez Bien'
                      : score >= 10
                          ? 'Passable'
                          : 'Médiocre');

      rows.add([
        subject,
        devoir.toStringAsFixed(2),
        compo.toStringAsFixed(2),
        score.toStringAsFixed(2),
        coef.toString(),
        points.toStringAsFixed(2),
        rank,
        appreciation,
      ]);
    }

    if (rows.isNotEmpty) {
      final moyGen = sumCoef > 0 ? (sumPoints / sumCoef) : 0.0;
      rows.add([
        'TOTAL GÉNÉRAL',
        '-',
        '-',
        '-',
        sumCoef.toString(),
        sumPoints.toStringAsFixed(2),
        '-',
        'Moy: ${moyGen.toStringAsFixed(2)} / 20',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['Aucune matière', '-', '-', '-', '-', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(0.8),
        7: const pw.FlexColumnWidth(2.6),
      },
    );
  }

  /// 3. LYCÉE TABLE
  static pw.Widget _buildLyceeTable(List<Map<String, dynamic>> grades) {
    final headers = ['Matière', 'Éval. Continue', 'Compo', 'Moyenne /20', 'Coef', 'Points', 'Rang', 'Min-Max Classe', 'Visa & Appréciation'];

    int sumCoef = 0;
    double sumPoints = 0.0;
    final rows = <List<String>>[];

    for (final g in grades) {
      final subject = g['school_subjects']?['subject_name']?.toString() ??
          g['subject_name']?.toString() ??
          g['discipline']?.toString() ??
          g['matiere']?.toString() ??
          'Matière';

      final rawDevoir = (g['class_work_score'] as num?)?.toDouble() ??
          (g['devoir_score'] as num?)?.toDouble();
      final rawCompo = (g['exam_score'] as num?)?.toDouble();
      final rawTotal = (g['total_score'] as num?)?.toDouble();

      double devoir = rawDevoir ?? 0.0;
      double compo = rawCompo ?? devoir;
      double score = 0.0;

      if (rawDevoir != null && rawCompo != null && rawDevoir > 0 && rawCompo > 0) {
        devoir = rawDevoir <= 20.0 ? rawDevoir : (rawDevoir / 2.0);
        compo = rawCompo <= 20.0 ? rawCompo : (rawCompo / 2.0);
        score = (devoir + compo) / 2.0;
      } else if (rawTotal != null && rawTotal > 0) {
        score = rawTotal <= 20.0 ? rawTotal : (rawTotal <= 40.0 ? rawTotal / 2.0 : (rawTotal / 100.0) * 20.0);
        devoir = score;
        compo = score;
      } else {
        score = compo > 0 ? compo : devoir;
      }

      int coef = (g['coefficient'] as num?)?.toInt() ??
          (g['coef'] as num?)?.toInt() ?? 0;
      if (coef <= 0) {
        coef = 3;
      }

      final points = score * coef;
      sumCoef += coef;
      sumPoints += points;

      final rank = g['rank']?.toString() ?? '-';
      final minMax = '${(g['min_score'] ?? 8).toStringAsFixed(0)} - ${(g['max_score'] ?? 18).toStringAsFixed(0)}';
      final appreciation = g['appreciation']?.toString() ??
          (score >= 16 ? 'Très satisfaisant' : score >= 12 ? 'Bon travail' : score >= 10 ? 'Travail convenable' : 'Insuffisant');

      rows.add([
        subject,
        devoir.toStringAsFixed(1),
        compo.toStringAsFixed(1),
        score.toStringAsFixed(2),
        coef.toString(),
        points.toStringAsFixed(2),
        rank,
        minMax,
        appreciation,
      ]);
    }

    if (rows.isNotEmpty) {
      final moyGen = sumCoef > 0 ? (sumPoints / sumCoef) : 0.0;
      rows.add([
        'TOTAL GÉNÉRAL',
        '-',
        '-',
        '-',
        sumCoef.toString(),
        sumPoints.toStringAsFixed(2),
        '-',
        '-',
        'Moy: ${moyGen.toStringAsFixed(2)} / 20',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['Aucune matière', '-', '-', '-', '-', '-', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(1.3),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(0.8),
        7: const pw.FlexColumnWidth(1.3),
        8: const pw.FlexColumnWidth(2.2),
      },
    );
  }

  /// 4. UNIVERSITÉ / LICENCE / MASTER (LMD) TABLE
  static pw.Widget _buildUniversiteTable(List<Map<String, dynamic>> grades) {
    final headers = ['Code UE', 'Intitulé de l\'Unité d\'Enseignement', 'CC /20', 'Examen /20', 'Moyenne /20', 'Crédits ECTS', 'Résultat UE', 'Session'];

    final rows = grades.map((g) {
      final code = g['subject_code']?.toString() ?? 'UE';
      final subject = g['subject_name']?.toString() ?? 'Enseignement';
      final cc = (g['cc_score'] as num?)?.toDouble() ?? (g['total_score'] as num?)?.toDouble() ?? 0.0;
      final exam = (g['exam_score'] as num?)?.toDouble() ?? cc;
      final moy = (g['total_score'] as num?)?.toDouble() ?? ((cc * 0.4) + (exam * 0.6));
      final credits = (g['credits'] as num?)?.toInt() ?? 6;
      final isValid = moy >= 10.0;
      final result = isValid ? 'VALIDÉ (V)' : 'NON VALIDÉ (NV)';

      return [
        code,
        subject,
        cc.toStringAsFixed(1),
        exam.toStringAsFixed(1),
        moy.toStringAsFixed(2),
        credits.toString(),
        result,
        'Normale',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isNotEmpty ? rows : [['-', 'Aucune unité d\'enseignement', '-', '-', '-', '-', '-', '-']],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.purple900),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(3.8),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.3),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(1.8),
        7: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SUMMARY & DECISION BOX
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSummaryAndDecisionBox(EducationalStage stage, Map<String, dynamic> summary) {
    final avg = (summary['average'] as num?)?.toDouble() ?? 0.0;
    final totalPoints = (summary['totalPoints'] as num?)?.toDouble() ?? 0.0;
    final totalCoef = (summary['totalCoef'] as num?)?.toInt() ?? 1;
    final rank = summary['rank']?.toString() ?? '1er';
    final classAvg = (summary['classAvg'] as num?)?.toDouble() ?? 12.0;
    final pointsInfo = totalPoints > 0 ? ' | Total: ${totalPoints.toStringAsFixed(1)} (Coef: $totalCoef)' : '';

    String mention = 'Passable';
    if (avg >= 16) {
      mention = 'Très Bien';
    } else if (avg >= 14) {
      mention = 'Bien';
    } else if (avg >= 12) {
      mention = 'Assez Bien';
    } else if (avg < 10) {
      mention = 'Ajourné / Insuffisant';
    }

    String decision = avg >= 10 ? 'Admis(e) en classe supérieure' : 'À surveiller / Rattrapage';
    if (stage == EducationalStage.universite) {
      decision = avg >= 10 ? 'Semestre Validé avec Mention' : 'Semestre Non Validé - Session de Rattrapage';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('MOYENNE GÉNÉRALE : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
                  pw.Text('${avg.toStringAsFixed(2)} / 20', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: avg >= 10 ? PdfColors.green800 : PdfColors.red800)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text('Moyenne de la classe : ${classAvg.toStringAsFixed(2)} / 20 | Rang : $rank$pointsInfo', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  pw.Text('Mention : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                  pw.Text(mention, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.indigo900)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text('Décision : $decision', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: avg >= 10 ? PdfColors.green800 : PdfColors.red800)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SIGNATURES
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSignaturesBlock(EducationalStage stage) {
    String sig1 = 'Le Maître / Enseignant';
    String sig2 = 'Le Directeur de l\'École';

    if (stage == EducationalStage.maternelle) {
      sig1 = 'L\'Éducateur / Éducatrice';
      sig2 = 'La Direction de l\'Établissement';
    } else if (stage == EducationalStage.college) {
      sig1 = 'Le Professeur Principal';
      sig2 = 'Le Principal du Collège';
    } else if (stage == EducationalStage.lycee) {
      sig1 = 'Le Professeur Principal';
      sig2 = 'Le Proviseur du Lycée';
    } else if (stage == EducationalStage.universite) {
      sig1 = 'Le Chef de Département';
      sig2 = 'Le Doyen / Directeur Académique';
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return pw.Column(
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(sig1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.SizedBox(height: 20),
                  pw.Text('(Signature & Visa)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Fait le : $dateStr', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  pw.SizedBox(height: 3),
                  pw.Text(sig2, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.SizedBox(height: 16),
                  pw.Text('(Sceau & Signature Officielle)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(3),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Text(
            'AVIS IMPORTANT : Le présent document est un DUPLICATA NUMÉRIQUE NON ORIGINAL généré via l\'application mobile Edut pour information des parents et élèves. '
            'Il ne constitue en aucun cas le Bulletin de Notes officiel original. Seul le document physique revêtu du cachet humide officiel et de la signature manuscrite du Chef d\'Établissement fait foi.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }
}
