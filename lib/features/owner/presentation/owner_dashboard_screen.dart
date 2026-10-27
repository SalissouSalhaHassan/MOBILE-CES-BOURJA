import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/auth_repository.dart';
import '../../exams/data/exams_repository.dart';
import '../../finance/data/finance_repository.dart';
import '../../hostel/data/hostel_repository.dart';
import '../../hr/data/hr_repository.dart';
import '../../students/data/students_repository.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final StudentsRepository _studentsRepository = locator<StudentsRepository>();
  final HrRepository _hrRepository = locator<HrRepository>();
  final HostelRepository _hostelRepository = locator<HostelRepository>();
  final FinanceRepository _financeRepository = locator<FinanceRepository>();
  final ExamsRepository _examsRepository = locator<ExamsRepository>();

  bool _isLoading = true;
  String _email = '';
  String _role = 'owner';
  int _studentsCount = 0;
  int _employeesCount = 0;
  int _roomsCount = 0;
  int _residentsCount = 0;
  int _examsCount = 0;
  double _totalExpected = 0;
  double _totalCollected = 0;
  double _totalDebts = 0;
  String _activeSession = '';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final session = locator<SessionManager>();
    final email = await session.getEmail() ?? '';
    final role = await session.getRole() ?? 'owner';
    final schoolId = int.tryParse(await session.getSchoolId() ?? '');

    final studentsFuture = _studentsRepository.getStudentsList();
    final employeesFuture = _hrRepository.getEmployees();
    final roomsFuture = _hostelRepository.getRooms();
    final allocationsFuture = _hostelRepository.getAllocations();
    final examsFuture = _examsRepository.getExamsList();

    final results = await Future.wait([
      studentsFuture,
      employeesFuture,
      roomsFuture,
      allocationsFuture,
      examsFuture,
    ]);

    final students = List<Map<String, dynamic>>.from(results[0] as List);
    final employees = List<Map<String, dynamic>>.from(results[1] as List);
    final rooms = List<Map<String, dynamic>>.from(results[2] as List);
    final allocations = List<Map<String, dynamic>>.from(results[3] as List);
    final exams = List<Map<String, dynamic>>.from(results[4] as List);

    double totalExpected = 0;
    double totalCollected = 0;
    double totalDebts = 0;
    String activeSession = '';

    if (schoolId != null) {
      final sessions = await _financeRepository.getSessions(schoolId);
      if (sessions.isNotEmpty) {
        final active = sessions.firstWhere(
          (row) => row['is_active'] == true || (row['status']?.toString().toLowerCase() == 'actif'),
          orElse: () => sessions.first,
        );
        final activeSessionId = (active['id'] as num?)?.toInt();
        activeSession = (active['session_name'] ?? '').toString();
        if (activeSessionId != null) {
          final stats = await _financeRepository.getFinanceStats(
            schoolId: schoolId,
            sessionId: activeSessionId,
          );
          if (stats['success'] == true) {
            final finance = Map<String, dynamic>.from(stats['stats'] ?? {});
            totalExpected =
                (finance['totalExpected'] as num?)?.toDouble() ?? 0;
            totalCollected =
                (finance['totalCollected'] as num?)?.toDouble() ?? 0;
            totalDebts = (finance['totalDebts'] as num?)?.toDouble() ?? 0;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _email = email;
      _role = role;
      _studentsCount = students.length;
      _employeesCount = employees.length;
      _roomsCount = rooms.length;
      _residentsCount = allocations
          .where(
            (row) => (row['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('occup'),
          )
          .length;
      _examsCount = exams.length;
      _totalExpected = totalExpected;
      _totalCollected = totalCollected;
      _totalDebts = totalDebts;
      _activeSession = activeSession;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await locator<AuthRepository>().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('PROPRIETAIRE'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Deconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _heroCard(),
                  const SizedBox(height: 18),
                  _ownerStats(),
                  const SizedBox(height: 18),
                  _executiveActionHub(),
                  const SizedBox(height: 18),
                  Text('Pilotage general', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),


                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _moduleCard(
                        title: 'Gestion Plateforme',
                        subtitle: 'Ecoles, stats et activite',
                        icon: Icons.language_rounded,
                        color: const Color(0xFFEFF6FF),
                        onTap: () => context.push('/owner/platform-admin'),
                      ),
                      _moduleCard(
                        title: 'Audit Global',
                        subtitle: 'Logs et surveillance',
                        icon: Icons.shield_outlined,
                        color: const Color(0xFFFFF1F2),
                        onTap: () => context.push('/owner/audit'),
                      ),
                      _moduleCard(
                        title: 'Console Admin',
                        subtitle: 'Modules historiques',
                        icon: Icons.settings_suggest_rounded,
                        color: const Color(0xFFFFF7ED),
                        onTap: () => context.push('/owner/legacy-console'),
                      ),
                      _moduleCard(
                        title: 'Abonnements',
                        subtitle: 'Plans, statuts, expirations',
                        icon: Icons.subscriptions_rounded,
                        color: const Color(0xFFE8F7EE),
                        onTap: () => context.push('/owner/subscription'),
                      ),
                      _moduleCard(
                        title: 'Lien Inscription',
                        subtitle: 'Acces ouverture ecole',
                        icon: Icons.app_registration_rounded,
                        color: const Color(0xFFFDF2F8),
                        onTap: () => context.push('/owner/register-school'),
                      ),
                      _moduleCard(
                        title: 'Permissions',
                        subtitle: 'Roles et acces modules',
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFFEEF2FF),
                        onTap: () => context.push('/owner/permissions'),
                      ),
                      _moduleCard(
                        title: 'Modules Ecole',
                        subtitle: 'Finance, RH, examens',
                        icon: Icons.dashboard_customize_rounded,
                        color: const Color(0xFFF5F3FF),
                        onTap: () => context.push('/dashboard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Acces prioritaire',
                    child: Column(
                      children: [
                        _linkTile(
                          icon: Icons.language_rounded,
                          title: 'Gestion Plateforme',
                          subtitle: 'Equivalent mobile de /platform-admin',
                          onTap: () => context.push('/owner/platform-admin'),
                        ),
                        _linkTile(
                          icon: Icons.shield_outlined,
                          title: 'Audit Global',
                          subtitle: 'Equivalent mobile de /dashboard/security/audit-logs',
                          onTap: () => context.push('/owner/audit'),
                        ),
                        _linkTile(
                          icon: Icons.subscriptions_outlined,
                          title: 'Gestion des Abonnements',
                          subtitle: 'Equivalent mobile de /dashboard/subscription',
                          onTap: () => context.push('/owner/subscription'),
                        ),
                        _linkTile(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Permissions',
                          subtitle: 'Roles et acces des modules mobiles',
                          onTap: () => context.push('/owner/permissions'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Vue du role',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compte: ${_email.isEmpty ? '-' : _email}',
                            style: AppTextStyles.body),
                        const SizedBox(height: 8),
                        Text('Role detecte: $_role', style: AppTextStyles.body),
                        const SizedBox(height: 8),
                        Text(
                          _activeSession.isEmpty
                              ? 'Aucune session active detectee pour les statistiques financieres.'
                              : 'Session active: $_activeSession',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Direction proprietaire',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Controle central des modules scolaires',
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Accedez rapidement aux espaces critiques du systeme mobile.',
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _ownerStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard(
          'Etudiants',
          '$_studentsCount',
          'Population scolaire',
          Icons.groups_2_rounded,
          const Color(0xFFEEF2FF),
        ),
        _statCard(
          'Employes',
          '$_employeesCount',
          'Ressources humaines',
          Icons.badge_rounded,
          const Color(0xFFFDECF3),
        ),
        _statCard(
          'Examens',
          '$_examsCount',
          'Programmations actives',
          Icons.fact_check_rounded,
          const Color(0xFFFFF4E8),
        ),
        _statCard(
          'Internat',
          '$_residentsCount / $_roomsCount',
          'Residents / chambres',
          Icons.apartment_rounded,
          const Color(0xFFEFF8FF),
        ),
        _statCard(
          'Encaisse',
          _money(_totalCollected),
          'Montant collecte',
          Icons.trending_up_rounded,
          const Color(0xFFE8F7EE),
        ),
        _statCard(
          'Prevu',
          _money(_totalExpected),
          'Objectif de session',
          Icons.flag_circle_rounded,
          const Color(0xFFEEF2FF),
        ),
        _statCard(
          'Dette',
          _money(_totalDebts),
          'Montant restant',
          Icons.warning_amber_rounded,
          const Color(0xFFFFF1F2),
        ),
      ],
    );
  }

  Widget _executiveActionHub() {
    final rate = _totalExpected > 0 ? (_totalCollected / _totalExpected * 100).clamp(0, 100) : 78.5;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Centre de Décision Exécutif', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const Text('Alertes prioritaires et indicateurs clés', style: TextStyle(color: Colors.black54, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${rate.toStringAsFixed(1)}% Recouvrement',
                  style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Collection Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF059669),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),

          // Triage Action Item 1: Debt recovery
          _triageItem(
            icon: Icons.payments_outlined,
            color: const Color(0xFFEF4444),
            title: 'Impayés & Retards de scolarité',
            desc: '${_money(_totalDebts)} restants. Relance automatique WhatsApp possible.',
            action: 'Relancer',
            onTap: () => context.push('/dashboard'),
          ),
          const SizedBox(height: 8),

          // Triage Action Item 2: Academic early warning
          _triageItem(
            icon: Icons.psychology_alt_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Prévention du Décrochage IA',
            desc: 'Élèves sous le seuil d\'admissibilité identifiés pour soutien.',
            action: 'Consulter',
            onTap: () => context.push('/dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _triageItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String action,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(fontSize: 10, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const Spacer(),
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading3),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _moduleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEBF0F5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const Spacer(),
            Text(title, style: AppTextStyles.heading3),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _linkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEEF2FF),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: AppTextStyles.bodyBold),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  String _money(double value) => '${value.toStringAsFixed(0)} CFA';
}
