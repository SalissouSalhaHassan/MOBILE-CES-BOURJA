import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class CashflowForecastScreen extends StatefulWidget {
  const CashflowForecastScreen({super.key});

  @override
  State<CashflowForecastScreen> createState() => _CashflowForecastScreenState();
}

class _CashflowForecastScreenState extends State<CashflowForecastScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _timeline = [];
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadForecastData();
  }

  Future<void> _loadForecastData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiClient.getJson('/api/mobile/executive/cashflow-forecast');
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _summary = Map<String, dynamic>.from(data['summary'] ?? {});
          _timeline = List<Map<String, dynamic>>.from(data['monthlyTimeline'] ?? []);
          _classes = List<Map<String, dynamic>>.from(data['classes'] ?? []);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prévisions de Trésorerie & Cashflow',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Analyses prédictives des recouvrements',
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
            onPressed: _loadForecastData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate600)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadForecastData, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadForecastData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Cards
                        _buildSummaryMetrics(),
                        const SizedBox(height: 16),

                        // Interactive Chart Card
                        _buildChartCard(),
                        const SizedBox(height: 20),

                        // Class Collection Performance
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recouvrement par Classe',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                            ),
                            Text(
                              '${_classes.length} classes',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._classes.map((c) => _buildClassCard(c)),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryMetrics() {
    final expected = (_summary['totalExpected'] as num?)?.toDouble() ?? 0.0;
    final collected = (_summary['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final balance = (_summary['totalBalance'] as num?)?.toDouble() ?? 0.0;
    final rate = (_summary['collectionRate'] as num?)?.toDouble() ?? 0.0;
    final health = _summary['recoveryHealth']?.toString() ?? 'Normal';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Attendu Annuel',
                '${_currencyFormat.format(expected)} F',
                Icons.account_balance_wallet_outlined,
                const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Encaissé Réel',
                '${_currencyFormat.format(collected)} F',
                Icons.check_circle_outline_rounded,
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Reste à Recouvrer',
                '${_currencyFormat.format(balance)} F',
                Icons.pending_outlined,
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Taux & Santé',
                '${rate.toStringAsFixed(1)}% ($health)',
                Icons.trending_up_rounded,
                rate >= 70 ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    if (_timeline.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Courbe Prévisionnelle Mensuelle',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              Row(
                children: [
                  _chartLegend('Réalisé', const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _chartLegend('Projeté', const Color(0xFF6366F1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _timeline.length) {
                          return Text(
                            _timeline[idx]['month'] ?? '',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Realized Line
                  LineChartBarData(
                    spots: _timeline.asMap().entries.map((e) {
                      final val = (e.value['realized'] as num?)?.toDouble() ?? 0.0;
                      return FlSpot(e.key.toDouble(), val / 100000);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                  // Forecast Line
                  LineChartBarData(
                    spots: _timeline.asMap().entries.map((e) {
                      final val = (e.value['forecast'] as num?)?.toDouble() ?? 0.0;
                      return FlSpot(e.key.toDouble(), val / 100000);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF6366F1),
                    dashArray: [5, 4],
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c) {
    final name = c['className'] ?? 'Classe';
    final rate = (c['collectionRate'] as num?)?.toDouble() ?? 0.0;
    final expected = (c['expected'] as num?)?.toDouble() ?? 0.0;
    final paid = (c['paid'] as num?)?.toDouble() ?? 0.0;
    final studentCount = (c['studentCount'] as num?)?.toInt() ?? 0;
    final status = c['status']?.toString() ?? 'En cours';

    final Color statusColor = status == 'Excellent' || status == 'Soldé'
        ? const Color(0xFF10B981)
        : status == 'Bon'
            ? const Color(0xFF059669)
            : status == 'Moyen'
                ? const Color(0xFFF59E0B)
                : status == 'En cours'
                    ? const Color(0xFF6366F1)
                    : expected > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8);

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
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  if (studentCount > 0) ...[
                    const SizedBox(width: 6),
                    Text('• $studentCount élèves', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expected > 0 ? '$status (${rate.toStringAsFixed(0)}%)' : 'N/A',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Encaissé : ${_currencyFormat.format(paid)} F',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
              Text(
                'Total : ${_currencyFormat.format(expected)} F',
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
