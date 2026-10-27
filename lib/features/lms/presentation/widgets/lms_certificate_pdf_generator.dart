import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LmsCertificatePdfGenerator {
  /// Generates and previews / prints the certificate PDF in landscape format
  static Future<void> printCertificate({
    required String studentName,
    required String courseTitle,
    required String certificateCode,
    String? issueDate,
    String? schoolName,
  }) async {
    final pdf = await _buildPdf(
      studentName: studentName,
      courseTitle: courseTitle,
      certificateCode: certificateCode,
      issueDate: issueDate,
      schoolName: schoolName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf,
      name: 'Certificat_$certificateCode.pdf',
    );
  }

  /// Shares the certificate PDF directly
  static Future<void> shareCertificate({
    required String studentName,
    required String courseTitle,
    required String certificateCode,
    String? issueDate,
    String? schoolName,
  }) async {
    final pdf = await _buildPdf(
      studentName: studentName,
      courseTitle: courseTitle,
      certificateCode: certificateCode,
      issueDate: issueDate,
      schoolName: schoolName,
    );

    await Printing.sharePdf(
      bytes: pdf,
      filename: 'Certificat_$certificateCode.pdf',
    );
  }

  static Future<Uint8List> _buildPdf({
    required String studentName,
    required String courseTitle,
    required String certificateCode,
    String? issueDate,
    String? schoolName,
  }) async {
    final doc = pw.Document();
    final dateStr = issueDate ?? DateTime.now().toString().split(' ').first;
    final institution = schoolName ?? 'EDUT - PLATEFORME ÉDUCATIVE DIGITALE';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber800, width: 4),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              color: PdfColors.white,
            ),
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Header
                pw.Column(
                  children: [
                    pw.Text(
                      institution.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'CERTIFICAT DE RÉUSSITE & D\'ACQUISITION DE COMPÉTENCES',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                        letterSpacing: 1.5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 8),
                      height: 2,
                      width: 140,
                      color: PdfColors.amber800,
                    ),
                  ],
                ),

                // Body
                pw.Column(
                  children: [
                    pw.Text(
                      'Ce certificat officiel est décerné à :',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      studentName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Pour avoir suivi avec assiduité et validé avec succès l\'ensemble des modules et évaluations de la formation :',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        courseTitle,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                // Footer with Date, Verification Code & Signature line
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Délivré le : $dateStr',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Code de vérification : $certificateCode',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo800,
                          ),
                        ),
                        pw.Text(
                          'Vérifiable en ligne sur la plateforme Edut LMS',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 1,
                          color: PdfColors.grey500,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Direction Pédagogique & Certification',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.Text(
                          'Cachet & Signature Électronique',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
