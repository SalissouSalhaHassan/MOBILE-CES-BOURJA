import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/sync_engine.dart';
import '../data/academics_repository.dart';
import '../utils/calculations.dart';
import '../../ai/data/ai_repository.dart';
import 'voice_note_recorder_dialog.dart';
import '../../students/presentation/award_badge_dialog.dart';
import 'qcm_scanner_screen.dart';
import '../../../core/utils/type_converters.dart';

class SaisieNotesScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;

  const SaisieNotesScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SaisieNotesScreen> createState() => _SaisieNotesScreenState();
}

class _SaisieNotesScreenState extends State<SaisieNotesScreen> {
  final AcademicsRepository _repository = locator<AcademicsRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageAcademics = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _periods = [];
  List<Map<String, dynamic>> _gradingScale = [];

  int? _selectedSessionId;
  String _selectedSessionName = '';
  String _selectedPeriodName = '';
  bool _isHigherEd = false;
  bool _isEditable = true;
  String? _lockReason;
  double _coefficient = 1.0;
  int _schoolId = 1; // stored to reuse in period/session changes

  // Grade Approval Workflow state
  String _workflowStatus = 'BROUILLON';
  String? _workflowObservation;
  String _userRole = 'teacher';
  bool _isWorkflowActionLoading = false;

  final TextEditingController _searchController = TextEditingController();

  // Maps to store inputs in state
  final Map<int, TextEditingController> _classWorkControllers = {};
  final Map<int, TextEditingController> _examControllers = {};
  final Map<int, String> _observations = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _classWorkControllers.values) {
      controller.dispose();
    }
    for (var controller in _examControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final isOnline = locator<SyncEngine>().isOnlineNotifier.value;
    final profile = await locator<PermissionService>().getCurrentProfile(forceRefresh: isOnline);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canManageAcademics = profile.permissions.contains(AppPermissions.saisieNotesEdit);
    });

    try {
      final sessionManager = locator<SessionManager>();
      
      // Retrieve schoolId directly from SessionManager
      final schoolIdStr = await sessionManager.getSchoolId();
      int schoolId = int.tryParse(schoolIdStr ?? '') ?? 1;
      _schoolId = schoolId;
      debugPrint("✅ schoolId from session: $schoolId");

      // Fallback: If not found or defaults to 1, try querying database only if online
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
              schoolId = empInfo.first['school_id'] as int;
              _schoolId = schoolId; // store in state
              debugPrint("✅ schoolId from employee DB: $schoolId");
            }
          } catch (e) {
            debugPrint("⚠️ Failed to lookup schoolId in Supabase DB: $e");
          }
        }
      }

      // Fetch sessions and grading scales
      _sessions = await _repository.getSessions(schoolId);
      _gradingScale = await _repository.getGradingScale();
      
      debugPrint("📋 Sessions found: ${_sessions.length}");

      if (_sessions.isNotEmpty) {
        // Find active session or default to most recent (highest id)
        final activeSession = _sessions.firstWhere(
          (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
          orElse: () => _sessions.first,
        );
        _selectedSessionId = (activeSession['id'] as num?)?.toInt() ?? 1;
        _selectedSessionName = activeSession['session_name']?.toString() ?? '';
        debugPrint("✅ Active session: [$_selectedSessionId] $_selectedSessionName");

        // Fetch periods for this session
        _periods = await _repository.getPeriods(schoolId, _selectedSessionId!, classId: widget.classId);
        debugPrint("📋 Periods found: ${_periods.length}");
        
        if (_periods.isNotEmpty) {
          final activePeriod = _periods.firstWhere(
            (p) => p['is_active'] == true,
            orElse: () => _periods.first,
          );
          // Safe extraction of period name
          _selectedPeriodName = (activePeriod['name'] as String?)?.trim() ?? 
                                 activePeriod['period_type'] as String? ?? 
                                 '1er Trimestre';
          debugPrint("✅ Active period: $_selectedPeriodName");
        }
      }

      if (_selectedSessionId != null && _selectedPeriodName.isNotEmpty) {
        await _fetchGridData(schoolId);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Aucune session ou période académique trouvée. (sessions: ${_sessions.length})";
        });
      }
    } catch (e) {
      debugPrint("❌ _loadInitialData error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur d'initialisation: $e";
      });
    }
  }

  Future<void> _fetchGridData(int schoolId) async {
    if (_selectedSessionId == null || _selectedPeriodName.isEmpty) return;

    try {
      final result = await _repository.getGradingGrid(
        classId: widget.classId,
        subjectId: widget.subjectId,
        sessionId: _selectedSessionId!,
        term: _selectedPeriodName,
        schoolId: schoolId,
        className: widget.className,
      );

      if (result['success'] == true) {
        final List rawData = result['data'] is List ? (result['data'] as List) : [];
        _students = rawData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _filteredStudents = _students;
        // Fetch Grade Approval Workflow
        final wfResult = await _repository.getGradeWorkflowStatus(
          classId: widget.classId,
          subjectId: widget.subjectId,
          sessionId: _selectedSessionId!,
          period: _selectedPeriodName,
        );
        if (wfResult['success'] == true) {
          _workflowStatus = wfResult['workflowStatus'] as String? ?? 'BROUILLON';
          _workflowObservation = wfResult['observation'] as String?;
          _userRole = wfResult['role'] as String? ?? 'teacher';
        }

        final isSuperOrAdmin = _userRole.toLowerCase().contains('admin') ||
            _userRole.toLowerCase().contains('direct') ||
            _userRole.toLowerCase().contains('owner');

        final periodEditable = result['is_editable'] as bool? ?? true;
        _isEditable = periodEditable &&
            (isSuperOrAdmin ||
                _workflowStatus == 'BROUILLON' ||
                _workflowStatus == 'CORRECTION_DEMANDEE');
        _lockReason = result['lock_reason'] as String?;
        _isHigherEd = ["Licence", "Master", "Doctorat", "Supérieur", "Université"]
            .contains(result['level']);
        _coefficient = TypeConverters.safeDouble(result['coefficient'], 1.0);

        // Initialize controllers
        _classWorkControllers.clear();
        _examControllers.clear();
        _observations.clear();

        for (var student in _students) {
          final sId = TypeConverters.safeInt(student['student_id'] ?? student['id']);
          
          final classWorkVal = student['class_work_score'] != null
              ? (num.tryParse(student['class_work_score'].toString())?.toStringAsFixed(2).replaceAll('.00', '') ?? student['class_work_score'].toString())
              : '';
          final examVal = student['exam_score'] != null
              ? (num.tryParse(student['exam_score'].toString())?.toStringAsFixed(2).replaceAll('.00', '') ?? student['exam_score'].toString())
              : '';

          _classWorkControllers[sId] = TextEditingController(text: classWorkVal);
          _examControllers[sId] = TextEditingController(text: examVal);
          _observations[sId] = student['observation'] as String? ?? '';
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = _formatFriendlyError(result['error'] ?? "Une erreur est survenue.");
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _formatFriendlyError("Erreur lors du chargement de la grille: $e");
      });
    }
  }

  String _formatFriendlyError(dynamic error) {
    if (error == null) return "Une erreur est survenue.";
    final str = error.toString();
    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('DioException') ||
        str.contains('connection error') ||
        str.contains('errno = 7')) {
      return "Mode Hors-ligne : Connexion réseau indisponible. Les données locales sont conservées en sécurité.";
    }
    return str;
  }

  void _filterStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _students;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = (s['nom_etudiant'] as String? ?? '').toLowerCase();
        final code = (s['num_admission'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || code.contains(lowerQuery);
      }).toList();
    });
  }

  // Get live stats
  Map<String, dynamic> _getCalculatedStats() {
    if (_students.isEmpty) return {'avg': 0.0, 'passed': 0, 'failed': 0};

    double totalSum = 0.0;
    int count = 0;
    int passed = 0;

    for (var s in _students) {
      final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
      final cw = double.tryParse(_classWorkControllers[sId]?.text ?? '') ?? 0.0;
      final ex = double.tryParse(_examControllers[sId]?.text ?? '') ?? 0.0;

      final metrics = StudentMetrics.calculate(
        classWork: cw,
        examNote: ex,
        coefficient: _coefficient,
        isHigherEd: _isHigherEd,
      );

      totalSum += metrics.average;
      count++;
      if (metrics.average >= 10) {
        passed++;
      }
    }

    final avg = count > 0 ? totalSum / count : 0.0;
    final failed = count - passed;

    return {
      'avg': avg,
      'passed': passed,
      'failed': failed,
    };
  }

  // Live calculation for a single student row
  Map<String, dynamic> _getRowMetrics(int studentId) {
    final cw = double.tryParse(_classWorkControllers[studentId]?.text ?? '') ?? 0.0;
    final ex = double.tryParse(_examControllers[studentId]?.text ?? '') ?? 0.0;

    final metrics = StudentMetrics.calculate(
      classWork: cw,
      examNote: ex,
      coefficient: _coefficient,
      isHigherEd: _isHigherEd,
    );

    final appreciation = getAppreciation(metrics.average, _gradingScale);

    return {
      'total': metrics.total,
      'average': metrics.average,
      'weighted': metrics.weighted,
      'appreciation': appreciation,
    };
  }

  // Calculate live ranks
  Map<int, int> _getLiveRanks() {
    final List<Map<String, dynamic>> list = [];
    for (var s in _students) {
      final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
      final cw = double.tryParse(_classWorkControllers[sId]?.text ?? '') ?? 0.0;
      final ex = double.tryParse(_examControllers[sId]?.text ?? '') ?? 0.0;

      final metrics = StudentMetrics.calculate(
        classWork: cw,
        examNote: ex,
        coefficient: _coefficient,
        isHigherEd: _isHigherEd,
      );

      list.add({
        'student_id': sId,
        'weighted_score': metrics.weighted,
      });
    }

    return calculateRanks(list);
  }

  Future<void> _saveGrades() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final ranksMap = _getLiveRanks();
      if (_students.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun élève à enregistrer dans cette classe.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        return;
      }

      final sessionId = _selectedSessionId ?? 1;
      final periodName = _selectedPeriodName.isNotEmpty ? _selectedPeriodName : '1er Trimestre';
      final List<Map<String, dynamic>> gradesToSave = [];

      for (var s in _students) {
        final sId = TypeConverters.safeInt(s['student_id'] ?? s['id']);
        final classWorkStr = _classWorkControllers[sId]?.text ?? '';
        final examStr = _examControllers[sId]?.text ?? '';

        final cw = double.tryParse(classWorkStr);
        final ex = double.tryParse(examStr);

        // Calculate metrics
        final metrics = StudentMetrics.calculate(
          classWork: cw ?? 0.0,
          examNote: ex ?? 0.0,
          coefficient: _coefficient,
          isHigherEd: _isHigherEd,
        );

        final app = getAppreciation(metrics.average, _gradingScale);
        final rk = formatRank(ranksMap[sId] ?? 0);

        gradesToSave.add({
          'student_id': sId,
          'class_id': widget.classId,
          'subject_id': widget.subjectId,
          'session_id': sessionId,
          'term': periodName,
          'class_work_score': cw,
          'exam_score': ex,
          'total_score': metrics.total,
          'coefficient': _coefficient.round(),
          'weighted_score': metrics.weighted,
          'absences': s['absences'] ?? 0,
          'observation': _observations[sId] ?? '',
          'appreciation': app,
          'rank': rk,
        });
      }

      final res = await _repository.saveStudentGrades(grades: gradesToSave);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (res['success'] == true) {
          final isOnline = locator<SyncEngine>().isOnlineNotifier.value;
          final isActuallySavedOnline = isOnline && res['isOffline'] != true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isActuallySavedOnline
                    ? 'Notes enregistrées avec succès !'
                    : '💾 Notes enregistrées localement (Mode Hors-ligne). Synchronisation automatique dès le retour du réseau 📶',
              ),
              backgroundColor: isActuallySavedOnline ? AppColors.success : const Color(0xFFD97706),
            ),
          );
          // Reload data to ensure sync under current selected session & period
          setState(() {
            _isLoading = true;
          });
          _fetchGridData(_schoolId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_formatFriendlyError(res['error'] ?? 'Erreur lors de la sauvegarde.')),
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
            content: Text(_formatFriendlyError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleWorkflowAction(String targetAction, {String? observation}) async {
    setState(() => _isWorkflowActionLoading = true);
    try {
      final res = await _repository.updateGradeWorkflowStatus(
        classId: widget.classId,
        subjectId: widget.subjectId,
        sessionId: _selectedSessionId!,
        period: _selectedPeriodName,
        targetAction: targetAction,
        schoolId: _schoolId,
        observation: observation,
      );

      if (res['success'] == true) {
        if (mounted) {
          final isOffline = res['isOffline'] == true || !locator<SyncEngine>().isOnlineNotifier.value;
          final msg = isOffline
              ? (res['message'] ?? '📋 Action enregistrée localement (Mode Hors-ligne). Synchronisation automatique dès la reconnexion.')
              : (res['message'] ?? 'Statut du circuit d\'approbation mis à jour avec succès.');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: isOffline ? const Color(0xFFD97706) : AppColors.success,
            ),
          );

          if (res['workflowStatus'] != null) {
            setState(() {
              _workflowStatus = res['workflowStatus'] as String;
              if (observation != null) _workflowObservation = observation;
              _isEditable = _workflowStatus == 'BROUILLON' || _workflowStatus == 'CORRECTION_DEMANDEE';
            });
          }

          _fetchGridData(_schoolId);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_formatFriendlyError(res['error'] ?? 'Erreur lors de la mise à jour.')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatFriendlyError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorkflowActionLoading = false);
    }
  }

  void _showRequestCorrectionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.assignment_return_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text("Demander une correction", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Indiquez la raison pour laquelle le professeur doit corriger les notes :",
              style: TextStyle(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Ex: Notes manquantes, moyenne anormale...",
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              _handleWorkflowAction('request_correction', observation: controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text("Envoyer la demande", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard() {
    Color statusColor = AppColors.slate600;
    String statusTitle = "Saisie Libre (Brouillon)";
    IconData statusIcon = Icons.edit_note_rounded;

    if (_workflowStatus == 'CORRECTION_DEMANDEE') {
      statusColor = AppColors.danger;
      statusTitle = "Correction Demandée par la Direction";
      statusIcon = Icons.error_outline_rounded;
    } else if (_workflowStatus == 'SAISIE_TERMINEE') {
      statusColor = const Color(0xFF2563EB); // Blue
      statusTitle = "Soumis (En attente contrôle Censeur)";
      statusIcon = Icons.schedule_rounded;
    } else if (_workflowStatus == 'CONTROLE_PEDAGOGIQUE' || _workflowStatus == 'VALIDATION_CONSEIL') {
      statusColor = const Color(0xFFD97706); // Amber
      statusTitle = "Validé Pédagogique (Prêt pour Conseil)";
      statusIcon = Icons.verified_user_rounded;
    } else if (_workflowStatus == 'VERROUILLE') {
      statusColor = const Color(0xFFDC2626); // Red
      statusTitle = "Verrouillé & Scellé (Conseil)";
      statusIcon = Icons.lock_rounded;
    } else if (_workflowStatus == 'PUBLIE' || _workflowStatus == 'ARCHIVE') {
      statusColor = AppColors.success;
      statusTitle = "Publié aux Familles";
      statusIcon = Icons.public_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CIRCUIT D'APPROBATION",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_workflowObservation != null && _workflowObservation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Motif : $_workflowObservation",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showExtensionDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
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
                        
                        // Load new periods using the correct schoolId
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
                        _fetchGridData(_schoolId);
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

  void _showObservationDialog(int studentId, String studentName) {
    final controller = TextEditingController(text: _observations[studentId] ?? '');
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Observation : $studentName", style: AppTextStyles.heading3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    enabled: _canManageAcademics && !isGenerating,
                    decoration: const InputDecoration(
                      hintText: "Saisir une remarque...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  if (_canManageAcademics)
                    InkWell(
                      onTap: isGenerating
                          ? null
                          : () async {
                              setDialogState(() => isGenerating = true);
                              final cw = double.tryParse(_classWorkControllers[studentId]?.text ?? '') ?? 12.0;
                              final ex = double.tryParse(_examControllers[studentId]?.text ?? '') ?? cw;
                              final score = ((cw + ex) / 2.0).clamp(0.0, 20.0);
                              final app = await locator<AiRepository>().generateGradeAppreciation(
                                studentName: studentName,
                                subjectName: widget.subjectName,
                                score: score,
                                className: widget.className,
                              );
                              setDialogState(() {
                                isGenerating = false;
                                controller.text = app;
                              });
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isGenerating)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                              )
                            else
                              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isGenerating ? 'Génération IA...' : 'Suggérer une appréciation IA ✨',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler", style: TextStyle(color: AppColors.slate500)),
                ),
                ElevatedButton(
                  onPressed: !_canManageAcademics || isGenerating
                      ? null
                      : () {
                          setState(() {
                            _observations[studentId] = controller.text.trim();
                          });
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
                ),
              ],
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

    final stats = _getCalculatedStats();
    final liveRanks = _getLiveRanks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie des Notes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            onPressed: _showPeriodSelector,
            tooltip: 'Période académique',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header / Filter Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        "$_selectedSessionName • $_selectedPeriodName",
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: locator<SyncEngine>().isOnlineNotifier,
                      builder: (context, isOnline, _) {
                        if (isOnline) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 12, color: Color(0xFFB45309)),
                              SizedBox(width: 4),
                              Text(
                                "Hors-Ligne",
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Coef: ${_coefficient.toStringAsFixed(0)}",
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overview Stats Panel
          _buildStatsPanel(stats),

          // World-Class Grade Approval Workflow Card
          _buildWorkflowCard(),

          // Lock Banner if Period is Locked or Read-Only
          if (!_isEditable || !_canManageAcademics)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade600),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lockReason ?? (!_canManageAcademics 
                          ? 'Mode lecture seule (Droits d\'édition désactivés).'
                          : (_workflowStatus == 'SAISIE_TERMINEE'
                              ? 'Notes soumises au Censeur pour contrôle pédagogique (Saisie verrouillée).'
                              : (_workflowStatus == 'CONTROLE_PEDAGOGIQUE' || _workflowStatus == 'VALIDATION_CONSEIL' || _workflowStatus == 'VERROUILLE' || _workflowStatus == 'PUBLIE'
                                  ? 'Grille scellée et validée par l\'administration.'
                                  : 'Période verrouillée : La date limite de saisie des notes est dépassée.'))),
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_lockReason != null || (_workflowStatus == 'BROUILLON' || _workflowStatus == 'CORRECTION_DEMANDEE'))
                    TextButton.icon(
                      onPressed: _showExtensionDialog,
                      icon: const Icon(Icons.send_rounded, size: 14, color: AppColors.primary),
                      label: const Text(
                        "Dérogation",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStudents,
              decoration: InputDecoration(
                hintText: "Rechercher un élève...",
                prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: AppColors.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Main Student List
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final sId = TypeConverters.safeInt(student['student_id'] ?? student['id']);
                          final matricule = student['num_admission']?.toString() ?? '-';
                          final name = student['nom_etudiant']?.toString() ?? 'Élève';
                          final rank = liveRanks[sId] ?? 0;

                          final rowMetrics = _getRowMetrics(sId);

                          return _buildStudentCard(
                            studentId: sId,
                            matricule: matricule,
                            name: name,
                            rank: rank,
                            metrics: rowMetrics,
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // When in BROUILLON or CORRECTION_DEMANDEE: Save + Submit
              if (_workflowStatus == 'BROUILLON' || _workflowStatus == 'CORRECTION_DEMANDEE') ...[
                Row(
                  children: [
                    // Save Button
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving || !_canManageAcademics || !_isEditable ? null : _saveGrades,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text("Enregistrer"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Submit for Review Button
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _isWorkflowActionLoading
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Soumettre les notes ?"),
                                    content: const Text(
                                      "Les notes seront transmises au Censeur pour vérification pédagogique. La saisie sera verrouillée temporairement.",
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                        child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _handleWorkflowAction('submit');
                                }
                              },
                        icon: _isWorkflowActionLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          "Soumettre",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_workflowStatus == 'SAISIE_TERMINEE') ...[
                // Censeur Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isWorkflowActionLoading ? null : _showRequestCorrectionDialog,
                        icon: const Icon(Icons.rotate_left, color: AppColors.danger, size: 18),
                        label: const Text("Demander Correction", style: TextStyle(color: AppColors.danger)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isWorkflowActionLoading
                            ? null
                            : () => _handleWorkflowAction('validate_control'),
                        icon: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                        label: const Text("Valider Contrôle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_workflowStatus == 'CONTROLE_PEDAGOGIQUE' || _workflowStatus == 'VALIDATION_CONSEIL') ...[
                // Director Action: Lock
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isWorkflowActionLoading
                        ? null
                        : () => _handleWorkflowAction('lock'),
                    icon: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                    label: const Text("Verrouiller Définitivement (Conseil)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                  ),
                ),
              ] else ...[
                // Locked / Published banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 18, color: AppColors.slate600),
                      SizedBox(width: 8),
                      Text(
                        "Grille scellée et validée",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel(Map<String, dynamic> stats) {
    final double avg = stats['avg'] as double;
    final int passed = stats['passed'] as int;
    final int failed = stats['failed'] as int;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            title: "Moyenne Classe",
            value: "${avg.toStringAsFixed(2)}/20",
            icon: Icons.analytics,
            color: AppColors.primary,
          ),
          Container(width: 1, height: 40, color: AppColors.slate100),
          _buildStatItem(
            title: "Admis",
            value: "$passed",
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          Container(width: 1, height: 40, color: AppColors.slate100),
          _buildStatItem(
            title: "Non Admis",
            value: "$failed",
            icon: Icons.cancel_outlined,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
      ],
    );
  }

  Widget _buildStudentCard({
    required int studentId,
    required String matricule,
    required String name,
    required int rank,
    required Map<String, dynamic> metrics,
  }) {
    final double avg = metrics['average'] as double;
    final String appreciation = metrics['appreciation'] as String;

    Color appreciationColor = AppColors.slate500;
    if (appreciation.contains("Excellent") || appreciation.contains("Bien")) {
      appreciationColor = AppColors.success;
    } else if (appreciation.contains("Passable")) {
      appreciationColor = AppColors.warning;
    } else if (appreciation.contains("Insuffisant") || appreciation.contains("Médiocre")) {
      appreciationColor = AppColors.danger;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.slate100),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student details row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.slate300),
                        ),
                        child: Text(
                          matricule,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate500),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 22),
                      onPressed: () => AwardBadgeDialog.show(context, studentId: studentId, studentName: name),
                      tooltip: "Décerner un écusson d'honneur",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatRank(rank),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.warning),
                        ),
                        const Text("Rang", style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Score Entry Row
            Row(
              children: [
                if (!_isHigherEd) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Moy. Classe", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _classWorkControllers[studentId],
                          enabled: _canManageAcademics && _isEditable,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: "--",
                            fillColor: AppColors.slate50,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: !_canManageAcademics
                              ? null
                              : (v) {
                            if (v.isNotEmpty && double.tryParse(v) != null) {
                              final numVal = double.parse(v);
                              if (numVal > 20) {
                                _classWorkControllers[studentId]?.text = "20";
                              }
                            }
                            setState(() {}); // Recalculate stats
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isHigherEd ? "Note" : "Note Compo", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _examControllers[studentId],
                        enabled: _canManageAcademics && _isEditable,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "--",
                          fillColor: AppColors.slate50,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.document_scanner_rounded, size: 18, color: Color(0xFF10B981)),
                            tooltip: "Scanner QCM IA",
                            onPressed: !_canManageAcademics || !_isEditable
                                ? null
                                : () async {
                                    final scannedScore = await Navigator.push<double>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => QcmScannerScreen(
                                          subjectName: widget.subjectName,
                                          className: widget.className,
                                          studentName: name,
                                        ),
                                      ),
                                    );
                                    if (scannedScore != null) {
                                      _examControllers[studentId]?.text = scannedScore.toStringAsFixed(2);
                                      setState(() {});
                                    }
                                  },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: !_canManageAcademics
                            ? null
                            : (v) {
                          if (v.isNotEmpty && double.tryParse(v) != null) {
                            final numVal = double.parse(v);
                            if (numVal > 20) {
                              _examControllers[studentId]?.text = "20";
                            }
                          }
                          setState(() {}); // Recalculate stats
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${avg.toStringAsFixed(2)}/20",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: avg >= 10 ? AppColors.success : AppColors.danger),
                    ),
                    const Text("Moyenne", style: TextStyle(fontSize: 10, color: AppColors.slate400)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Observation & Appreciation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_outline, size: 14, color: AppColors.slate400),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: appreciationColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appreciation,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: appreciationColor),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: "Note vocale multilingue",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: !_canManageAcademics || !_isEditable
                          ? null
                          : () => VoiceNoteRecorderDialog.show(
                                context,
                                studentId: studentId,
                                studentName: name,
                                subjectName: widget.subjectName,
                                className: widget.className,
                              ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: _canManageAcademics && _isEditable
                          ? () => _showObservationDialog(studentId, name)
                          : null,
                      icon: Icon(
                        _observations[studentId]?.isNotEmpty == true ? Icons.comment : Icons.comment_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        _observations[studentId]?.isNotEmpty == true ? "Obs: ${_observations[studentId]}" : "Ajouter Obs.",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
