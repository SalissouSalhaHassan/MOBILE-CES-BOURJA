import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/students_repository.dart';

class StudentPromotionScreen extends StatefulWidget {
  const StudentPromotionScreen({super.key});

  @override
  State<StudentPromotionScreen> createState() => _StudentPromotionScreenState();
}

class _StudentPromotionScreenState extends State<StudentPromotionScreen> {
  final StudentsRepository _repository = locator<StudentsRepository>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isPromoting = false;
  bool _isPreparingPreview = false;
  bool _transferBalance = true;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _history = [];
  final Set<int> _selectedIds = {};

  String _sourceClass = '';
  String _sourceSession = '';
  String _targetClass = '';
  String _targetSession = '';

  bool get _isTargetSessionFrozen {
    if (_targetSession.isEmpty) return false;
    return _repository.isSessionFrozen(sessionName: _targetSession);
  }

  bool get _isSourceSessionFrozen {
    if (_sourceSession.isEmpty) return false;
    return _repository.isSessionFrozen(sessionName: _sourceSession);
  }

  bool get _isPromotionBlocked => _isTargetSessionFrozen || _isSourceSessionFrozen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final students = await _repository.getStudentsList();
    final options = await _repository.getPromotionOptions();
    final history = await _repository.getPromotionHistory();

    if (!mounted) return;
    setState(() {
      _students = students;
      _classes = List<Map<String, dynamic>>.from(options['classes'] ?? []);
      _sessions = List<Map<String, dynamic>>.from(options['sessions'] ?? []);
      _history = history;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _students.where((student) {
      final name = (student['nom_etudiant'] ?? '').toString().toLowerCase();
      final admission =
          (student['num_admission'] ?? '').toString().toLowerCase();
      final className = (student['classe'] ?? '').toString();
      final sessionName = (student['session'] ?? '').toString();

      final matchesSearch =
          query.isEmpty || name.contains(query) || admission.contains(query);
      final matchesClass = _sourceClass.isEmpty || className == _sourceClass;
      final matchesSession =
          _sourceSession.isEmpty || sessionName == _sourceSession;

      return matchesSearch && matchesClass && matchesSession;
    }).toList();

    setState(() {
      _filteredStudents = filtered;
      _selectedIds.removeWhere(
        (id) => !_filteredStudents.any((student) => student['id'] == id),
      );
    });
  }

  List<Map<String, dynamic>> _selectedStudents() {
    return _filteredStudents
        .where((student) => _selectedIds.contains(student['id']))
        .toList();
  }

  Future<void> _openPreview() async {
    if (_isPromotionBlocked) {
      _showMessage("Promotion impossible : l'année scolaire sélectionnée est clôturée ou verrouillée.");
      return;
    }
    if (_selectedIds.isEmpty) {
      _showMessage('Selectionnez au moins un etudiant.');
      return;
    }
    if (_targetClass.isEmpty || _targetSession.isEmpty) {
      _showMessage('Selectionnez la classe et la session de destination.');
      return;
    }

    setState(() => _isPreparingPreview = true);
    final preview = await _repository.getPromotionPreview(
      students: _selectedStudents(),
      targetClass: _targetClass,
      targetSession: _targetSession,
    );
    if (!mounted) return;
    setState(() => _isPreparingPreview = false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final promotable = preview
            .where((row) => row['recommendation'] == 'Promouvoir')
            .length;
        final conditional = preview
            .where((row) => row['recommendation'] == 'Sous reserve')
            .length;
        final repeat = preview
            .where((row) => row['recommendation'] == 'Redoublement conseille')
            .length;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Apercu avant promotion',
                        style: AppTextStyles.heading2,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'Destination: $_targetClass - $_targetSession',
                  style: AppTextStyles.body.copyWith(color: AppColors.slate500),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _previewStat(
                        'Promouvoir',
                        '$promotable',
                        const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _previewStat(
                        'Sous reserve',
                        '$conditional',
                        const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _previewStat(
                        'A risque',
                        '$repeat',
                        const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: preview.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = preview[index];
                      final average =
                          (student['calculated_average'] as num?)?.toDouble();
                      final recommendation =
                          (student['recommendation'] ?? 'A verifier').toString();
                      final color = _recommendationColor(recommendation);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEBF0F5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (student['nom_etudiant'] ?? 'Etudiant')
                                        .toString(),
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${student['num_admission'] ?? '-'} - ${student['classe'] ?? '-'}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    average == null
                                        ? 'N/A'
                                        : '${average.toStringAsFixed(1)}/20',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    recommendation,
                                    style: AppTextStyles.caption.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isPromoting || _isPromotionBlocked
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _promote();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPromotionBlocked ? AppColors.slate400 : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(_isPromotionBlocked ? Icons.lock_rounded : Icons.arrow_upward_rounded),
                    label: Text(_isPromotionBlocked ? 'Promotion Verrouillée' : 'Confirmer la promotion'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promote() async {
    if (_isPromotionBlocked) {
      _showMessage("Impossible d'effectuer une promotion vers ou depuis une session clôturée.");
      return;
    }
    if (_selectedIds.isEmpty) {
      _showMessage('Selectionnez au moins un etudiant.');
      return;
    }
    if (_targetClass.isEmpty || _targetSession.isEmpty) {
      _showMessage('Selectionnez la classe et la session de destination.');
      return;
    }

    setState(() => _isPromoting = true);
    final result = await _repository.promoteStudents(
      studentIds: _selectedIds.toList(),
      targetClass: _targetClass,
      targetSession: _targetSession,
      transferBalance: _transferBalance,
    );

    if (!mounted) return;
    setState(() => _isPromoting = false);

    _showMessage(
      result['success'] == true
          ? (result['message']?.toString() ?? 'Promotion reussie.')
          : (result['error']?.toString() ?? 'Erreur promotion'),
    );

    if (result['success'] == true) {
      _selectedIds.clear();
      await _load();
    }
  }

  void _showHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historique des promotions', style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                if (_history.isEmpty)
                  Text(
                    'Aucune promotion enregistree pour le moment.',
                    style: AppTextStyles.body,
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final details = _decodeDetails(item['details']);
                        final count = details['students_count'] ?? 0;
                        final targetClass =
                            (details['target_class'] ?? '-').toString();
                        final targetSession =
                            (details['target_session'] ?? '-').toString();

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFEBF0F5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$count etudiants vers $targetClass',
                                style: AppTextStyles.bodyBold,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Session cible: $targetSession',
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Par ${(item['username'] ?? 'mobile').toString()}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _decodeDetails(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return {};
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _recommendationColor(String recommendation) {
    switch (recommendation) {
      case 'Promouvoir':
        return const Color(0xFF059669);
      case 'Sous reserve':
        return const Color(0xFFD97706);
      case 'Redoublement conseille':
        return const Color(0xFFDC2626);
      default:
        return AppColors.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _promotionStats();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Promotion des etudiants'),
        actions: [
          IconButton(
            onPressed: _showHistorySheet,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_isPromotionBlocked) ...[
                        _buildFreezeWarningBanner(),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        'Transferez les etudiants vers la classe superieure pour la nouvelle session.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _sourceCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _targetCard()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _statsBar(stats),
                      const SizedBox(height: 18),
                      _toolbar(),
                      const SizedBox(height: 14),
                      if (_filteredStudents.isEmpty)
                        _emptyState()
                      else
                        ..._filteredStudents.map(_studentTile),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFEBF0F5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} selectionnes',
                          style: AppTextStyles.bodyBold,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: (_isPreparingPreview || _isPromotionBlocked) ? null : _openPreview,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          foregroundColor: _isPromotionBlocked ? AppColors.slate400 : null,
                        ),
                        icon: Icon(_isPromotionBlocked ? Icons.lock_outline_rounded : Icons.visibility_outlined),
                        label: Text(
                          _isPromotionBlocked
                              ? 'Verrouillé'
                              : (_isPreparingPreview ? 'Preparation...' : 'Apercu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFreezeWarningBanner() {
    final reason = _isTargetSessionFrozen && _isSourceSessionFrozen
        ? 'Les années scolaires source et cible sont clôturées.'
        : _isTargetSessionFrozen
            ? 'L\'année scolaire cible "$_targetSession" est clôturée.'
            : 'L\'année scolaire source "$_sourceSession" est clôturée.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Promotion Verrouillée (Session Clôturée)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$reason Toute promotion est temporairement désactivée.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceCard() {
    return _configCard(
      title: 'Classe source',
      tint: const Color(0xFFFEF2F2),
      iconColor: const Color(0xFFDC2626),
      icon: Icons.arrow_back_rounded,
      children: [
        _dropdownString(
          label: 'Classe',
          value: _sourceClass,
          options: _classNames(),
          onChanged: (value) {
            setState(() => _sourceClass = value ?? '');
            _applyFilters();
          },
        ),
        const SizedBox(height: 10),
        _dropdownString(
          label: 'Session',
          value: _sourceSession,
          options: _sessionNames(),
          onChanged: (value) {
            setState(() => _sourceSession = value ?? '');
            _applyFilters();
          },
        ),
      ],
    );
  }

  Widget _targetCard() {
    return _configCard(
      title: 'Classe destination',
      tint: const Color(0xFFECFDF5),
      iconColor: const Color(0xFF059669),
      icon: Icons.arrow_forward_rounded,
      children: [
        _dropdownString(
          label: 'Classe',
          value: _targetClass,
          options: _classNames(),
          onChanged: (value) => setState(() => _targetClass = value ?? ''),
        ),
        const SizedBox(height: 10),
        _dropdownString(
          label: 'Session',
          value: _targetSession,
          options: _sessionNames(),
          onChanged: (value) => setState(() => _targetSession = value ?? ''),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _transferBalance,
          onChanged: (value) => setState(() => _transferBalance = value),
          title: const Text('Transferer le solde'),
        ),
      ],
    );
  }

  Widget _configCard({
    required String title,
    required Color tint,
    required Color iconColor,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.heading3)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _statsBar(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Row(
        children: [
          Expanded(child: _miniStat('Effectif', '${stats['total'] ?? 0}')),
          Expanded(
            child: _miniStat(
              'Eligibles',
              '${stats['promotable'] ?? 0}',
            ),
          ),
          Expanded(
            child: _miniStat(
              'A risque',
              '${stats['repeat'] ?? 0}',
            ),
          ),
          Expanded(
            child: _miniStat(
              'Destination',
              _targetClass.isEmpty ? '-' : _targetClass,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.heading3),
      ],
    );
  }

  Widget _toolbar() {
    final allSelected = _filteredStudents.isNotEmpty &&
        _selectedIds.length == _filteredStudents.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Rechercher un etudiant',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (_) {
                  setState(() {
                    if (allSelected) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds
                        ..clear()
                        ..addAll(
                          _filteredStudents
                              .map((student) => student['id'] as int),
                        );
                    }
                  });
                },
              ),
              const Text('Tout selectionner'),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _selectedIds.clear());
                },
                child: const Text('Tout deselectionner'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentTile(Map<String, dynamic> student) {
    final studentId = student['id'] as int;
    final selected = _selectedIds.contains(studentId);
    final recommendation = _recommendationFromStudent(student);
    final color = _recommendationColor(recommendation);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _selectedIds.remove(studentId);
            } else {
              _selectedIds.add(studentId);
            }
          });
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFEBF0F5),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(studentId);
                    } else {
                      _selectedIds.add(studentId);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (student['nom_etudiant'] ?? 'Etudiant').toString(),
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student['num_admission'] ?? '-'} - ${student['classe'] ?? '-'}',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommendation,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill((student['statut'] ?? 'Actif').toString()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final active = status.toLowerCase().contains('actif');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: active ? const Color(0xFF059669) : const Color(0xFFDC2626),
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _dropdownString({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final all = [''] + options;
    return DropdownButtonFormField<String>(
      initialValue: all.contains(value) ? value : '',
      items: all
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item.isEmpty ? 'Selectionner' : item),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
        ),
      ),
    );
  }

  Widget _previewStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, size: 44, color: AppColors.slate500),
          const SizedBox(height: 12),
          Text('Aucun etudiant trouve', style: AppTextStyles.heading3),
        ],
      ),
    );
  }

  Map<String, int> _promotionStats() {
    var promotable = 0;
    var reserve = 0;
    var repeat = 0;

    for (final student in _filteredStudents) {
      final recommendation = _recommendationFromStudent(student);
      if (recommendation == 'Promouvoir') {
        promotable++;
      } else if (recommendation == 'Sous reserve') {
        reserve++;
      } else if (recommendation == 'Redoublement conseille') {
        repeat++;
      }
    }

    return {
      'total': _filteredStudents.length,
      'promotable': promotable,
      'reserve': reserve,
      'repeat': repeat,
    };
  }

  String _recommendationFromStudent(Map<String, dynamic> student) {
    final behavior = (student['behavior_score'] as num?)?.toDouble();
    if (behavior == null) {
      return 'A verifier';
    }
    if (behavior >= 10) {
      return 'Promouvoir';
    }
    if (behavior >= 8) {
      return 'Sous reserve';
    }
    return 'Redoublement conseille';
  }

  List<String> _classNames() {
    return _classes
        .map((row) => row['class_name']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _sessionNames() {
    return _sessions
        .map((row) => row['session_name']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }
}
