import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/connectivity_widgets.dart';
import '../../../core/widgets/sync_status_banner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/offline_vector_school_map.dart';
import '../data/ministry_repository.dart';

class MinistryDashboardScreen extends StatefulWidget {
  const MinistryDashboardScreen({super.key});

  @override
  State<MinistryDashboardScreen> createState() => _MinistryDashboardScreenState();
}

class _MinistryDashboardScreenState extends State<MinistryDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repository = locator<MinistryRepository>();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMsg = "";
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final summaryData = await _repository.getSummary();
      final schoolsList = await _repository.getSchools(query: _searchController.text);
      final alertsList = await _repository.getAlerts();

      setState(() {
        _summary = summaryData;
        _schools = schoolsList;
        _alerts = alertsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = "Impossible de charger les données: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_summary.isEmpty) {
      return const Center(child: Text("Aucune donnée disponible"));
    }

    final totalSchools = _summary['totalSchools']?.toString() ?? '0';
    final totalEleves = _summary['totalEleves']?.toString() ?? '0';
    final totalTeachers = _summary['totalEnseignants']?.toString() ?? '0';
    final successRate = "${_summary['avgSuccess'] ?? 0}%";
    final attendanceRate = "${_summary['avgAttendance'] ?? 0}%";
    final completionRate = "${_summary['avgCompletion'] ?? 0}%";
    final ratio = _summary['pupilTeacherRatio']?.toString() ?? '0';
    final priorityZones = _summary['priorityZones']?.toString() ?? '0';

    final noWater = _summary['noWater']?.toString() ?? '0';
    final noElectricity = _summary['noElec']?.toString() ?? '0';
    final noLatrines = _summary['noLatrines']?.toString() ?? '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MINISTÈRE DE L'ÉDUCATION NATIONALE",
                  style: TextStyle(
                    color: Color(0xFFF43F5E),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tableau de Bord National",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pilotage et analyse de performance scolaire",
                  style: TextStyle(
                    color: Colors.white.withAlpha(160),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Grid KPIs
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.35,
            children: [
              _buildSummaryCard("Écoles", totalSchools, Icons.domain, const Color(0xFF6D28D9)),
              _buildSummaryCard("Élèves", totalEleves, Icons.people, const Color(0xFF10B981)),
              _buildSummaryCard("Enseignants", totalTeachers, Icons.badge, const Color(0xFF3B82F6)),
              _buildSummaryCard("Ratio Élève/Ens", ratio, Icons.analytics, const Color(0xFFF59E0B)),
              _buildSummaryCard("Taux Réussite", successRate, Icons.stars, const Color(0xFF10B981)),
              _buildSummaryCard("Présence", attendanceRate, Icons.done_all, const Color(0xFF3B82F6)),
              _buildSummaryCard("Complétude", completionRate, Icons.fact_check, const Color(0xFF8B5CF6)),
              _buildSummaryCard("Zones Prioritaires", priorityZones, Icons.error_outline, const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 20),

          // Infrastructure Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Insuffisances Logistiques",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                _buildLogisticsRow("Sans accès à l'eau potable", noWater, Icons.opacity, Colors.blue),
                const Divider(),
                _buildLogisticsRow("Sans électricité", noElectricity, Icons.flash_on, Colors.amber),
                const Divider(),
                _buildLogisticsRow("Sans latrines opérationnelles", noLatrines, Icons.clean_hands, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsRow(String title, String count, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF475569))),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => _loadData(),
            decoration: InputDecoration(
              hintText: "Rechercher un établissement...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadData();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF6D28D9)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: _schools.isEmpty
              ? const Center(child: Text("Aucun établissement trouvé"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _schools.length,
                  itemBuilder: (context, index) {
                    final s = _schools[index];
                    final isComplete = s['completion'] >= 90;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          s['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text("Code: ${s['code'] ?? ''} | Commune: ${s['commune'] ?? ''}"),
                            const SizedBox(height: 4),
                            Text("Cycle: ${s['cycle'] ?? ''} | Type: ${s['type'] ?? ''}"),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildBadge("Élèves: ${s['eleves']}", Colors.blue),
                                const SizedBox(width: 8),
                                _buildBadge("Enseignants: ${s['enseignants']}", Colors.green),
                                const SizedBox(width: 8),
                                _buildBadge(
                                  "Fiche: ${s['completion']}%",
                                  isComplete ? Colors.teal : Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Icon(
                          isComplete ? Icons.check_circle : Icons.warning,
                          color: isComplete ? Colors.teal : Colors.orange,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return const Center(child: Text("Aucune alerte en cours"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        final isCritical = alert['severity'] == 'critical';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(
              isCritical ? Icons.error : Icons.warning,
              color: isCritical ? Colors.red : Colors.orange,
              size: 28,
            ),
            title: Text(
              alert['type'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text("Établissement: ${alert['school'] ?? ''}"),
                Text("Code: ${alert['code'] ?? ''}"),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MINISTÈRE DE L'ÉDUCATION"),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Color(0xFFF43F5E)),
            onPressed: () => context.push('/ministry/benchmarking'),
            tooltip: "Benchmark & Excellence Inter-Écoles",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFF43F5E),
          tabs: const [
            Tab(text: "Résumé", icon: Icon(Icons.bar_chart)),
            Tab(text: "Écoles", icon: Icon(Icons.domain)),
            Tab(text: "Carte", icon: Icon(Icons.map_rounded)),
            Tab(text: "Alertes", icon: Icon(Icons.notifications_active)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    const SyncStatusBanner(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildSchoolsTab(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: OfflineVectorSchoolMap(
                              schools: _schools.map((s) {
                                final isPriority = (s['completion'] ?? 100) < 50;
                                return SchoolMapPoint(
                                  id: s['id']?.toString() ?? s['code']?.toString() ?? '0',
                                  name: s['name']?.toString() ?? 'École',
                                  region: s['region']?.toString() ?? 'Région',
                                  xRatio: ((s['id']?.hashCode ?? 1) % 70 + 15) / 100.0,
                                  yRatio: ((s['name']?.hashCode ?? 1) % 65 + 20) / 100.0,
                                  studentsCount: s['eleves'] is num ? (s['eleves'] as num).toInt() : 450,
                                  cycle: s['cycle']?.toString() ?? 'Collège',
                                  isPriority: isPriority,
                                );
                              }).toList(),
                            ),
                          ),
                          _buildAlertsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
