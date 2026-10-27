import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../data/attendance_repository.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  String _filterType = "week"; // "day" | "week" | "month" | "year"
  DateTime _selectedDate = DateTime.now();
  
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _slots = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final employeeIdStr = await locator<SessionManager>().getEmployeeId();
    final employeeId = int.tryParse(employeeIdStr ?? '');

    if (employeeId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Session invalide. Veuillez vous reconnecter.";
      });
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final result = await locator<AttendanceRepository>().getTeacherScheduleAttendance(
      employeeId: employeeId,
      filterType: _filterType,
      dateStr: dateStr,
    );

    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _slots = result['slots'];
          _stats = result['stats'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? "Une erreur est survenue";
          _isLoading = false;
        });
      }
    }
  }

  void _handleSlotClick(dynamic slot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withAlpha(25),
                    child: const Icon(Icons.school, color: AppColors.primary),
                  ),
                  title: const Text("Faire l'appel des élèves", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Marquer les présences pour ${slot['className']}"),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      '/attendance/student-roll',
                      extra: {
                        'classId': slot['classId'],
                        'className': slot['className'],
                        'subjectId': slot['subjectId'],
                        'subjectName': slot['subjectName'],
                        'initialDateStr': slot['dateStr'],
                      },
                    ).then((_) => _fetchAttendanceData());
                  },
                ),
                const Divider(height: 1, color: Color(0xFFEEF2F6)),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.slate100,
                    child: Icon(Icons.close, color: AppColors.slate500),
                  ),
                  title: const Text("Annuler", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate700)),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _changeDate(int offset) {
    setState(() {
      if (_filterType == "day") {
        _selectedDate = _selectedDate.add(Duration(days: offset));
      } else if (_filterType == "week") {
        _selectedDate = _selectedDate.add(Duration(days: offset * 7));
      } else if (_filterType == "month") {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
      } else if (_filterType == "year") {
        _selectedDate = DateTime(_selectedDate.year + offset, 1, 1);
      }
    });
    _fetchAttendanceData();
  }

  String _getDateRangeText() {
    if (_filterType == "day") {
      return DateFormat('dd MMMM yyyy').format(_selectedDate);
    } else if (_filterType == "week") {
      final weekday = _selectedDate.weekday;
      final start = _selectedDate.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 6));
      return "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}";
    } else if (_filterType == "month") {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    } else {
      return DateFormat('yyyy').format(_selectedDate);
    }
  }

  // Print PDF report of the attendance
  Future<void> _printReport() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text("Rapport de presence Enseignant - Edut", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 12),
                pw.Text("Periode: ${_getDateRangeText()}"),
                pw.Text("Taux de presence: ${_stats['rate']}%"),
                pw.Text("Heures de cours planifiees: ${_stats['total']}"),
                pw.Text("Heures de cours assurees: ${_stats['attended']}"),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ["Date", "Periode", "Classe", "Matiere", "Statut"],
                  data: _slots.map((slot) => [
                    slot['dateStr'] ?? '',
                    "P${slot['periodNumber']}",
                    slot['className'] ?? '',
                    slot['subjectName'] ?? '',
                    slot['status'] ?? '',
                  ]).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text("Calendrier & Présences", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 22),
            onPressed: _slots.isEmpty ? null : _printReport,
            tooltip: 'Imprimer PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Types selectors
          _buildFilterBar(),
          
          // Date slider controller
          _buildDateSelector(),

          // Main content or loading state
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)))
                    : _slots.isEmpty
                        ? const Center(child: Text("Aucun cours programmé sur cette période.", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold)))
                        : Column(
                            children: [
                              // Top statistics ring & metrics dashboard
                              _buildDashboardCard(),
                              
                              // List of class slots in timeline style
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                  itemCount: _slots.length,
                                  itemBuilder: (context, index) {
                                    return _buildSlotCard(_slots[index]);
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFilterButton("Jour", "day"),
          _buildFilterButton("Semaine", "week"),
          _buildFilterButton("Mois", "month"),
          _buildFilterButton("Année", "year"),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterType = value;
        });
        _fetchAttendanceData();
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.slate700,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      backgroundColor: AppColors.slate100,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.slate500),
            onPressed: () => _changeDate(-1),
          ),
          Text(
            _getDateRangeText(),
            style: const TextStyle(color: AppColors.slate900, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.slate500),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard() {
    final rate = _stats['rate'] ?? 100;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.slate900, AppColors.slate800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress Indicator for Rate
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 76,
                width: 76,
                child: CircularProgressIndicator(
                  value: rate / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    rate >= 90
                        ? AppColors.success
                        : (rate >= 75 ? AppColors.warning : AppColors.danger),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$rate%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    "Taux",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Statistics Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "RÉSUMÉ DES SÉANCES",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDashboardMetric(
                      label: "Total",
                      value: "${_stats['total'] ?? 0}",
                      color: Colors.white,
                    ),
                    _buildDashboardMetric(
                      label: "Assurés",
                      value: "${_stats['attended'] ?? 0}",
                      color: AppColors.success,
                    ),
                    _buildDashboardMetric(
                      label: "Absences",
                      value: "${_stats['absent'] ?? 0}",
                      color: AppColors.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(dynamic slot) {
    final status = slot['status'] as String;
    
    Color statusColor = AppColors.slate400;
    IconData statusIcon = Icons.help_outline;

    if (status == "Présent") {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    } else if (status == "Absent") {
      statusColor = AppColors.danger;
      statusIcon = Icons.cancel;
    } else if (status == "En Retard") {
      statusColor = AppColors.warning;
      statusIcon = Icons.watch_later;
    } else if (status == "Planifié") {
      statusColor = AppColors.info;
      statusIcon = Icons.calendar_today;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _handleSlotClick(slot),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular avatar icon representing status
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withAlpha(25),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 16),

              // Class & subject details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot['subjectName'] ?? 'Matière',
                      style: const TextStyle(color: AppColors.slate900, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.room_outlined, size: 14, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(
                          "${slot['className']} • Salle ${slot['roomName']}",
                          style: const TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 14, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(
                          "Période ${slot['periodNumber']} • ${slot['dateStr']}",
                          style: const TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
