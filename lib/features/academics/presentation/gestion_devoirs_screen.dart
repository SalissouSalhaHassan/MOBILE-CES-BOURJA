import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/sync_engine.dart';
import '../data/academics_repository.dart';
import '../../ai/data/ai_repository.dart';
import '../../../core/utils/type_converters.dart';

class GestionDevoirsScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;

  const GestionDevoirsScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<GestionDevoirsScreen> createState() => _GestionDevoirsScreenState();
}

class _GestionDevoirsScreenState extends State<GestionDevoirsScreen> {
  final AcademicsRepository _repository = locator<AcademicsRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExportingPdf = false;
  bool _canManageAcademics = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _periods = [];

  int? _selectedSessionId;
  String _selectedSessionName = '';
  String _selectedPeriodName = '';
  int _coefficient = 1;
  bool _isEditable = true;
  String? _lockReason;
  int _schoolId = 1;

  final TextEditingController _searchController = TextEditingController();
  String _activeFilterStatus = 'all'; // all, evaluated, pending, danger

  // Map of studentId -> List of 5 Controllers (for devoir1 to devoir5)
  final Map<int, List<TextEditingController>> _devoirControllers = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controllersList in _devoirControllers.values) {
      for (var controller in controllersList) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final isOnline = locator<SyncEngine>().isOnlineNotifier.value;
    final profile = await locator<PermissionService>().getCurrentProfile(forceRefresh: isOnline);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canManageAcademics = profile.permissions.contains(AppPermissions.gestionDevoirsEdit);
    });

    try {
      final sessionManager = locator<SessionManager>();
      
      // 1. Retrieve schoolId directly from local session (offline-safe)
      final schoolIdStr = await sessionManager.getSchoolId();
      int schoolId = int.tryParse(schoolIdStr ?? '') ?? 1;
      _schoolId = schoolId;

      // 2. Only query Supabase DB if schoolId is missing/default to 1 AND online
      if (schoolId == 1 && isOnline) {
        final employeeIdStr = await sessionManager.getEmployeeId();
        final employeeId = int.tryParse(employeeIdStr ?? '');
        if (employeeId != null) {
          try {
            final client = SupabaseClientManager().client;
            final List<dynamic> empInfo = await client
                .from('employees')
                .select('school_id')
                .eq('id', employeeId);
            if (empInfo.isNotEmpty && empInfo.first['school_id'] != null) {
              schoolId = TypeConverters.safeInt(empInfo.first['school_id'], schoolId);
              _schoolId = schoolId;
            }
          } catch (e) {
            debugPrint("⚠️ Could not query schoolId from Supabase: $e");
          }
        }
      }

      // Fetch sessions
      _sessions = await _repository.getSessions(schoolId);

      if (_sessions.isNotEmpty) {
        final activeSession = _sessions.firstWhere(
          (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
          orElse: () => _sessions.first,
        );
        _selectedSessionId = TypeConverters.safeInt(activeSession['id'], 1);
        _selectedSessionName = activeSession['session_name']?.toString() ?? '';

        // Fetch periods
        _periods = await _repository.getPeriods(schoolId, _selectedSessionId!, classId: widget.classId);
        if (_periods.isNotEmpty) {
          final activePeriod = _periods.firstWhere(
            (p) => p['is_active'] == true,
            orElse: () => _periods.first,
          );
          _selectedPeriodName = activePeriod['name'] as String;
        }
      }

      if (_selectedSessionId != null && _selectedPeriodName.isNotEmpty) {
        await _fetchDevoirData(schoolId);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Aucune session ou période académique trouvée.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur d'initialisation: $e";
      });
    }
  }

  Future<void> _fetchDevoirData(int schoolId) async {
    if (_selectedSessionId == null || _selectedPeriodName.isEmpty) return;

    try {
      final result = await _repository.getDevoirGrid(
        classId: widget.classId,
        subjectId: widget.subjectId,
        sessionId: _selectedSessionId!,
        term: _selectedPeriodName,
        schoolId: schoolId,
        className: widget.className,
      );

      if (result['success'] == true) {
        _isEditable = result['is_editable'] as bool? ?? true;
        _lockReason = result['lock_reason'] as String?;
        _coefficient = TypeConverters.safeInt(result['coefficient'], 1);
        final List rawData = result['data'] is List ? (result['data'] as List) : [];
        _students = rawData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // Initialize controllers for devoirs
        _devoirControllers.clear();

        for (var student in _students) {
          final sId = TypeConverters.safeInt(student['student_id'] ?? student['id']);
          final List<dynamic> devoirsList = student['devoirs'] is List ? (student['devoirs'] as List<dynamic>) : [];

          final List<TextEditingController> controllers = [];
          for (int i = 0; i < 5; i++) {
            final devRaw = i < devoirsList.length ? devoirsList[i] : null;
            final devVal = (devRaw != null && devRaw.toString().trim().isNotEmpty)
                ? (num.tryParse(devRaw.toString())?.toStringAsFixed(2).replaceAll('.00', '') ?? devRaw.toString())
                : '';
            controllers.add(TextEditingController(text: devVal));
          }
          _devoirControllers[sId] = controllers;
        }

        _applyFilters();

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['error'] ?? "Une erreur est survenue.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur lors du chargement des devoirs: $e";
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = (s['nom_etudiant'] as String? ?? '').toLowerCase();
        final code = (s['num_admission'] as String? ?? '').toLowerCase();
        final matchesSearch = query.isEmpty || name.contains(query) || code.contains(query);
        if (!matchesSearch) return false;

        final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
        final controllers = _devoirControllers[sId];
        final hasGrade = controllers?.any((c) => c.text.trim().isNotEmpty) ?? false;
        final avg = _getLiveAverage(sId);

        if (_activeFilterStatus == 'evaluated') return hasGrade;
        if (_activeFilterStatus == 'pending') return !hasGrade;
        if (_activeFilterStatus == 'danger') return hasGrade && avg < 10.0;
        return true;
      }).toList();
    });
  }

  // Calculate live devoir average for a student row
  double _getLiveAverage(int studentId) {
    final controllers = _devoirControllers[studentId];
    if (controllers == null) return 0.0;

    final values = controllers
        .map((c) => double.tryParse(c.text))
        .where((v) => v != null)
        .cast<double>()
        .toList();

    if (values.isEmpty) return 0.0;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  // Real-time Class Statistics
  Map<String, dynamic> _calculateClassStats() {
    int evaluatedCount = 0;
    double sumAverages = 0.0;
    double maxScore = 0.0;
    double minScore = 20.0;
    String topStudent = '-';
    int passCount = 0;

    for (var s in _students) {
      final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
      final controllers = _devoirControllers[sId];
      final hasGrade = controllers?.any((c) => c.text.trim().isNotEmpty) ?? false;

      if (hasGrade) {
        final avg = _getLiveAverage(sId);
        evaluatedCount++;
        sumAverages += avg;
        if (avg >= 10.0) passCount++;

        if (avg > maxScore || evaluatedCount == 1) {
          maxScore = avg;
          topStudent = s['nom_etudiant'] as String? ?? '-';
        }
        if (avg < minScore || evaluatedCount == 1) {
          minScore = avg;
        }
      }
    }

    final total = _students.length;
    final classAvg = evaluatedCount > 0 ? (sumAverages / evaluatedCount) : 0.0;
    final passRate = evaluatedCount > 0 ? ((passCount / evaluatedCount) * 100) : 0.0;

    return {
      'total': total,
      'evaluated': evaluatedCount,
      'average': classAvg,
      'passRate': passRate,
      'max': evaluatedCount > 0 ? maxScore : 0.0,
      'min': evaluatedCount > 0 ? minScore : 0.0,
      'topStudent': topStudent,
    };
  }

  Future<void> _saveDevoirs() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final List<Map<String, dynamic>> devoirsToSave = [];

      for (var s in _students) {
        final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
        final controllers = _devoirControllers[sId] ?? [];

        final List<double?> devoirsList = controllers.map((c) {
          final val = double.tryParse(c.text);
          return val;
        }).toList();

        final avg = _getLiveAverage(sId);

        devoirsToSave.add({
          'student_id': sId,
          'class_id': widget.classId,
          'subject_id': widget.subjectId,
          'session_id': _selectedSessionId!,
          'term': _selectedPeriodName,
          'devoirs': devoirsList,
          'moyenne_devoirs': avg,
        });
      }

      final res = await _repository.saveDevoirGrades(devoirsList: devoirsToSave);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Devoirs et bulletins synchronisés avec succès !'),
              backgroundColor: AppColors.success,
            ),
          );
          setState(() {
            _isLoading = true;
          });
          _fetchDevoirData(_schoolId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Erreur lors de la sauvegarde.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur critique: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ─── PDF Export & Print Functionality ─────────────────────────────────────
  Future<void> _exportPdfReport() async {
    setState(() {
      _isExportingPdf = true;
    });

    try {
      final stats = _calculateClassStats();
      final dateStr = DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now());

      final pdf = pw.Document();

      final tableData = _students.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final s = entry.value;
        final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
        final matricule = s['num_admission'] as String? ?? '-';
        final name = s['nom_etudiant'] as String? ?? 'Sans Nom';

        final controllers = _devoirControllers[sId];
        final d1 = controllers != null && controllers[0].text.isNotEmpty ? controllers[0].text : '-';
        final d2 = controllers != null && controllers[1].text.isNotEmpty ? controllers[1].text : '-';
        final d3 = controllers != null && controllers[2].text.isNotEmpty ? controllers[2].text : '-';
        final d4 = controllers != null && controllers[3].text.isNotEmpty ? controllers[3].text : '-';
        final d5 = controllers != null && controllers[4].text.isNotEmpty ? controllers[4].text : '-';

        final hasGrade = controllers?.any((c) => c.text.trim().isNotEmpty) ?? false;
        final avg = _getLiveAverage(sId);
        final avgStr = hasGrade ? avg.toStringAsFixed(2) : '-';
        final statut = !hasGrade ? 'En attente' : avg >= 10.0 ? 'Admis' : 'Faible';

        return [
          idx.toString(),
          matricule,
          name,
          d1,
          d2,
          d3,
          d4,
          d5,
          avgStr,
          statut,
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(height: 4, color: PdfColor.fromHex('#0F172A')),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'PROCÈS-VERBAL DES DEVOIRS SURVEILLÉS (DS)',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'RELEVÉ OFFICIEL DES ÉVALUATIONS CONTINUES • ${_selectedPeriodName.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                  ),
                ),
                pw.SizedBox(height: 10),

                // Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.RichText(
                            text: pw.TextSpan(
                              text: 'Classe : ',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              children: [
                                pw.TextSpan(text: widget.className, style: const pw.TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.RichText(
                            text: pw.TextSpan(
                              text: 'Matière : ',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              children: [
                                pw.TextSpan(text: widget.subjectName, style: const pw.TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.RichText(
                            text: pw.TextSpan(
                              text: 'Coefficient : ',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              children: [
                                pw.TextSpan(text: '$_coefficient', style: const pw.TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.RichText(
                            text: pw.TextSpan(
                              text: 'Période : ',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              children: [
                                pw.TextSpan(text: _selectedPeriodName, style: const pw.TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.RichText(
                            text: pw.TextSpan(
                              text: 'Date : ',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              children: [
                                pw.TextSpan(text: dateStr, style: const pw.TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.RichText(
                            text: pw.TextSpan(
                              text: 'Moyenne Classe : ',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              children: [
                                pw.TextSpan(
                                  text: '${(stats['average'] as double).toStringAsFixed(2)} / 20',
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#059669')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Stats Bar
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F1F5F9'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Effectif : ${stats['total']}  |  Évalués : ${stats['evaluated']}  |  Taux Réussite : ${(stats['passRate'] as double).toStringAsFixed(1)}%  |  Note Max : ${(stats['max'] as double).toStringAsFixed(2)} (${stats['topStudent']})  |  Note Min : ${(stats['min'] as double).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155')),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Matricule', 'Nom & Prénom', 'DS 1', 'DS 2', 'DS 3', 'DS 4', 'DS 5', 'Moy. DS', 'Statut'],
                data: tableData,
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellAlignment: pw.Alignment.center,
                cellAlignments: {
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(16),
                  1: const pw.FixedColumnWidth(48),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(24),
                  4: const pw.FixedColumnWidth(24),
                  5: const pw.FixedColumnWidth(24),
                  6: const pw.FixedColumnWidth(24),
                  7: const pw.FixedColumnWidth(24),
                  8: const pw.FixedColumnWidth(30),
                  9: const pw.FixedColumnWidth(34),
                },
              ),
              pw.SizedBox(height: 20),

              // Signature zone
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("L'Enseignant Titulaire :", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Date et Signature", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.SizedBox(height: 24),
                      pw.Container(width: 140, height: 0.5, color: PdfColors.grey600),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Visa de la Direction des Études :", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Cachet officiel et Approbation", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.SizedBox(height: 24),
                      pw.Container(width: 140, height: 0.5, color: PdfColors.grey600),
                    ],
                  ),
                ],
              ),
            ];
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Document officiel Edut Mobile • Page ${context.pageNumber} sur ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final cleanClass = widget.className.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final cleanSubject = widget.subjectName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'PV_Devoirs_${cleanClass}_$cleanSubject.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export PDF: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  void _showExtensionDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.assignment_late_outlined, color: AppColors.warning),
              SizedBox(width: 8),
              Text("Demande de dérogation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "La période est actuellement verrouillée. Vous pouvez transmettre une demande de réouverture à la direction.",
                style: AppTextStyles.caption.copyWith(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Motif / Raison (optionnel)",
                  hintText: "Ex: Retard d'évaluation pour raisons médicales...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (_selectedSessionId != null) {
                  final res = await _repository.requestPeriodExtension(
                    sessionId: _selectedSessionId!,
                    term: _selectedPeriodName,
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Demande transmise avec succès !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("Envoyer la demande"),
            ),
          ],
        );
      },
    );
  }

  void _showAiQuizGeneratorDialog() {
    final lessonController = TextEditingController(text: 'Évaluation formative');
    bool isGenerating = false;
    List<Map<String, dynamic>> generatedQuestions = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text("Générateur de Quiz IA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Matière : ${widget.subjectName} • Classe : ${widget.className}",
                        style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: lessonController,
                        decoration: const InputDecoration(
                          labelText: "Titre de la leçon / Thème",
                          hintText: "Ex: Les équations du second degré...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: isGenerating
                            ? null
                            : () async {
                                setDialogState(() {
                                  isGenerating = true;
                                  generatedQuestions = [];
                                });
                                final questions = await locator<AiRepository>().generateQuizQuestions(
                                  lessonTitle: lessonController.text.trim(),
                                  subjectName: widget.subjectName,
                                  className: widget.className,
                                  count: 3,
                                );
                                setDialogState(() {
                                  isGenerating = false;
                                  generatedQuestions = questions;
                                });
                              },
                        icon: isGenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isGenerating ? 'Génération en cours...' : 'Générer les questions ✨',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      if (generatedQuestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Questions générées :",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                        ),
                        const SizedBox(height: 8),
                        ...generatedQuestions.map((q) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF6366F1).withAlpha(40)),
                              ),
                              child: Text(
                                q['question']?.toString() ?? '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            )),
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Fermer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Sélectionner la période", style: AppTextStyles.heading3),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSessionId,
                      decoration: const InputDecoration(labelText: "Session Académique"),
                      items: _sessions.map((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(s['session_name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val == null) return;
                        final selected = _sessions.firstWhere((s) => s['id'] == val);
                        setModalState(() {
                          _selectedSessionId = val;
                          _selectedSessionName = selected['session_name'] as String;
                          _periods = [];
                        });
                        
                        final pList = await _repository.getPeriods(_schoolId, val, classId: widget.classId);
                        setModalState(() {
                          _periods = pList;
                          if (_periods.isNotEmpty) {
                            _selectedPeriodName = _periods.first['name'] as String;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_periods.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPeriodName,
                        decoration: const InputDecoration(labelText: "Trimestre / Semestre"),
                        items: _periods.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['name'] as String,
                            child: Text(p['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setModalState(() {
                            _selectedPeriodName = val;
                          });
                        },
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _fetchDevoirData(_schoolId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "Appliquer les filtres",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _calculateClassStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Devoirs (DS)'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isExportingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.success),
            onPressed: _isExportingPdf ? null : _exportPdfReport,
            tooltip: 'Exporter PDF (PV)',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
            onPressed: _showAiQuizGeneratorDialog,
            tooltip: 'Générateur de questions IA',
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            onPressed: _showPeriodSelector,
            tooltip: 'Période académique',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter details Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.slate100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.className} • ${widget.subjectName}",
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$_selectedSessionName • $_selectedPeriodName • Coeff : $_coefficient",
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Sync Directe",
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // ─── Live Analytics Bar ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatBadge(
                    label: "Moy. Classe",
                    value: "${(stats['average'] as double).toStringAsFixed(2)}/20",
                    icon: Icons.calculate_rounded,
                    color: (stats['average'] as double) >= 10 ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: "Évalués",
                    value: "${stats['evaluated']}/${stats['total']}",
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: "Réussite",
                    value: "${(stats['passRate'] as double).toStringAsFixed(1)}%",
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: "Note Max",
                    value: "${(stats['max'] as double).toStringAsFixed(2)}/20",
                    icon: Icons.emoji_events_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: "Note Min",
                    value: "${(stats['min'] as double).toStringAsFixed(2)}/20",
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ),

          // Lock Banner if Period is Locked or Read-Only
          if (!_isEditable || !_canManageAcademics)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade600),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lockReason ?? (!_canManageAcademics 
                          ? 'Mode lecture seule (Droits d\'édition désactivés).'
                          : 'Période verrouillée : Modification des devoirs fermée.'),
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showExtensionDialog,
                    child: const Text("Dérogation", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
            ),

          // Search Bar & Filter Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: "Rechercher élève ou matricule...",
                    prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: AppColors.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Tous (${_students.length})'),
                      const SizedBox(width: 6),
                      _buildFilterChip('evaluated', 'Évalués (${stats['evaluated']})'),
                      const SizedBox(width: 6),
                      _buildFilterChip('pending', 'En attente (${stats['total'] - stats['evaluated']})'),
                      const SizedBox(width: 6),
                      _buildFilterChip('danger', '< 10/20'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Devoir entry List
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                    ),
                  )
                : _filteredStudents.isEmpty
                    ? const Center(child: Text("Aucun élève trouvé"))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final sId = TypeConverters.safeInt(student['student_id'] ?? student['id']);
                          final matricule = student['num_admission'] as String? ?? '-';
                          final name = student['nom_etudiant'] as String? ?? 'Sans Nom';

                          final liveAvg = _getLiveAverage(sId);

                          return _buildDevoirCard(
                            studentId: sId,
                            matricule: matricule,
                            name: name,
                            average: liveAvg,
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed:
                _isSaving || !_canManageAcademics || !_isEditable ? null : _saveDevoirs,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "ENREGISTRER & SYNCHRONISER",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _activeFilterStatus == status;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : AppColors.slate700,
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.slate100,
      onSelected: (val) {
        setState(() {
          _activeFilterStatus = status;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildDevoirCard({
    required int studentId,
    required String matricule,
    required String name,
    required double average,
  }) {
    final hasGrade = _devoirControllers[studentId]?.any((c) => c.text.trim().isNotEmpty) ?? false;
    final isPass = average >= 10.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: !hasGrade
              ? AppColors.slate300
              : isPass
                  ? AppColors.success.withAlpha(60)
                  : AppColors.danger.withAlpha(60),
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.slate300),
                        ),
                        child: Text(
                          matricule,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate600),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasGrade ? "${average.toStringAsFixed(2)}/20" : "--",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: !hasGrade
                            ? AppColors.slate400
                            : isPass
                                ? AppColors.success
                                : AppColors.danger,
                      ),
                    ),
                    Text(
                      !hasGrade ? "En attente" : isPass ? "Moy. DS (Admis)" : "Moy. DS (Faible)",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: !hasGrade ? AppColors.slate400 : isPass ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Scrollable Devoir Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Notes des Devoirs (DS 1 à 5)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                if (_canManageAcademics && _isEditable)
                  InkWell(
                    onTap: () {
                      for (int i = 0; i < 5; i++) {
                        if (_devoirControllers[studentId]?[i].text.trim().isEmpty ?? true) {
                          _devoirControllers[studentId]?[i].text = "0";
                        }
                      }
                      setState(() {});
                    },
                    child: const Text(
                      "Vides = 0",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Container(
                    width: 58,
                    margin: const EdgeInsets.only(right: 6),
                    child: TextField(
                      controller: _devoirControllers[studentId]?[index],
                      enabled: _canManageAcademics && _isEditable,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "DS ${index + 1}",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        labelStyle: const TextStyle(fontSize: 9.5, color: AppColors.slate500, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        fillColor: AppColors.slate50,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: !_canManageAcademics
                          ? null
                          : (v) {
                        if (v.isNotEmpty && double.tryParse(v) != null) {
                          final numVal = double.parse(v);
                          if (numVal > 20) {
                            _devoirControllers[studentId]?[index].text = "20";
                          }
                        }
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
