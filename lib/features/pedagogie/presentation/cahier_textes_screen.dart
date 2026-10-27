import 'package:flutter/material.dart';
import '../data/pedagogie_repository.dart';
import 'seance_form_screen.dart';
import 'inspection_dialog.dart';
import '../../academics/presentation/ai_timetable_generator_sheet.dart';

/// Statuts with colors
const _statutColors = {
  'Brouillon': Color(0xFF94A3B8),
  'Soumis': Color(0xFF3B82F6),
  'Validé': Color(0xFF10B981),
  'Rejeté': Color(0xFFEF4444),
  'En attente': Color(0xFFF59E0B),
};

class CahierTextesScreen extends StatefulWidget {
  const CahierTextesScreen({super.key});

  @override
  State<CahierTextesScreen> createState() => _CahierTextesScreenState();
}

class _CahierTextesScreenState extends State<CahierTextesScreen> {
  final _repo = PedagogieRepository();

  List<Map<String, dynamic>> _seances = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _selectedStatut = '';
  final _searchCtr = TextEditingController();

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
      final data = await _repo.getSeances(
        statut: _selectedStatut.isEmpty ? null : _selectedStatut,
      );
      if (mounted) {
        setState(() {
          _seances = data;
          _isLoading = false;
        });
        _applyFilters();
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

  void _applyFilters() {
    final q = _searchCtr.text.toLowerCase().trim();
    setState(() {
      _filtered = _seances.where((s) {
        final titre = (s['titre_lecon'] ?? '').toString().toLowerCase();
        final cls =
            ((s['school_classes'] as Map?)?['class_name'] ?? '').toString().toLowerCase();
        final sub =
            ((s['school_subjects'] as Map?)?['subject_name'] ?? '').toString().toLowerCase();
        final matchesSearch =
            q.isEmpty || titre.contains(q) || cls.contains(q) || sub.contains(q);
        final matchesStatut = _selectedStatut.isEmpty ||
            (s['statut'] ?? '') == _selectedStatut;
        return matchesSearch && matchesStatut;
      }).toList();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? seance}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeanceFormScreen(existingSeance: seance),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> seance) async {
    final statut = seance['statut'] ?? '';
    if (statut == 'Validé') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer une séance validée.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la séance ?'),
        content: Text(
          'La séance "${seance['titre_lecon']}" sera supprimée définitivement.',
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
        await _repo.deleteSeance(seance['id'] as int);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Séance supprimée.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitSeance(Map<String, dynamic> seance) async {
    try {
      await _repo.submitSeance(seance['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Séance soumise pour validation.'),
            backgroundColor: Color(0xFF3B82F6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        title: const Text(
          'Cahier de textes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => AiTimetableGeneratorSheet.show(context),
            tooltip: 'Générateur IA d\'Emploi du Temps 📅',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF6D28D9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouvelle séance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Filters bar ───────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchCtr,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une séance...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                // Statut chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Tous', ''),
                      const SizedBox(width: 8),
                      ...[
                        'Brouillon',
                        'Soumis',
                        'Validé',
                        'Rejeté',
                        'En attente',
                      ].map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _filterChip(s, s),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
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
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) =>
                                  _buildSeanceCard(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _selectedStatut == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedStatut = value);
        _applyFilters();
      },
      selectedColor: const Color(0xFF6D28D9).withAlpha(30),
      checkmarkColor: const Color(0xFF6D28D9),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF6D28D9) : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected
            ? const Color(0xFF6D28D9)
            : Colors.grey.withAlpha(70),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSeanceCard(Map<String, dynamic> seance) {
    final statut = seance['statut'] ?? 'Brouillon';
    final statutColor =
        _statutColors[statut] ?? const Color(0xFF94A3B8);
    final titre = seance['titre_lecon'] ?? '—';
    final cls =
        (seance['school_classes'] as Map?)?['class_name'] ?? '—';
    final sub =
        (seance['school_subjects'] as Map?)?['subject_name'] ?? '—';
    final date = seance['session_date']?.toString().split('T').first ?? '—';
    final heureDebut = seance['heure_debut'] ?? '';
    final heureFin = seance['heure_fin'] ?? '';
    final horaire = heureDebut.isNotEmpty
        ? '$heureDebut${heureFin.isNotEmpty ? ' → $heureFin' : ''}'
        : '';

    final canEdit = statut == 'Brouillon' || statut == 'Rejeté';
    final canSubmit = statut == 'Brouillon';
    final canDelete = statut != 'Validé';

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
      child: InkWell(
        onTap: canEdit ? () => _openForm(seance: seance) : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D28D9).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      color: Color(0xFF6D28D9),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$cls — $sub',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Statut badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statut,
                      style: TextStyle(
                        color: statutColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Date & Horaire row
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  if (horaire.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.access_time,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      horaire,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),

              // Preview contenu
              if ((seance['contenu_realise'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  seance['contenu_realise'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],

              // Action buttons
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionBtn(
                    icon: Icons.rate_review_rounded,
                    label: 'Viser / Inspecter',
                    color: const Color(0xFF0F766E),
                    onTap: () => InspectionDialog.show(context, seance: seance, onValidated: _load),
                  ),
                  if (canSubmit) ...[
                    const SizedBox(width: 8),
                    _actionBtn(
                      icon: Icons.send,
                      label: 'Soumettre',
                      color: const Color(0xFF3B82F6),
                      onTap: () => _submitSeance(seance),
                    ),
                  ],
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    _actionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Modifier',
                      color: const Color(0xFF6D28D9),
                      onTap: () => _openForm(seance: seance),
                    ),
                  ],
                  if (canDelete) ...[
                    const SizedBox(width: 8),
                    _actionBtn(
                      icon: Icons.delete_outline,
                      label: 'Supprimer',
                      color: const Color(0xFFEF4444),
                      onTap: () => _confirmDelete(seance),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
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
            Text(
              'Erreur de chargement',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9)),
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
            Icon(Icons.menu_book_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              _selectedStatut.isNotEmpty || _searchCtr.text.isNotEmpty
                  ? 'Aucune séance trouvée'
                  : 'Aucune séance enregistrée',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatut.isNotEmpty || _searchCtr.text.isNotEmpty
                  ? 'Essayez de modifier les filtres.'
                  : 'Créez votre première séance avec le bouton ci-dessous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
