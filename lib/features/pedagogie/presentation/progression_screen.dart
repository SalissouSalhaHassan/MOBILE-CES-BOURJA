import 'package:flutter/material.dart';
import '../data/planification_repository.dart';

class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({super.key});

  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  final _repo = PlanificationRepository();

  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'progress_desc'; // progress_desc | progress_asc | name

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getProgressionBySubject();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
        _sort();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _sort() {
    setState(() {
      switch (_sortBy) {
        case 'progress_desc':
          _data.sort((a, b) => (b['progressRate'] as int)
              .compareTo(a['progressRate'] as int));
        case 'progress_asc':
          _data.sort((a, b) => (a['progressRate'] as int)
              .compareTo(b['progressRate'] as int));
        case 'name':
          _data.sort((a, b) => (a['subjectName'] as String)
              .compareTo(b['subjectName'] as String));
      }
    });
  }

  // Aggregate stats
  int get _totalPlanned => _data.fold(0, (s, e) => s + (e['planned'] as int));
  int get _totalRealised =>
      _data.fold(0, (s, e) => s + (e['realised'] as int));
  int get _totalEnRetard =>
      _data.fold(0, (s, e) => s + (e['enRetard'] as int));
  int get _overallRate =>
      _totalPlanned > 0 ? (_totalRealised / _totalPlanned * 100).round() : 0;

  Color _rateColor(int rate) {
    if (rate >= 80) return const Color(0xFF10B981);
    if (rate >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        title: const Text(
          'Progression pédagogique',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              setState(() => _sortBy = v);
              _sort();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'progress_desc',
                child: Text('Taux décroissant'),
              ),
              const PopupMenuItem(
                value: 'progress_asc',
                child: Text('Taux croissant'),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Text('Par matière'),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _data.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCard(),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Par matière & classe'),
                          const SizedBox(height: 12),
                          ..._data.map(_buildProgressCard),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Taux global de progression',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_overallRate%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _overallRate / 100,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _rateColor(_overallRate),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(Icons.event_note, '$_totalPlanned', 'Planifiés'),
              _summaryItem(
                  Icons.check_circle, '$_totalRealised', 'Réalisés'),
              _summaryItem(
                  Icons.warning_amber, '$_totalEnRetard', 'En retard'),
              _summaryItem(
                Icons.speed,
                '${_data.length}',
                'Matières',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.bar_chart, color: Color(0xFF7C3AED), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(Map<String, dynamic> item) {
    final subjectName = item['subjectName'] as String? ?? '—';
    final className = item['className'] as String? ?? '—';
    final planned = item['planned'] as int;
    final realised = item['realised'] as int;
    final enRetard = item['enRetard'] as int;
    final rate = item['progressRate'] as int;
    final rateColor = _rateColor(rate);
    final remaining = (planned - realised).clamp(0, planned);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rateColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.book, color: rateColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      className,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Rate badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rateColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rate%',
                  style: TextStyle(
                    color: rateColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(rateColor),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 10),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Planifiés', planned, const Color(0xFF3B82F6)),
              _statItem('Réalisés', realised, const Color(0xFF10B981)),
              _statItem('Restants', remaining, const Color(0xFF94A3B8)),
              _statItem('En retard', enRetard, const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Erreur de chargement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_chart_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'Aucune donnée de progression',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez des plans pédagogiques et des séances pour suivre votre progression.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
