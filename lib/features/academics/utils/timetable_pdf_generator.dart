import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TimetablePdfGenerator {
  /// Generate Official A4 Landscape Timetable PDF Bytes
  static Future<Uint8List> generateTimetableBytes({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> timetableEntries,
    required String className,
    required String sessionName,
    String? schoolName,
  }) async {
    final pdf = pw.Document();

    final regularFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    final semiBoldFont = await PdfGoogleFonts.interSemiBold();

    final studentName = student['nom_etudiant'] ?? student['nomEtudiant'] ?? 'Élève';
    final matricule = student['num_admission'] ?? student['numAdmission'] ?? 'N/A';
    final establishmentName = (schoolName != null && schoolName.isNotEmpty)
        ? schoolName.toUpperCase()
        : 'ÉTABLISSEMENT D\'EXCELLENCE - EDUT PRO';

    final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

    // Determine max period count
    int maxPeriod = 6;
    for (final e in timetableEntries) {
      final p = (e['period_number'] as num?)?.toInt() ?? 0;
      if (p > maxPeriod) maxPeriod = p;
    }

    String getPeriodTime(int p) {
      final startMin = (8 * 60) + ((p - 1) * 60) + (p > 3 ? 30 : 0);
      final endMin = startMin + 60;
      final sH = (startMin ~/ 60).toString().padLeft(2, '0');
      final sM = (startMin % 60).toString().padLeft(2, '0');
      final eH = (endMin ~/ 60).toString().padLeft(2, '0');
      final eM = (endMin % 60).toString().padLeft(2, '0');
      return '${sH}h$sM - ${eH}h$eM';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          fontFallback: [regularFont, boldFont],
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ─── 1. Header ───
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Republic
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RÉPUBLIQUE DU NIGER',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9,
                            letterSpacing: 0.5,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.Text(
                          'MINISTÈRE DE L\'ENSEIGNEMENT SUPÉRIEUR / ÉDUCATION',
                          style: pw.TextStyle(
                            font: semiBoldFont,
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          establishmentName,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 11,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),

                    // Center Badge
                    pw.Column(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue900,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            'EMPLOI DU TEMPS OFFICIEL',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: PdfColors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'CLASSE : $className',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.Text(
                          'Année Académique : $sessionName',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),

                    // Right Student Details
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          studentName,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9.5,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.Text(
                          'Matricule : $matricule',
                          style: pw.TextStyle(
                            font: semiBoldFont,
                            fontSize: 8,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.Text(
                          'Édité le : ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 7.5,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ─── 2. Weekly Timetable Grid Table ───
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.blueGrey300,
                    width: 0.8,
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(85),
                    for (int i = 1; i <= days.length; i++)
                      i: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF1F5F9),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                          child: pw.Text(
                            'HORAIRE / PÉRIODE',
                            style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: PdfColors.blueGrey900),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        ...days.map(
                          (d) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                            child: pw.Text(
                              d.toUpperCase(),
                              style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.blueGrey900),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Period Rows
                    ...List.generate(maxPeriod, (index) {
                      final pNum = index + 1;
                      final isRecess = pNum == 4;

                      return [
                        if (isRecess)
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFFEF3C7),
                            ),
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                                child: pw.Center(
                                  child: pw.Text(
                                    '09h30 - 10h00',
                                    style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.amber900),
                                  ),
                                ),
                              ),
                              ...List.generate(
                                days.length,
                                (i) => pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                                  child: pw.Center(
                                    child: pw.Text(
                                      '☕ PAUSE / RÉCRÉATION (30 MIN)',
                                      style: pw.TextStyle(font: boldFont, fontSize: 6.5, color: PdfColors.amber900),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        pw.TableRow(
                          children: [
                            // Period Column
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              color: const PdfColor.fromInt(0xFFF8FAFC),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'Période $pNum',
                                    style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.blueGrey900),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    getPeriodTime(pNum),
                                    style: pw.TextStyle(font: regularFont, fontSize: 6.5, color: PdfColors.grey700),
                                  ),
                                ],
                              ),
                            ),

                            // Day slots
                            ...days.map((day) {
                              final entry = timetableEntries.firstWhere(
                                (e) =>
                                    (e['day_name']?.toString().toLowerCase() == day.toLowerCase()) &&
                                    ((e['period_number'] as num?)?.toInt() == pNum),
                                orElse: () => {},
                              );

                              if (entry.isEmpty) {
                                return pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Center(
                                    child: pw.Text('—', style: pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
                                  ),
                                );
                              }

                              final subject = entry['school_subjects']?['subject_name'] ??
                                  entry['subjectName'] ??
                                  'Matière';
                              final teacher = entry['employees']?['nom'] ??
                                  entry['teacherName'] ??
                                  '';
                              final room = entry['room_name'] ?? entry['roomName'] ?? '';

                              return pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      subject,
                                      style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 7.5,
                                        color: PdfColors.blue900,
                                      ),
                                      maxLines: 2,
                                    ),
                                    if (teacher.isNotEmpty) ...[
                                      pw.SizedBox(height: 1.5),
                                      pw.Text(
                                        teacher,
                                        style: pw.TextStyle(
                                          font: semiBoldFont,
                                          fontSize: 6.5,
                                          color: PdfColors.grey800,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ],
                                    if (room.isNotEmpty) ...[
                                      pw.SizedBox(height: 1),
                                      pw.Text(
                                        'Salle : $room',
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 6,
                                          color: PdfColors.teal800,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ];
                    }).expand((element) => element).toList(),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // ─── 3. Official Footer ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Document académique officiel généré via la plateforme Edut Pro.',
                        style: pw.TextStyle(font: regularFont, fontSize: 6.5, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Toute modification ou falsification de ce document entraîne des sanctions disciplinaires.',
                        style: pw.TextStyle(font: regularFont, fontSize: 6, color: PdfColors.grey500),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DIRECTION DES ÉTUDES',
                        style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Cachet et Visa de l\'Établissement',
                        style: pw.TextStyle(font: regularFont, fontSize: 6.5, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
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

    return pdf.save();
  }

  /// Direct Print or Share action
  static Future<void> printOrShareTimetable({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> timetableEntries,
    required String className,
    required String sessionName,
    String? schoolName,
  }) async {
    final bytes = await generateTimetableBytes(
      student: student,
      timetableEntries: timetableEntries,
      className: className,
      sessionName: sessionName,
      schoolName: schoolName,
    );

    final cleanName = (student['nom_etudiant'] ?? 'Eleve').toString().replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Emploi_du_temps_${className}_$cleanName.pdf',
    );
  }
}
