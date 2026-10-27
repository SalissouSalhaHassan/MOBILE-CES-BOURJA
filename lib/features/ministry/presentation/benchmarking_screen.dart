import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class BenchmarkingScreen extends StatefulWidget {
  const BenchmarkingScreen({super.key});

  @override
  State<BenchmarkingScreen> createState() => _BenchmarkingScreenState();
}

class _BenchmarkingScreenState extends State<BenchmarkingScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _macro = {};
  List<Map<String, dynamic>> _benchmarks = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadBenchmarkingData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBenchmarkingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiClient.getJson('/api/mobile/executive/benchmarking');
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _macro = Map<String, dynamic>.from(data['macro'] ?? {});
          _benchmarks = List<Map<String, dynamic>>.from(data['benchmarks'] ?? []);
          _filtered = _benchmarks;
          _isLoading = false;
        });
      } else {
        throw Exception(res['error'] ?? 'Données indisponibles');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  void _filterSchools(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _benchmarks;
      } else {
        _filtered = _benchmarks.where((b) {
          final name = (b['name'] ?? '').toString().toLowerCase();
          final city = (b['city'] ?? '').toString().toLowerCase();
          return name.contains(query) || city.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Benchmark & Excellence Inter-Écoles',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            Text(
              'Tableau comparatif des performances académiques',
              style: TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBenchmarkingData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadBenchmarkingData, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBenchmarkingData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Macro KPI Overview
                        _buildMacroMetrics(),
                        const SizedBox(height: 16),

                        // Podium Top 3
                        if (_benchmarks.length >= 3) ...[
                          const Text(
                            '🏆 Podium d\'Excellence',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                          const SizedBox(height: 10),
                          _buildPodium(),
                          const SizedBox(height: 20),
                        ],

                        // Search
                        TextField(
                          controller: _searchController,
                          onChanged: _filterSchools,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un établissement ou une ville...',
                            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400, size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // League Table
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Classement Général & Ratios',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.slate900),
                            ),
                            Text(
                              '${_filtered.length} établissements',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._filtered.map((b) => _buildBenchmarkCard(b)),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMacroMetrics() {
    final totalSchools = _macro['totalSchools']?.toString() ?? '0';
    final totalStudents = _macro['totalStudents']?.toString() ?? '0';
    final passRate = (_macro['nationalAvgPassRate'] as num?)?.toDouble() ?? 0.0;
    final attendance = (_macro['nationalAvgAttendance'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        Expanded(child: _buildMiniKpi('Établissements', totalSchools, Icons.school_rounded, const Color(0xFF2563EB))),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniKpi('Élèves', totalStudents, Icons.people_alt_rounded, const Color(0xFF6366F1))),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniKpi('Réussite Moy.', '${passRate.toStringAsFixed(1)}%', Icons.verified_rounded, const Color(0xFF10B981))),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniKpi('Assiduité', '${attendance.toStringAsFixed(1)}%', Icons.timer_rounded, const Color(0xFFF59E0B))),
      ],
    );
  }

  Widget _buildMiniKpi(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.slate500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final top1 = _benchmarks[0];
    final top2 = _benchmarks[1];
    final top3 = _benchmarks[2];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _podiumItem(top2, '🥈 2ème', 100, const Color(0xFF94A3B8)),
          _podiumItem(top1, '🥇 1er', 125, const Color(0xFFFACC15)),
          _podiumItem(top3, '🥉 3ème', 85, const Color(0xFFF97316)),
        ],
      ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> b, String badge, double height, Color color) {
    return Column(
      children: [
        Text(badge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          width: 85,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                b['name'] ?? '',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${b['performanceIndex']}/100',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenchmarkCard(Map<String, dynamic> b) {
    final rank = b['rank'] ?? 0;
    final name = b['name'] ?? 'Établissement';
    final city = b['city'] ?? 'Niamey';
    final passRate = (b['passRate'] as num?)?.toDouble() ?? 0.0;
    final avgGrade = (b['averageGrade'] as num?)?.toDouble() ?? 0.0;
    final ratio = (b['studentTeacherRatio'] as num?)?.toDouble() ?? 0.0;
    final attendance = (b['attendanceRate'] as num?)?.toDouble() ?? 0.0;
    final index = (b['performanceIndex'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: rank <= 3 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? const Color(0xFFD97706) : AppColors.slate700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(city, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Score: $index',
                  style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricChip('Réussite', '${passRate.toStringAsFixed(1)}%', const Color(0xFF10B981)),
              _metricChip('Moyenne', '${avgGrade.toStringAsFixed(1)}/20', const Color(0xFF2563EB)),
              _metricChip('Assiduité', '${attendance.toStringAsFixed(1)}%', const Color(0xFFF59E0B)),
              _metricChip('Ratio Él/Ens', '${ratio.toStringAsFixed(0)} : 1', const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.slate500)),
      ],
    );
  }
}
