import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sync_status_banner.dart';
import '../../auth/data/auth_repository.dart';
import '../data/family_repository.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../ai/data/ai_repository.dart';
import '../../ai/presentation/early_warning_card.dart';
import '../../ai/presentation/ai_voice_assistant_sheet.dart';
import 'voice_note_player_card.dart';
import 'student_health_profile_sheet.dart';
import '../../health/presentation/student_health_sheet.dart';
import '../../discipline/presentation/student_conduct_sheet.dart';
import '../../admissions/presentation/online_admission_sheet.dart';
import '../../hostel/presentation/student_hostel_sheet.dart';
import '../../transport/presentation/student_transport_sheet.dart';
import '../../canteen/presentation/student_canteen_sheet.dart';
import 'sms_inquiry_helper_dialog.dart';
import 'mobile_money_payment_dialog.dart';
import '../../academics/utils/bulletin_pdf_generator.dart';
import '../../academics/utils/timetable_pdf_generator.dart';
import '../../finance/data/finance_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/push_notification_service.dart';

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final FamilyRepository _repository = locator<FamilyRepository>();
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;

  bool _isLoading = true;
  String? _errorMessage;
  String? _debugError;
  int _currentIndex = 0;
  int _unreadNotificationsCount = 0;

  String _role = 'student';
  int? _studentId;
  int? _schoolId;
  String _studentName = '';
  String _studentClass = '';

  List<Map<String, dynamic>> _sessions = [];
  int? _selectedSessionId;
  String _selectedSessionName = '';

  Map<String, dynamic> _student = {};
  List<Map<String, dynamic>> _timetable = [];
  List<Map<String, dynamic>> _grades = [];
  String? _selectedPeriod;
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _homework = [];
  Map<String, dynamic>? _aiWarningData;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToPushNotifications();
  }

  void _subscribeToPushNotifications() {
    try {
      final pushService = locator<MobilePushNotificationService>();
      _pushSubscription = pushService.onNotificationReceived.listen((notification) {
        if (mounted) {
          MobilePushNotificationService.showInAppPushBanner(context, notification);
          setState(() {
            _unreadNotificationsCount++;
          });
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to push notifications: $e');
    }
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  void _appendError(String component, dynamic error) {
    setState(() {
      _debugError = "${_debugError ?? ''}\n• $component: $error".trim();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _debugError = null;
    });

    try {
      final session = locator<SessionManager>();
      _role = await session.getRole() ?? 'student';
      _studentId = int.tryParse(await session.getStudentId() ?? '');
      _schoolId = int.tryParse(await session.getSchoolId() ?? '');
      _studentName = await session.getStudentName() ?? '';
      _studentClass = await session.getStudentClass() ?? '';

      // Sync fresh profile from API
      try {
        final token = await session.getToken() ?? '';
        if (token.isNotEmpty) {
          final apiProfile = await locator<MobileApiClient>().getMeProfile(token);
          if (apiProfile != null && apiProfile.studentId != null) {
            final freshId = int.tryParse(apiProfile.studentId!);
            if (freshId != null) {
              _studentId = freshId;
              _schoolId = int.tryParse(apiProfile.schoolId ?? '') ?? _schoolId;
              _studentName = apiProfile.studentName ?? _studentName;
              _studentClass = apiProfile.studentClass ?? _studentClass;
              await session.saveSession(
                token: token,
                email: await session.getEmail() ?? '',
                role: _role,
                employeeId: await session.getEmployeeId() ?? '',
                userId: await session.getUserId(),
                schoolId: _schoolId?.toString(),
                studentId: _studentId?.toString(),
                studentName: _studentName,
                studentClass: _studentClass,
              );
            }
          }
        }

        if (_studentId == null) {
          final client = SupabaseClientManager().client;
          final email = await session.getEmail() ?? '';
          final username = email.split('@').first;
          final userDoc = await client
              .from('users')
              .select('student_id, school_id')
              .or('utilisateur.eq.$username,utilisateur.eq.$email')
              .maybeSingle();

          if (userDoc != null && userDoc['student_id'] != null) {
            _studentId = int.tryParse(userDoc['student_id'].toString());
            _schoolId ??= int.tryParse(userDoc['school_id']?.toString() ?? '');
          } else {
            // Match student by num_admission
            final studentRow = await client
                .from('students')
                .select('id, school_id, nom_etudiant, classe')
                .or('num_admission.eq.${username.toUpperCase()},num_admission.eq.$username,num_admission.eq.$email')
                .maybeSingle();
            if (studentRow != null) {
              _studentId = int.tryParse(studentRow['id'].toString());
              _schoolId ??= int.tryParse(studentRow['school_id']?.toString() ?? '');
              _studentName = studentRow['nom_etudiant']?.toString() ?? _studentName;
              _studentClass = studentRow['classe']?.toString() ?? _studentClass;
            }
          }
        }

        if (_studentId != null) {
          if (_studentName.isEmpty || _studentClass.isEmpty) {
            final client = SupabaseClientManager().client;
            final st = await client
                .from('students')
                .select('nom_etudiant, classe')
                .eq('id', _studentId!)
                .maybeSingle();
            if (st != null) {
              _studentName = st['nom_etudiant']?.toString() ?? _studentName;
              _studentClass = st['classe']?.toString() ?? _studentClass;
            }
          }
          await session.saveSession(
            token: await session.getToken() ?? '',
            email: await session.getEmail() ?? '',
            role: _role,
            employeeId: await session.getEmployeeId() ?? '',
            userId: await session.getUserId(),
            schoolId: _schoolId?.toString(),
            studentId: _studentId?.toString(),
            studentName: _studentName,
            studentClass: _studentClass,
          );
        }
      } catch (healError) {
        debugPrint("[FamilyDashboard] Self-healing student profile failed: $healError");
      }

      if (_studentId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Aucun profil élève lié à ce compte. Vérifiez le rattachement du compte.";
        });
        return;
      }

      try {
        _student = await _repository.getStudentSnapshot(studentId: _studentId!);
        _studentName = (_student['nom_etudiant'] as String?) ?? _studentName;
        _studentClass = (_student['classe'] as String?) ?? _studentClass;
        _schoolId ??= (_student['school_id'] as num?)?.toInt();
      } catch (e) {
        _appendError("StudentSnapshot", e);
      }

      if (_schoolId != null) {
        try {
          _sessions = await _repository.getSessions(_schoolId!);
          if (_sessions.isNotEmpty) {
            final active = _sessions.firstWhere(
              (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
              orElse: () => _sessions.first,
            );
            _selectedSessionId = (active['id'] as num?)?.toInt() ?? 1;
            _selectedSessionName = active['session_name'] as String? ?? '';
          }
        } catch (e) {
          _appendError("Sessions", e);
        }
      }

      int unreadNotificationsCount = 0;
      try {
        final notifs = await locator<MessagingRepository>().getNotifications();
        unreadNotificationsCount = (notifs['unreadCount'] as num?)?.toInt() ?? 0;
      } catch (e) {
        debugPrint('Failed to load notifications count in family: $e');
      }

      await Future.wait([
        _loadTimetable().catchError((e) => _appendError("Timetable", e)),
        _loadGrades().catchError((e) => _appendError("Grades", e)),
        _loadAttendance().catchError((e) => _appendError("Attendance", e)),
        _loadHomework().catchError((e) => _appendError("Homework", e)),
        _loadAiWarning().catchError((e) => debugPrint("AI warning load error: $e")),
      ]);

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadNotificationsCount;
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

  Future<void> _loadTimetable() async {
    if (_schoolId == null || _studentClass.isEmpty) return;
    _timetable = await _repository.getTimetable(
      schoolId: _schoolId!,
      className: _studentClass,
      sessionId: _selectedSessionId,
    );
  }

  bool _termsMatch(String? termA, String? termB) {
    if (termA == null || termB == null) return false;
    final a = termA.trim().toLowerCase();
    final b = termB.trim().toLowerCase();
    if (a == b) return true;
    final numA = RegExp(r'\d+').firstMatch(a)?.group(0);
    final numB = RegExp(r'\d+').firstMatch(b)?.group(0);
    if (numA != null && numB != null && numA == numB) {
      if ((a.contains('s') || a.contains('semestre')) && (b.contains('s') || b.contains('semestre'))) return true;
      if ((a.contains('t') || a.contains('trimestre')) && (b.contains('t') || b.contains('trimestre'))) return true;
      if ((a.contains('p') || a.contains('periode') || a.contains('période')) &&
          (b.contains('p') || b.contains('periode') || b.contains('période'))) return true;
    }
    return a.contains(b) || b.contains(a);
  }

  Future<void> _loadGrades() async {
    if (_studentId == null) return;
    final res = await _repository.getGrades(
      studentId: _studentId!,
      schoolId: _schoolId ?? 1,
      sessionId: _selectedSessionId,
    );
    if (!mounted) return;
    setState(() {
      _grades = res;
      final periods = _grades
          .map((g) => g['term']?.toString().trim() ?? '')
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      periods.sort();
      if (periods.isNotEmpty) {
        if (_selectedPeriod == null || !periods.any((p) => _termsMatch(p, _selectedPeriod))) {
          _selectedPeriod = periods.last;
        }
      } else {
        _selectedPeriod = null;
      }
    });
    _loadAiWarning().catchError((e) => debugPrint("AI warning load error: $e"));
  }

  Future<void> _loadAttendance() async {
    if (_studentId == null) return;
    final res = await _repository.getAttendance(studentId: _studentId!);
    if (mounted) {
      setState(() {
        _attendance = res;
      });
    }
  }

  Future<void> _loadHomework() async {
    if (_studentClass.isEmpty) return;
    final res = await _repository.getHomework(className: _studentClass);
    if (mounted) {
      setState(() {
        _homework = res;
      });
    }
  }

  Future<void> _loadAiWarning() async {
    if (_studentId == null) return;
    final res = await locator<AiRepository>().getEarlyWarningAnalysis(
      studentId: _studentId!,
      sessionId: _selectedSessionId,
      term: _selectedPeriod,
    );
    if (mounted && res != null) {
      setState(() {
        _aiWarningData = res;
      });
    }
  }

  Future<void> _changeSession(int? sessionId) async {
    if (sessionId == null) return;
    final match = _sessions.firstWhere((s) => s['id'] == sessionId);
    setState(() {
      _selectedSessionId = sessionId;
      _selectedSessionName = match['session_name'] as String? ?? '';
      _isLoading = true;
    });
    await Future.wait([
      _loadTimetable(),
      _loadGrades(),
      _loadAttendance(),
      _loadHomework(),
      _loadAiWarning(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await locator<AuthRepository>().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  List<Map<String, dynamic>> get _todayTimetable {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final now = DateTime.now();
    var todayName = days[now.weekday - 1];
    
    // Fallback to Monday's schedule on weekends so the dashboard is not empty
    if (todayName == 'Samedi' || todayName == 'Dimanche') {
      todayName = 'Lundi';
    }

    final items = _timetable
        .where((item) => item['day_name'] == todayName)
        .toList();
    items.sort(
      (a, b) => ((a['period_number'] as num?)?.toInt() ?? 0).compareTo(
        (b['period_number'] as num?)?.toInt() ?? 0,
      ),
    );
    return items;
  }

  double _extractNormalizedScoreOn20(Map<String, dynamic> row) {
    final rawTotal = (row['total_score'] as num?)?.toDouble();
    final classWork = (row['class_work_score'] as num?)?.toDouble();
    final exam = (row['exam_score'] as num?)?.toDouble();
    final coef = ((row['coefficient'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 20.0);

    double? score;

    // 1. If classWork & exam exist with standard note <= 20
    if (classWork != null && exam != null && classWork > 0 && exam > 0) {
      if (classWork <= 20.0 && exam <= 20.0) {
        score = (classWork + exam) / 2.0;
      }
    }

    // 2. Check raw total
    if (score == null && rawTotal != null && rawTotal > 0) {
      if (rawTotal <= 20.0) {
        score = rawTotal;
      } else if (coef > 1.0 && (rawTotal / coef) <= 20.0) {
        // rawTotal was weighted score (score * coef)
        score = rawTotal / coef;
      } else if (rawTotal <= 40.0) {
        // rawTotal was sum of 2 grades out of 20 (sum = 40)
        score = rawTotal / 2.0;
      } else if (rawTotal <= 100.0) {
        // rawTotal was percentage out of 100
        score = (rawTotal / 100.0) * 20.0;
      } else {
        score = 20.0;
      }
    } else if (score == null) {
      if (exam != null && exam > 0) {
        score = exam <= 20.0 ? exam : (exam <= 100.0 ? (exam / 100.0) * 20.0 : 20.0);
      } else if (classWork != null && classWork > 0) {
        score = classWork <= 20.0 ? classWork : (classWork <= 100.0 ? (classWork / 100.0) * 20.0 : 20.0);
      } else {
        score = 0.0;
      }
    }

    return score.clamp(0.0, 20.0);
  }

  Map<String, double> get _gradeSummary {
    final list = (_selectedPeriod == null || _selectedPeriod!.isEmpty)
        ? _grades 
        : _grades.where((g) => _termsMatch(g['term']?.toString(), _selectedPeriod)).toList();
    final effectiveList = list.isNotEmpty ? list : _grades;
    if (effectiveList.isEmpty) {
      return {'average': 0, 'best': 0, 'risk': 0};
    }
    double totalPoints = 0;
    double totalCoef = 0;
    double best = 0;
    int risk = 0;
    for (final row in effectiveList) {
      final score = _extractNormalizedScoreOn20(row);
      final coef = ((row['coefficient'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 20.0);
      totalPoints += score * coef;
      totalCoef += coef;
      if (score > best) best = score;
      if (score < 10) risk++;
    }
    final avg = totalCoef > 0 ? (totalPoints / totalCoef) : (totalPoints / effectiveList.length);
    return {
      'average': avg.clamp(0.0, 20.0),
      'best': best.clamp(0.0, 20.0),
      'risk': risk.toDouble(),
    };
  }

  Map<String, int> get _attendanceSummary {
    int justified = 0;
    int unjustified = 0;
    int late = 0;
    for (final row in _attendance) {
      final status = (row['status'] as String? ?? '').toLowerCase();
      final remark = (row['remark'] as String? ?? '').toLowerCase();
      if (status.contains('retard') || status.contains('late')) {
        late++;
      } else if (status.contains('excus') || status.contains('justif') || remark.contains('just')) {
        justified++;
      } else if (status.contains('abs')) {
        unjustified++;
      }
    }
    return {'justified': justified, 'unjustified': unjustified, 'late': late};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        title: Text(
          _role == 'parent' ? 'Espace Parent' : 'Espace Élève',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  await context.push('/notifications');
                  _loadData();
                },
                tooltip: 'Notifications',
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (_sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSessionId,
                  borderRadius: BorderRadius.circular(16),
                  items: _sessions
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(
                            s['session_name'] as String? ?? 'Session',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _changeSession,
                ),
              ),
            ),
          IconButton(
            onPressed: () => StudentHealthSheet.show(
              context,
              studentId: _studentId,
              studentName: _studentName,
              studentClass: _studentClass,
            ),
            icon: const Icon(Icons.health_and_safety_rounded, color: Color(0xFFE11D48)),
            tooltip: 'Carnet de Santé & Infirmerie',
          ),
          IconButton(
            onPressed: () => AiVoiceAssistantSheet.show(
              context,
              studentId: _studentId,
              studentName: _studentName,
              studentClass: _studentClass,
            ),
            icon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF6366F1)),
            tooltip: 'Assistant Vocal Edut AI (Hausa / Zarma / FR)',
          ),
          IconButton(
            onPressed: () => context.push('/security/connected-devices'),
            icon: const Icon(Icons.phonelink_lock_rounded, color: Color(0xFF0F4C81)),
            tooltip: 'Appareils Connectés',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.mic_rounded, size: 20),
        label: const Text('Assistant Vocal 🇳🇪', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        onPressed: () => AiVoiceAssistantSheet.show(
          context,
          studentId: _studentId,
          studentName: _studentName,
          studentClass: _studentClass,
        ),
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  )
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildOverviewTab(),
                      _buildGradesTab(),
                      _buildAttendanceTab(),
                      _buildHomeworkTab(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Emploi'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph), label: 'Notes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check),
            label: 'Absences',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Devoirs',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final todayCourses = _todayTimetable;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          // Quick Service Shortcuts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  label: "Payer (Mobile Money)",
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0D9488),
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => MobileMoneyPaymentDialog(
                      studentId: _student['id'] as int? ?? _studentId ?? 1,
                      studentName: _student['nom_etudiant'] as String? ?? _studentName,
                      defaultAmount: 25000,
                      onPaymentSuccess: (res) {
                        _loadData();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Suivi Bus GPS",
                  icon: Icons.directions_bus_filled_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.push('/family/transport'),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Prédicteur BEPC / BAC",
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF6D28D9),
                  onTap: () => context.push('/family/exam-predictor', extra: {
                    'studentId': _student['id'] as int? ?? _studentId ?? 1,
                    'studentName': _student['nom_etudiant'] as String? ?? _studentName,
                    'studentClass': _studentClass,
                  }),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Santé & Infirmerie",
                  icon: Icons.health_and_safety_rounded,
                  color: const Color(0xFFE11D48),
                  onTap: () => StudentHealthSheet.show(
                    context,
                    studentId: _student['id'] as int? ?? _studentId,
                    studentName: _student['nom_etudiant'] as String? ?? _studentName,
                    studentClass: _studentClass,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Discipline & Conduite",
                  icon: Icons.shield_outlined,
                  color: const Color(0xFFE11D48),
                  onTap: () => StudentConductSheet.show(
                    context,
                    studentId: _student['id'] as int? ?? _studentId,
                    studentName: _student['nom_etudiant'] as String? ?? _studentName,
                    studentClass: _studentClass,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Inscriptions & Admissions",
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF059669),
                  onTap: () => OnlineAdmissionSheet.show(
                    context,
                    defaultParentPhone: _student['telephone_parent'] as String? ?? _student['telephone'] as String?,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Internat & Dortoir",
                  icon: Icons.home_work_outlined,
                  color: const Color(0xFF2563EB),
                  onTap: () => StudentHostelSheet.show(
                    context,
                    studentId: (_student['id'] as num?)?.toInt() ?? _studentId ?? 0,
                    studentName: _student['nom_etudiant'] as String? ?? _studentName,
                    studentClass: _studentClass,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Transport Scolaire",
                  icon: Icons.directions_bus_filled_rounded,
                  color: const Color(0xFF0284C7),
                  onTap: () => StudentTransportSheet.show(
                    context,
                    studentId: (_student['id'] as num?)?.toInt() ?? _studentId ?? 0,
                    studentName: _student['nom_etudiant'] as String? ?? _studentName,
                    studentClass: _studentClass,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Cantine & Repas",
                  icon: Icons.restaurant_rounded,
                  color: const Color(0xFF059669),
                  onTap: () => StudentCanteenSheet.show(
                    context,
                    studentId: (_student['id'] as num?)?.toInt() ?? _studentId ?? 0,
                    studentName: _student['nom_etudiant'] as String? ?? _studentName,
                    studentClass: _studentClass,
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Médiathèque & E-Learning",
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () => context.push('/family/library'),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Interroger par SMS",
                  icon: Icons.sms_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => SmsInquiryHelperDialog.show(
                    context,
                    matricule: _student['num_admission'] as String? ?? 'MAT-2025',
                    studentName: _student['nom_etudiant'] as String? ?? 'Élève',
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: "Appareils Connectés",
                  icon: Icons.phonelink_lock_rounded,
                  color: const Color(0xFF0F4C81),
                  onTap: () => context.push('/security/connected-devices'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Teacher Voice Notes Player Card (Hausa, Zarma, Français, Arabe)
          VoiceNotePlayerCard(studentId: _student['id'] as int? ?? _studentId ?? 1),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Programme du jour', Icons.today),
              if (_timetable.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: const Color(0xFFCCFBF1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    TimetablePdfGenerator.printOrShareTimetable(
                      student: _student,
                      timetableEntries: _timetable,
                      className: _studentClass,
                      sessionName: _selectedSessionName.isNotEmpty ? _selectedSessionName : '2025-2026',
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Imprimer PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (todayCourses.isEmpty)
            _buildEmptyCard('Aucun cours planifié pour aujourd’hui.')
          else
            ...todayCourses.map(_buildTimetableCard),
          const SizedBox(height: 24),
          if (_aiWarningData != null) ...[
            EarlyWarningCard(
              data: _aiWarningData!,
              onOpenTutor: () => context.push('/ai/tutor'),
            ),
            const SizedBox(height: 16),
          ],
          _buildSectionTitle('Aperçu rapide', Icons.insights),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Moyenne',
                  _gradeSummary['average']!.toStringAsFixed(1),
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  'Retards',
                  _attendanceSummary['late']!.toString(),
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Services scolaires & IA', Icons.dashboard_customize),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _buildServiceCard(
                title: 'Tuteur IA',
                subtitle: 'Assistance & révisions 24/7',
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFF6366F1),
                onTap: () => context.push('/ai/tutor'),
              ),
              _buildServiceCard(
                title: 'Carte Scolaire',
                subtitle: 'Badge QR code dynamique',
                icon: Icons.badge_rounded,
                color: const Color(0xFF0284C7),
                onTap: () => context.push('/family/student-id'),
              ),
              _buildServiceCard(
                title: 'Finance',
                subtitle: 'Frais, paiements et reçus PDF',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF0F766E),
                onTap: () => context.push('/family/finance'),
              ),
              _buildServiceCard(
                title: 'Transport',
                subtitle: 'Bus GPS & suivi direct',
                icon: Icons.directions_bus_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => context.push('/family/transport'),
              ),
              _buildServiceCard(
                title: 'Médiathèque & E-Learning',
                subtitle: 'Livres PDF, vidéos & annales BEPC/BAC',
                icon: Icons.local_library_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => context.push('/family/library'),
              ),
              _buildServiceCard(
                title: 'Internat',
                subtitle: 'Chambre, bâtiment & dortoir',
                icon: Icons.hotel_rounded,
                color: const Color(0xFFD97706),
                onTap: () => context.push('/family/hostel'),
              ),
              _buildServiceCard(
                title: 'Notifications',
                subtitle: 'Messages de l\'école',
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFFF43F5E),
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAbsenceExcuseDialog() {
    final reasonController = TextEditingController(text: 'Raison médicale (Maladie)');
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Justifier une Absence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motif de l\'absence:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: reasonController.text,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Raison médicale (Maladie)', child: Text('Raison médicale (Maladie)')),
                    DropdownMenuItem(value: 'Impératif familial', child: Text('Impératif familial')),
                    DropdownMenuItem(value: 'Déplacement d\'urgence', child: Text('Déplacement d\'urgence')),
                    DropdownMenuItem(value: 'Autre motif légitime', child: Text('Autre motif légitime')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => reasonController.text = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Explications / Remarques:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Précisez les détails ou le nom du praticien...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (_studentId == null) return;
                      setDialogState(() => isSubmitting = true);
                      final ok = await _repository.justifyAbsence(
                        studentId: _studentId!,
                        reason: reasonController.text,
                        notes: notesController.text,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Justification d\'absence transmise à l\'administration !'
                                : 'Erreur lors de la transmission du justificatif.'),
                            backgroundColor: ok ? const Color(0xFF059669) : Colors.red,
                          ),
                        );
                        _loadAttendance();
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Transmettre'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReportCardPdf() async {
    try {
      final selectedPeriod = _selectedPeriod;
      final period = (selectedPeriod != null && selectedPeriod.isNotEmpty)
          ? selectedPeriod
          : 'Général';
      final filteredGrades = _grades
          .where((g) =>
              selectedPeriod == null ||
              selectedPeriod.isEmpty ||
              _termsMatch(g['term']?.toString(), selectedPeriod))
          .toList();

      final isUniv = _studentClass.toLowerCase().contains('licence') ||
          _studentClass.toLowerCase().contains('master') ||
          _studentClass.toLowerCase().contains('doctorat') ||
          _studentClass.toLowerCase().contains('l1') ||
          _studentClass.toLowerCase().contains('l2') ||
          _studentClass.toLowerCase().contains('l3') ||
          _studentClass.toLowerCase().contains('m1') ||
          _studentClass.toLowerCase().contains('m2') ||
          (_student['educational_level']?.toString() ?? '').toLowerCase().contains('univ');

      final gradesToUse = isUniv
          ? _grades
          : (filteredGrades.isNotEmpty ? filteredGrades : _grades);

      Map<String, dynamic>? headerConfig;
      if (_schoolId != null) {
        try {
          final headerRes = await locator<FinanceRepository>().getDocumentHeader(_schoolId!);
          if (headerRes['success'] == true) {
            headerConfig = headerRes['data'] as Map<String, dynamic>?;
          }
        } catch (e) {
          debugPrint("Error fetching document header for report card: $e");
        }
      }

      final pdfBytes = await OfficialBulletinPdfGenerator.generateBulletinBytes(
        student: _student.isNotEmpty ? _student : {
          'nom_etudiant': _studentName,
          'classe': _studentClass,
          'num_admission': _studentId?.toString() ?? 'N/A',
        },
        grades: gradesToUse,
        summary: _gradeSummary,
        period: period,
        sessionName: _selectedSessionName.isNotEmpty ? _selectedSessionName : '2024-2025',
        headerConfig: headerConfig,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      debugPrint("Error generating official bulletin PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la génération du bulletin: $e"),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildGradesTab() {
    final avg = _gradeSummary['average'] ?? 0;
    
    // Unique periods from grades
    final periods = _grades
        .map((g) => g['term']?.toString().trim() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    periods.sort();

    final filteredGrades = _grades
        .where((g) =>
            _selectedPeriod == null ||
            _selectedPeriod!.isEmpty ||
            _termsMatch(g['term']?.toString(), _selectedPeriod))
        .toList();

    final displayGrades = filteredGrades.isNotEmpty ? filteredGrades : _grades;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        VoiceNotePlayerCard(studentId: _student['id'] as int? ?? _studentId ?? 1),
        _buildSectionTitle('Résultats & bulletins', Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        if (periods.isNotEmpty) _buildPeriodSelector(periods),
        _buildLineChartCard(displayGrades),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                'Moyenne générale',
                avg.toStringAsFixed(2),
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStat(
                'Meilleure note',
                (_gradeSummary['best'] ?? 0).toStringAsFixed(1),
                AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _generateReportCardPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Imprimer / Exporter le Bulletin PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 16),
        if (displayGrades.isEmpty)
          _buildEmptyCard(
            'Aucune note disponible pour le moment.',
          )
        else
          ...displayGrades.map(_buildGradeCard),
      ],
    );
  }

  Widget _buildPeriodSelector(List<String> periods) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // slate 100
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = _termsMatch(_selectedPeriod, period);
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    formatTerm(period),
                    style: TextStyle(
                      color: isSelected ? AppColors.slate900 : AppColors.slate500,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String formatTerm(String term) {
    if (term == 'S1') return 'Semestre 1';
    if (term == 'S2') return 'Semestre 2';
    if (term == 'T1') return 'Trimestre 1';
    if (term == 'T2') return 'Trimestre 2';
    if (term == 'T3') return 'Trimestre 3';
    if (term == '1') return 'Période 1';
    if (term == '2') return 'Période 2';
    if (term == '3') return 'Période 3';
    return term;
  }

  Widget _buildAttendanceTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSectionTitle(
            'Suivi des absences et retards',
            Icons.stacked_bar_chart,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _openAbsenceExcuseDialog,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Justifier une Absence d\'Élève', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 14),
          _buildAttendanceChartCard(),
          const SizedBox(height: 16),
          if (_attendance.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Excellente Assiduité Scolaire 🎓',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'L\'élève ${_studentName.isNotEmpty ? _studentName : "inscrit"} est à jour et ne présente aucune absence injustifiée ni retard.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: const [
                              Text('100%', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 14)),
                              SizedBox(height: 2),
                              Text('Présence', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: const [
                              Text('0 h', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 14)),
                              SizedBox(height: 2),
                              Text('Manquées', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: const [
                              Text('Exemplaire', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), fontSize: 12)),
                              SizedBox(height: 2),
                              Text('Discipline', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ..._attendance.take(50).map(_buildAttendanceCard),
        ],
      ),
    );
  }

  Widget _buildHomeworkTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('Homework Hub', Icons.menu_book_rounded),
        const SizedBox(height: 12),
        if (_homework.isEmpty)
          _buildEmptyCard('Aucun devoir publié pour cette classe.')
        else
          ..._homework.map(_buildHomeworkCard),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _role == 'parent'
                  ? 'Vue parent connectée'
                  : 'Vue élève connectée',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _studentName.isEmpty ? 'Élève' : _studentName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _studentClass.isEmpty ? 'Classe non définie' : _studentClass,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (_selectedSessionName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Session: $_selectedSessionName',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineChartCard(List<Map<String, dynamic>> filteredGrades) {
    final bars = <FlSpot>[];
    for (var i = 0; i < filteredGrades.length; i++) {
      final score = _extractNormalizedScoreOn20(filteredGrades[i]);
      bars.add(FlSpot(i.toDouble(), score));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution par matière', style: AppTextStyles.bodyBold),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: filteredGrades.isEmpty
                ? const Center(child: Text('Pas encore de notes'))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 20,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppColors.slate100, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 5,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= filteredGrades.length) {
                                return const SizedBox.shrink();
                              }
                              final subject =
                                  filteredGrades[index]['school_subjects']?['subject_code']
                                      as String? ??
                                  (filteredGrades[index]['school_subjects']?['subject_name']
                                          as String? ??
                                      'M');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  subject.length > 4
                                      ? subject.substring(0, 4)
                                      : subject,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: bars,
                          isCurved: true,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                          ),
                          barWidth: 4,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2563EB).withValues(alpha: 0.2),
                                const Color(0xFF10B981).withValues(alpha: 0.02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChartCard() {
    final summary = _attendanceSummary;
    final totalIncidents = summary['justified']! + summary['unjustified']! + summary['late']!;
    final totalSessions = _attendance.length;
    int presents = 0;
    for (final r in _attendance) {
      final s = (r['status'] as String? ?? '').toLowerCase();
      if (s.contains('présent') || s.contains('present')) presents++;
    }
    final attendanceRate = totalSessions == 0
        ? 100
        : (((presents + summary['justified']!) / totalSessions) * 100).round().clamp(0, 100);

    final sections = [
      if (summary['justified']! > 0)
        PieChartSectionData(
          value: summary['justified']!.toDouble(),
          title: 'Just.',
          color: AppColors.info,
          radius: 54,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (summary['unjustified']! > 0)
        PieChartSectionData(
          value: summary['unjustified']!.toDouble(),
          title: 'Non just.',
          color: AppColors.danger,
          radius: 58,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (summary['late']! > 0)
        PieChartSectionData(
          value: summary['late']!.toDouble(),
          title: 'Retard',
          color: AppColors.warning,
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Répartition des incidents', style: AppTextStyles.bodyBold),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: attendanceRate >= 90
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Assiduité: $attendanceRate%',
                  style: TextStyle(
                    color: attendanceRate >= 90 ? const Color(0xFF059669) : const Color(0xFFD97706),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: totalIncidents == 0
                      ? Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 9,
                                  backgroundColor: Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                                  SizedBox(height: 2),
                                  Text(
                                    '100%',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Assidu',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 32,
                            sections: sections,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        'Absences justifiées',
                        summary['justified']!,
                        AppColors.info,
                      ),
                      const SizedBox(height: 10),
                      _buildLegendItem(
                        'Absences non justifiées',
                        summary['unjustified']!,
                        AppColors.danger,
                      ),
                      const SizedBox(height: 10),
                      _buildLegendItem(
                        'Retards',
                        summary['late']!,
                        AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label • $value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableCard(Map<String, dynamic> row) {
    final subject = row['school_subjects']?['subject_name'] ?? 'Matière';
    final teacher = row['employees']?['nom'] ?? 'Professeur';
    final period = (row['period_number'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'P$period',
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: AppTextStyles.bodyBold),
                const SizedBox(height: 4),
                Text(
                  'Salle: ${row['room_name'] ?? 'Non définie'} • $teacher',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> row) {
    final subject = row['school_subjects']?['subject_name'] ?? 'Matière';
    final devoir = (row['class_work_score'] as num?)?.toDouble() ?? 0;
    final exam = (row['exam_score'] as num?)?.toDouble() ?? 0;
    final total = _extractNormalizedScoreOn20(row);
    final appreciation = row['appreciation'] ?? '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subject, style: AppTextStyles.bodyBold)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: total >= 10
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  total.toStringAsFixed(1),
                  style: TextStyle(
                    color: total >= 10 ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock('Devoirs', devoir.toStringAsFixed(1)),
              ),
              Expanded(
                child: _buildMetricBlock('Examen', exam.toStringAsFixed(1)),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Appréciation',
                  appreciation.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? 'Présent';
    final rawDate = row['date'] as String? ?? '';
    final remark = row['remark'] as String? ?? 'Aucune remarque';
    final subject = row['school_subjects']?['subject_name'] ?? 'Général';
    final color = status.toLowerCase().contains('retard')
        ? AppColors.warning
        : (status.toLowerCase().contains('excus') || status.toLowerCase().contains('justif'))
        ? AppColors.info
        : status.toLowerCase().contains('abs')
        ? AppColors.danger
        : AppColors.success;

    String displayDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(rawDate);
        if (parsed != null) {
          displayDate = DateFormat('dd/MM/yyyy à HH:mm').format(parsed.toLocal());
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$status • $subject', style: AppTextStyles.bodyBold),
                const SizedBox(height: 4),
                Text(displayDate.isNotEmpty ? displayDate : 'Date non définie', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(remark, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> row) {
    final dueDate = row['date_due'] as String? ?? '';
    final assignedDate = row['date_assigned'] as String? ?? '';
    final subject = row['school_subjects']?['subject_name'] ?? 'Matière';
    final isDelivered = (row['attachment_path'] as String?)?.isNotEmpty == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row['title'] as String? ?? 'Devoir',
                  style: AppTextStyles.bodyBold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDelivered
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isDelivered ? 'Pièce jointe' : 'À suivre',
                  style: TextStyle(
                    color: isDelivered ? AppColors.info : AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subject, style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Text(
            row['description'] as String? ?? 'Aucune description fournie.',
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Publié',
                  assignedDate.isEmpty ? '-' : assignedDate.split('T').first,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Échéance',
                  dueDate.isEmpty ? '-' : dueDate.split('T').first,
                ),
              ),
              Expanded(child: _buildMetricBlock('Suivi', 'En attente')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.slate400),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.heading3),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Text(
        message,
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBF0F5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
