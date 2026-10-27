import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/utils/type_converters.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/attendance_repository.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectName;
  final String? initialDateStr;

  const StudentAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectName,
    this.initialDateStr,
  });

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final AttendanceRepository _repository = locator<AttendanceRepository>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageAttendance = false;
  String? _errorMessage;
  
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  
  // Maps to track current UI changes before saving
  final Map<int, String> _statuses = {}; // studentId -> status ('Présent', 'Absent', 'En Retard', 'Excusé')
  final Map<int, String> _remarks = {};  // studentId -> remark string
  
  late DateTime _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  // Notification switches
  bool _sendSMS = false;
  bool _sendWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDateStr != null
        ? DateTime.tryParse(widget.initialDateStr!) ?? DateTime.now()
        : DateTime.now();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employeeIdStr = await locator<SessionManager>().getEmployeeId();
      final employeeId = int.tryParse(employeeIdStr ?? '');

      // 1. Fetch active students in class (filtered by schoolId via repository)
      final studentsList = await _repository.getStudentsByClass(widget.className, employeeId);
      
      // 2. Fetch existing records for this date and subject
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final recordsList = await _repository.getStudentAttendanceRecords(
        classId: widget.classId,
        dateStr: dateStr,
        subjectId: widget.subjectId,
      );

      final Map<int, String> existingStatuses = {};
      final Map<int, String> existingRemarks = {};

      for (var record in recordsList) {
        final sId = TypeConverters.safeInt(record['student_id']);
        if (sId != 0) {
          existingStatuses[sId] = record['status']?.toString() ?? 'Présent';
          if (record['remark'] != null && record['remark'].toString().trim().isNotEmpty) {
            existingRemarks[sId] = record['remark'].toString().trim();
          }
        }
      }

      if (mounted) {
        setState(() {
          _canManageAttendance =
              profile.permissions.contains(AppPermissions.attendanceManage);
          _students = studentsList;
          _filteredStudents = studentsList;
          
          // Populate status map: default to 'Présent' if no existing status
          _statuses.clear();
          _remarks.clear();
          for (var s in _students) {
            final sId = TypeConverters.safeInt(s['id'] ?? s['student_id']);
            if (sId != 0) {
              _statuses[sId] = existingStatuses[sId] ?? 'Présent';
              if (existingRemarks.containsKey(sId)) {
                _remarks[sId] = existingRemarks[sId]!;
              }
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur de chargement: $e";
        });
      }
    }
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
        final name = (s['nom_etudiant'] ?? s['nomEtudiant'] ?? '').toString().toLowerCase();
        final code = (s['num_admission'] ?? s['numAdmission'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery) || code.contains(lowerQuery);
      }).toList();
    });
  }

  // Bulk actions
  void _setAllStatus(String status) {
    setState(() {
      for (var s in _students) {
        final sId = TypeConverters.safeInt(s['id'] ?? s['student_id']);
        if (sId != 0) {
          _statuses[sId] = status;
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Tous les élèves ont été marqués: $status"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Edit single student remark in dialog
  void _showRemarkDialog(int studentId, String studentName) {
    final controller = TextEditingController(text: _remarks[studentId] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Remarque : $studentName", style: AppTextStyles.heading3),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Saisir une remarque...",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler", style: TextStyle(color: AppColors.slate500)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (controller.text.trim().isEmpty) {
                    _remarks.remove(studentId);
                  } else {
                    _remarks[studentId] = controller.text.trim();
                  }
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Valider", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Save student attendance records
  Future<void> _saveAttendance() async {
    setState(() {
      _isSaving = true;
    });

    final employeeIdStr = await locator<SessionManager>().getEmployeeId();
    final employeeId = int.tryParse(employeeIdStr ?? '');
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Format records for repository API
    final List<Map<String, dynamic>> recordsToSave = [];
    for (var s in _students) {
      final sId = TypeConverters.safeInt(s['id'] ?? s['student_id']);
      if (sId != 0) {
        recordsToSave.add({
          'student_id': sId,
          'status': _statuses[sId] ?? 'Présent',
          'remark': _remarks[sId],
        });
      }
    }

    final result = await _repository.saveStudentBatchAttendance(
      classId: widget.classId,
      dateStr: dateStr,
      subjectId: widget.subjectId,
      employeeId: employeeId,
      records: recordsToSave,
      sendSMS: _sendSMS,
      sendWhatsApp: _sendWhatsApp,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (result['success'] == true) {
        final isOnline = locator<SyncEngine>().isOnlineNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? "Appel enregistré avec succès !"
                  : "💾 Appel enregistré localement (Mode Hors-ligne). Synchronisation automatique dès le retour du réseau 📶",
            ),
            backgroundColor: isOnline ? AppColors.success : const Color(0xFFD97706),
          ),
        );
        Navigator.pop(context);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Erreur"),
            content: Text(result['error'] ?? "Une erreur est survenue lors de l'enregistrement."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  // Change date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.slate800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchData();
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF0D9488), // Teal
      const Color(0xFF7C3AED), // Purple
      const Color(0xFF2563EB), // Blue
      const Color(0xFFEA580C), // Orange
      const Color(0xFFDB2777), // Pink
      const Color(0xFF0284C7), // Sky
    ];
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final total = _students.length;
    final presentCount = _statuses.values.where((v) => v == 'Présent').length;
    final absentCount = _statuses.values.where((v) => v == 'Absent').length;
    final lateCount = _statuses.values.where((v) => v == 'En Retard').length;
    final excusedCount = _statuses.values.where((v) => v == 'Excusé').length;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text("Appel : ${widget.className}", style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint, size: 22, color: Color(0xFF4F46E5)),
            onPressed: _showBiometricDialog,
            tooltip: 'Pointage Biométrique par Empreinte',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: _selectDate,
            tooltip: 'Changer la date',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
               ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Class & Date Header Info Card
                    _buildHeaderCard(dateStr: _formatDateFrench(_selectedDate)),

                    // Stats Dashboard Grid
                    _buildStatsRow(
                      total: total,
                      presents: presentCount,
                      absents: absentCount,
                      lates: lateCount,
                      excused: excusedCount,
                    ),

                    // Quick Bulk Actions Bar
                    _buildBulkActionsBar(),

                    // Search field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterStudents,
                        decoration: InputDecoration(
                          hintText: "Rechercher un élève...",
                          hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterStudents('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // Student List
                    Expanded(
                      child: _filteredStudents.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isNotEmpty
                                    ? "Aucun résultat trouvé pour votre recherche."
                                    : "Aucun élève actif trouvé dans cette classe.",
                                style: AppTextStyles.caption,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                final studentId = TypeConverters.safeInt(student['id'] ?? student['student_id']);
                                final studentName = student['nom_etudiant']?.toString() ?? '';
                                final admissionNo = student['num_admission']?.toString() ?? '';
                                final currentStatus = _statuses[studentId] ?? 'Présent';
                                final hasRemark = _remarks.containsKey(studentId) && (_remarks[studentId]?.toString().trim().isNotEmpty ?? false);

                                return _buildStudentCard(
                                  studentId: studentId,
                                  studentName: studentName,
                                  admissionNo: admissionNo,
                                  currentStatus: currentStatus,
                                  hasRemark: hasRemark,
                                );
                              },
                            ),
                    ),

                    // Floating Bottom Saving Container
                    _buildSaveButtonContainer(),
                  ],
                ),
    );
  }

  Widget _buildHeaderCard({required String dateStr}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary.withAlpha(220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                "Classe : ${widget.className}",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (widget.subjectName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 16),
                const SizedBox(width: 10),
                Text(
                  "Matière : ${widget.subjectName}",
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: locator<SyncEngine>().isOnlineNotifier,
                builder: (context, isOnline, _) {
                  if (isOnline) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 13, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text(
                          "Mode Hors-Ligne",
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int presents,
    required int absents,
    required int lates,
    required int excused,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildStatBox(title: "Élèves", value: "$total", color: AppColors.slate700),
          const SizedBox(width: 6),
          _buildStatBox(title: "Présents", value: "$presents", color: AppColors.success),
          const SizedBox(width: 6),
          _buildStatBox(title: "Absents", value: "$absents", color: AppColors.danger),
          const SizedBox(width: 6),
          _buildStatBox(title: "Retards", value: "$lates", color: AppColors.warning),
          const SizedBox(width: 6),
          _buildStatBox(title: "Excusés", value: "$excused", color: AppColors.info),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(45), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _notifyAbsentParentsViaWhatsApp() async {
    final absentStudents = _students.where((s) {
      final sId = TypeConverters.safeInt(s['id'] ?? s['student_id']);
      return _statuses[sId] == 'Absent';
    }).toList();
    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élève marqué absent.')),
      );
      return;
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final subject = widget.subjectName ?? 'la séance';
    final className = widget.className;

    int preparedCount = 0;
    for (final s in absentStudents) {
      final phone = s['mobile'] ?? s['whatsapp'] ?? s['parent_phone'] ?? s['nom_pere'];
      if (phone != null && phone.toString().trim().isNotEmpty) {
        final text = "*ÉTABLISSEMENT SCOLAIRE EDUT* 🏫\n\nCher parent,\nNous vous informons que votre enfant *${s['nom_etudiant']}* (Classe: $className) a été noté(e) *ABSENT(E)* le *$dateStr* lors du cours de *$subject*.\n\n_Veuillez justifier cette absence sur l'application Edut ou auprès de la vie scolaire._";
        final cleanPhone = phone.toString().replaceAll(RegExp(r'\D'), '');
        final waUrl = Uri.parse("https://api.whatsapp.com/send?phone=${cleanPhone.length == 8 ? '227$cleanPhone' : cleanPhone}&text=${Uri.encodeComponent(text)}");
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
          preparedCount++;
          break; // Open WhatsApp for parent
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$preparedCount alerte(s) WhatsApp préparée(s) pour les parents.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _buildBulkActionsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: _canManageAttendance
                  ? () => _setAllStatus('Présent')
                  : null,
              icon: const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              label: const Text("Tous Présents", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.success)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.success, width: 1.5),
                backgroundColor: AppColors.success.withAlpha(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed:
                  _canManageAttendance ? () => _setAllStatus('Absent') : null,
              icon: const Icon(Icons.cancel, size: 16, color: AppColors.danger),
              label: const Text("Tous Absents", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                backgroundColor: AppColors.danger.withAlpha(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _notifyAbsentParentsViaWhatsApp,
            icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF10B981), size: 20),
            tooltip: 'Notifier les absents sur WhatsApp',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard({
    required int studentId,
    required String studentName,
    required String admissionNo,
    required String currentStatus,
    required bool hasRemark,
  }) {
    String initials = '?';
    final nameTrimmed = studentName.trim();
    if (nameTrimmed.isNotEmpty) {
      final parts = nameTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final avatarColor = _getAvatarColor(studentName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor.withAlpha(30),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: avatarColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(color: AppColors.slate900, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "N° Adm: $admissionNo",
                        style: const TextStyle(color: AppColors.slate500, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    hasRemark ? Icons.comment : Icons.comment_outlined,
                    color: hasRemark ? AppColors.primary : AppColors.slate400,
                    size: 20,
                  ),
                  onPressed: _canManageAttendance
                      ? () => _showRemarkDialog(studentId, studentName)
                      : null,
                  tooltip: 'Ajouter une remarque',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  SizedBox(width: 70, child: _buildStatusChip(studentId, 'Présent', AppColors.success)),
                  const SizedBox(width: 4),
                  SizedBox(width: 70, child: _buildStatusChip(studentId, 'Absent', AppColors.danger)),
                  const SizedBox(width: 4),
                  SizedBox(width: 70, child: _buildStatusChip(studentId, 'En Retard', AppColors.warning)),
                  const SizedBox(width: 4),
                  SizedBox(width: 70, child: _buildStatusChip(studentId, 'Excusé', AppColors.info)),
                  const SizedBox(width: 4),
                  _buildBiometricChip(studentId, studentName),
                ],
              ),
            ),
            if (hasRemark) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _remarks[studentId] ?? '',
                        style: const TextStyle(color: AppColors.slate700, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int studentId, String statusLabel, Color activeColor) {
    final isSelected = _statuses[studentId] == statusLabel;

    return GestureDetector(
      onTap: !_canManageAttendance
          ? null
          : () {
              setState(() {
                _statuses[studentId] = statusLabel;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            statusLabel == 'En Retard' ? 'Retard' : (statusLabel == 'Excusé' ? 'Excusé' : statusLabel),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppColors.slate700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricChip(int studentId, String studentName) {
    final isBiometric = _remarks[studentId]?.contains("Empreinte") == true ||
        (_statuses[studentId] == 'Présent' && _remarks[studentId] == 'Vérifié par empreinte digitale');

    return GestureDetector(
      onTap: !_canManageAttendance
          ? null
          : () {
              setState(() {
                _statuses[studentId] = 'Présent';
                _remarks[studentId] = 'Vérifié par empreinte digitale';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Empreinte validée : $studentName")),
                    ],
                  ),
                  backgroundColor: const Color(0xFF4F46E5),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isBiometric ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isBiometric ? const Color(0xFF4F46E5) : const Color(0xFFC7D2FE),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              size: 14,
              color: isBiometric ? Colors.white : const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 4),
            Text(
              "Empreinte",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isBiometric ? Colors.white : const Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateFrench(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showBiometricDialog() {
    String modalSearchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _students.where((s) {
              if (modalSearchQuery.trim().isEmpty) return true;
              final q = modalSearchQuery.trim().toLowerCase();
              final name = (s['nom_etudiant'] ?? s['nomEtudiant'] ?? '').toString().toLowerCase();
              final numAdm = (s['num_admission'] ?? s['numAdmission'] ?? '').toString().toLowerCase();
              return name.contains(q) || numAdm.contains(q);
            }).toList();

            return Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFC7D2FE), width: 2),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 40,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Scanner d'Empreinte Digitale",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Poser le doigt de l'élève sur le capteur biométrique ou valider directement la présence ci-dessous",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        modalSearchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Rechercher un élève par nom ou matricule...",
                      hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                "Aucun élève trouvé",
                                style: TextStyle(color: AppColors.slate500, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final s = filtered[index];
                              final sId = TypeConverters.safeInt(s['id'] ?? s['student_id']);
                              final sName = s['nom_etudiant'] ?? s['nomEtudiant'] ?? 'Élève';
                              final numAdm = s['num_admission'] ?? s['numAdmission'] ?? '';
                              final isPresent = _statuses[sId] == 'Présent';

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPresent ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isPresent ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPresent ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                                        color: isPresent ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            numAdm.isNotEmpty ? "Matricule : $numAdm" : "ID #$sId",
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isPresent ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        isPresent ? Icons.done_all_rounded : Icons.check_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        isPresent ? "Validé" : "Valider",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _statuses[sId] = 'Présent';
                                          _remarks[sId] = 'Vérifié par empreinte digitale';
                                        });
                                        setModalState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Présence validée par empreinte : $sName"),
                                            backgroundColor: const Color(0xFF16A34A),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSaveButtonContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option Toggles Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sendSMS ? AppColors.info.withAlpha(20) : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sendSMS ? AppColors.info.withAlpha(60) : const Color(0xFFEEF2F6)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sms_outlined, size: 18, color: _sendSMS ? AppColors.info : AppColors.slate500),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text("Alerte SMS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                        ),
                        Switch.adaptive(
                          value: _sendSMS,
                          thumbColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.info : null,
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.info.withAlpha(80) : null,
                          ),
                          onChanged: !_canManageAttendance
                              ? null
                              : (val) {
                            setState(() {
                              _sendSMS = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sendWhatsApp ? AppColors.success.withAlpha(20) : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sendWhatsApp ? AppColors.success.withAlpha(60) : const Color(0xFFEEF2F6)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18, color: _sendWhatsApp ? AppColors.success : AppColors.slate500),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text("WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                        ),
                        Switch.adaptive(
                          value: _sendWhatsApp,
                          thumbColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.success : null,
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? AppColors.success.withAlpha(80) : null,
                          ),
                          onChanged: !_canManageAttendance
                              ? null
                              : (val) {
                            setState(() {
                              _sendWhatsApp = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  _isSaving || !_canManageAttendance ? null : _saveAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Enregistrer l'appel",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
