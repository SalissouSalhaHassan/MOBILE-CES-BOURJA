import 'package:flutter/material.dart';
import '../data/planification_repository.dart';
import 'plan_form_screen.dart';

const _statutColors = {
  'Planifié': Color(0xFF3B82F6),
  'En cours': Color(0xFFF59E0B),
  'Réalisé': Color(0xFF10B981),
  'En retard': Color(0xFFEF4444),
  'Reporté': Color(0xFF94A3B8),
};

class PlanificationScreen extends StatefulWidget {
  const PlanificationScreen({super.key});

  @override
  State<PlanificationScreen> createState() => _PlanificationScreenState();
}

class _PlanificationScreenState extends State<PlanificationScreen> {
  final _repo = PlanificationRepository();

  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatut = '';
  String _selectedType = '';
  final _searchCtr = TextEditingController();

  final _types = ['', 'Annuel', 'Mensuel', 'Hebdomadaire', 'Officiel'];
  final _statuts = [
    '',
    'Planifié',
    'En cours',
    'Réalisé',
    'En retard',
    'Reporté',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtr.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtr.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getPlanifications(
        statut: _selectedStatut.isEmpty ? null : _selectedStatut,
        typePlan: _selectedType.isEmpty ? null : _selectedType,
      );
      if (mounted) {
        setState(() {
          _plans = data;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilters() {
    final q = _searchCtr.text.toLowerCase().trim();
    setState(() {
      _filtered = _plans.where((p) {
        final chap = (p['chapitre'] ?? '').toString().toLowerCase();
        final lecon = (p['lecon_prevue'] ?? '').toString().toLowerCase();
        final cls = ((p['school_classes'] as Map?)?['class_name'] ?? '')
            .toString()
            .toLowerCase();
        final sub = ((p['school_subjects'] as Map?)?['subject_name'] ?? '')
            .toString()
            .toLowerCase();
        final matchQ = q.isEmpty ||
            chap.contains(q) ||
            lecon.contains(q) ||
            cls.contains(q) ||
            sub.contains(q);
        final matchS = _selectedStatut.isEmpty ||
            (p['statut'] ?? '') == _selectedStatut;
        final matchT = _selectedType.isEmpty ||
            (p['type_plan'] ?? '') == _selectedType;
        return matchQ && matchS && matchT;
      }).toList();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? plan}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlanFormScreen(existingPlan: plan),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> plan) async {
    if ((plan['statut'] ?? '') == 'Réalisé') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer un plan réalisé.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le plan ?'),
        content: Text(
          'Le plan "${plan['chapitre']}" sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repo.deletePlanification(plan['id'] as int);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plan supprimé.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Stats summary
  Map<String, int> get _stats {
    final counts = <String, int>{};
    for (final p in _plans) {
      final s = p['statut'] as String? ?? 'Planifié';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        title: const Text(
          'Planification pédagogique',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouveau plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Stats row
          if (!_isLoading && _plans.isNotEmpty) _buildStatsRow(),

          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtr,
                  decoration: InputDecoration(
                    hintText: 'Rechercher chapitre, leçon...',
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropFilter(
                        'Type',
                        _types,
                        _selectedType,
                        (v) {
                          setState(() => _selectedType = v ?? '');
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropFilter(
                        'Statut',
                        _statuts,
                        _selectedStatut,
                        (v) {
                          setState(() => _selectedStatut = v ?? '');
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) =>
                                  _buildPlanCard(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _stats;
    return Container(
      color: const Color(0xFF0D9488),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _statChip('Total', _plans.length, Colors.white),
          const SizedBox(width: 8),
          _statChip('Réalisé', stats['Réalisé'] ?? 0, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _statChip('En retard', stats['En retard'] ?? 0, const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _statChip('Planifié', stats['Planifié'] ?? 0, const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropFilter(
    String hint,
    List<String> options,
    String current,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: options.map((o) {
        return DropdownMenuItem(
          value: o,
          child: Text(o.isEmpty ? 'Tous ($hint)' : o, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final statut = plan['statut'] as String? ?? 'Planifié';
    final color = _statutColors[statut] ?? const Color(0xFF94A3B8);
    final chapitre = plan['chapitre'] ?? '—';
    final lecon = plan['lecon_prevue'] ?? '—';
    final cls = (plan['school_classes'] as Map?)?['class_name'] ?? '—';
    final sub = (plan['school_subjects'] as Map?)?['subject_name'] ?? '—';
    final type = plan['type_plan'] ?? '—';
    final periode = plan['periode'] ?? '';
    final datePrevue = plan['date_prevue']?.toString().split('T').first ?? '';
    final canEdit = statut != 'Réalisé';
    final canDelete = statut != 'Réalisé';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_note,
                      color: Color(0xFF0D9488), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapitre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lecon,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statut,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Meta row
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _meta(Icons.class_, '$cls — $sub'),
                _meta(Icons.category, type),
                if (periode.isNotEmpty) _meta(Icons.date_range, periode),
                if (datePrevue.isNotEmpty) _meta(Icons.event, datePrevue),
              ],
            ),

            // Compétences
            if ((plan['competence_visee'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan['competence_visee'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canEdit)
                  _actionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Modifier',
                    color: const Color(0xFF0D9488),
                    onTap: () => _openForm(plan: plan),
                  ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    color: const Color(0xFFEF4444),
                    onTap: () => _confirmDelete(plan),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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
                  backgroundColor: const Color(0xFF0D9488)),
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
            Icon(Icons.event_note_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'Aucun plan trouvé',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre premier plan pédagogique.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
