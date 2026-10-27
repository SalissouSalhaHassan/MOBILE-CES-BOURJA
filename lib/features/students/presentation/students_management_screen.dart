import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/widgets/connectivity_widgets.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/students_repository.dart';

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() =>
      _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  final StudentsRepository _repository = locator<StudentsRepository>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isGridView = true;
  bool _canCreateStudents = false;
  bool _canPromoteStudents = false;
  String _statusFilter = 'Tous';
  String _levelFilter = 'Tous';
  String _classFilter = 'Tous';
  String _sectionFilter = 'Tous';
  bool _isSessionFrozen = false;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    final isFrozen = _repository.isSessionFrozen();
    setState(() {
      _isLoading = true;
      _canCreateStudents =
          profile.permissions.contains(AppPermissions.studentsCreate);
      _canPromoteStudents =
          profile.permissions.contains(AppPermissions.studentsPromote);
      _isSessionFrozen = isFrozen;
    });

    final students = await _repository.getStudentsList();

    if (!mounted) return;
    setState(() {
      _students = students;
      _recomputeMetadata();
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
      final className = (student['classe'] ?? '').toString().toLowerCase();
      final level =
          (student['educational_level'] ?? '').toString().toLowerCase();
      final section = (student['section'] ?? '').toString().toLowerCase();
      final status = (student['statut'] ?? 'Actif').toString().toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          admission.contains(query) ||
          className.contains(query);

      final normalizedFilter = _statusFilter.toLowerCase();
      final matchesStatus = normalizedFilter == 'tous' ||
          status == normalizedFilter ||
          (normalizedFilter == 'actif' && status.contains('actif')) ||
          (normalizedFilter == 'inactif' && status.contains('inactif')) ||
          (normalizedFilter == 'en attente' && status.contains('attente'));

      final matchesLevel = _levelFilter == 'Tous' ||
          level == _levelFilter.toLowerCase();
      final matchesClass = _classFilter == 'Tous' ||
          className == _classFilter.toLowerCase();
      final matchesSection = _sectionFilter == 'Tous' ||
          section == _sectionFilter.toLowerCase();

      return matchesSearch &&
          matchesStatus &&
          matchesLevel &&
          matchesClass &&
          matchesSection;
    }).toList();

    setState(() {
      _filteredStudents = filtered;
    });
  }

  int _activeCount = 0;
  int _classesCount = 0;
  List<String> _levels = ['Tous'];
  List<String> _classes = ['Tous'];
  List<String> _sections = ['Tous'];

  void _recomputeMetadata() {
    _activeCount = _students
        .where((student) =>
            (student['statut'] ?? '').toString().toUpperCase().contains('ACTIF'))
        .length;

    _classesCount = _students
        .map((student) => student['classe']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;

    _levels = [
      'Tous',
      ..._students
          .map((student) => student['educational_level']?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];

    _classes = [
      'Tous',
      ..._students
          .map((student) => student['classe']?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];

    _sections = [
      'Tous',
      ..._students
          .map((student) => student['section']?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
  }

  int get _newThisMonthCount {
    final now = DateTime.now();
    return _students.where((student) {
      final raw = student['created_at']?.toString();
      if (raw == null || raw.isEmpty) return false;
      final createdAt = DateTime.tryParse(raw);
      if (createdAt == null) return false;
      return createdAt.month == now.month && createdAt.year == now.year;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _canCreateStudents && !_isSessionFrozen
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push('/students/form');
                if (!mounted) return;
                if (created == true) {
                  _loadStudents();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Liste des etudiants mise a jour.'),
                    ),
                  );
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Ajouter'),
            )
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text('Gestion des etudiants'),
        actions: [
          if (_canPromoteStudents)
            IconButton(
              onPressed: () => context.push('/students/promotion'),
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: 'Promotion',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudents,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Consultez et suivez les informations des etudiants.',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ),
                              const CacheStatusChip(),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (_isSessionFrozen) ...[
                            _buildFreezeWarningBanner(),
                            const SizedBox(height: 14),
                          ],
                          _buildStats(),
                          const SizedBox(height: 18),
                          _buildSearchAndActions(),
                          const SizedBox(height: 12),
                          _buildAcademicFilters(),
                          const SizedBox(height: 12),
                          _buildStatusFilters(),
                          const SizedBox(height: 16),
                          Text(
                            '${_filteredStudents.length} etudiants affiches',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_filteredStudents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: _buildStudentsSliver(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildFreezeWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, color: Color(0xFFB45309), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Année scolaire clôturée ou verrouillée : Mode consultation seule. Les inscriptions et modifications d'élèves sont gelées.",
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Total',
          value: _students.length.toString(),
          subtitle: 'Tous les etudiants',
          color: const Color(0xFFEEF2FF),
          icon: Icons.groups_rounded,
          iconColor: const Color(0xFF4F46E5),
        ),
        _buildStatCard(
          title: 'Actifs',
          value: _activeCount.toString(),
          subtitle: 'Statut actif',
          color: const Color(0xFFECFDF5),
          icon: Icons.verified_user_rounded,
          iconColor: const Color(0xFF059669),
        ),
        _buildStatCard(
          title: 'Nouveaux',
          value: _newThisMonthCount.toString(),
          subtitle: 'Ce mois',
          color: const Color(0xFFFFF7ED),
          icon: Icons.person_add_alt_1_rounded,
          iconColor: const Color(0xFFEA580C),
        ),
        _buildStatCard(
          title: 'Classes',
          value: _classesCount.toString(),
          subtitle: 'Niveaux et classes',
          color: const Color(0xFFEFF6FF),
          icon: Icons.class_rounded,
          iconColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.heading2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, admission ou classe',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEBF0F5)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _isGridView = true),
                icon: Icon(
                  Icons.grid_view_rounded,
                  color: _isGridView ? AppColors.primary : AppColors.slate400,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isGridView = false),
                icon: Icon(
                  Icons.view_list_rounded,
                  color: !_isGridView ? AppColors.primary : AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    const filters = ['Tous', 'Actif', 'En attente', 'Inactif'];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _statusFilter == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _statusFilter = filter;
              });
              _applyFilters();
            },
            selectedColor: AppColors.primary.withAlpha(24),
            labelStyle: TextStyle(
              color: selected ? AppColors.primary : AppColors.slate600,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFEBF0F5)),
            ),
            backgroundColor: Colors.white,
          );
        },
      ),
    );
  }

  Widget _buildAcademicFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _filterDropdown(
                label: 'Niveau',
                value: _levelFilter,
                items: _levels,
                onChanged: (value) {
                  setState(() => _levelFilter = value ?? 'Tous');
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _filterDropdown(
                label: 'Classe',
                value: _classFilter,
                items: _classes,
                onChanged: (value) {
                  setState(() => _classFilter = value ?? 'Tous');
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _filterDropdown(
          label: 'Section',
          value: _sectionFilter,
          items: _sections,
          onChanged: (value) {
            setState(() => _sectionFilter = value ?? 'Tous');
            _applyFilters();
          },
        ),
      ],
    );
  }

  Widget _buildStudentsSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _isGridView
              ? _buildStudentCard(_filteredStudents[index])
              : _buildStudentRow(_filteredStudents[index]),
        ),
        childCount: _filteredStudents.length,
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return InkWell(
      onTap: () async {
        final studentId = student['id'] as int?;
        if (studentId != null) {
          await context.push('/students/details', extra: studentId);
          _loadStudents();
        }
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Row(
        children: [
          _buildAvatar(student),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (student['nom_etudiant'] ?? 'Etudiant').toString(),
                  style: AppTextStyles.heading3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${(student['num_admission'] ?? '-').toString()}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _metaText(student['educational_level'] ?? 'Niveau'),
                    _metaText(student['classe'] ?? 'Classe'),
                    _metaText(student['section'] ?? 'Section'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _metaText(student['mobile'] ?? '-'),
                    _metaText(student['nom_pere'] ?? '-'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildStatusBadge((student['statut'] ?? 'Actif').toString()),
        ],
      ),
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student) {
    return InkWell(
      onTap: () async {
        final studentId = student['id'] as int?;
        if (studentId != null) {
          await context.push('/students/details', extra: studentId);
          _loadStudents();
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Row(
        children: [
          _buildAvatar(student),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (student['nom_etudiant'] ?? 'Etudiant').toString(),
                        style: AppTextStyles.bodyBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusBadge((student['statut'] ?? 'Actif').toString()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${student['num_admission'] ?? '-'} • ${student['classe'] ?? '-'}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${student['educational_level'] ?? '-'} • ${student['mobile'] ?? '-'}',
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

  Widget _buildAvatar(Map<String, dynamic> student) {
    final rawPath = (student['photo_path'] ??
            student['photo_url'] ??
            student['photo'] ??
            student['avatar'])
        ?.toString();

    Widget fallbackIcon() => const Icon(
          Icons.person_rounded,
          color: Color(0xFF818CF8),
          size: 28,
        );

    if (rawPath == null || rawPath.trim().isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: fallbackIcon(),
      );
    }

    final trimmed = rawPath.trim();

    Widget imageWidget;
    if (trimmed.startsWith('data:image')) {
      try {
        final base64String = trimmed.split(',').last;
        imageWidget = Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackIcon(),
        );
      } catch (_) {
        imageWidget = fallbackIcon();
      }
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      imageWidget = Image.network(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallbackIcon(),
      );
    } else if (trimmed.startsWith('/')) {
      final fullUrl = '${MobileApiConfig.baseUrl}$trimmed';
      imageWidget = Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallbackIcon(),
      );
    } else {
      final fullUrl = '${MobileApiConfig.baseUrl}/$trimmed';
      imageWidget = Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallbackIcon(),
      );
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.toUpperCase();
    Color bgColor;
    Color textColor;
    String label;

    if (normalized.contains('ACTIF')) {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF059669);
      label = 'ACTIF';
    } else if (normalized.contains('ATTENTE')) {
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFD97706);
      label = 'EN ATTENTE';
    } else {
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFDC2626);
      label = 'INACTIF';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _metaText(dynamic value) {
    final text = value?.toString().trim();
    return Text(
      text == null || text.isEmpty ? '-' : text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.slate600,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildEmptyState() {
    final isOnline = locator.isRegistered<SyncEngine>()
        ? locator<SyncEngine>().isOnlineNotifier.value
        : true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !isOnline ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                !isOnline ? Icons.wifi_off_rounded : Icons.school_rounded,
                size: 48,
                color: !isOnline ? const Color(0xFFD97706) : AppColors.slate400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              !isOnline && _students.isEmpty
                  ? 'Aucune donnée hors-ligne'
                  : 'Aucun etudiant trouve',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              !isOnline && _students.isEmpty
                  ? 'Les données de cet établissement n\'ont pas encore été téléchargées localement.\nConnectez-vous à Internet une première fois pour synchroniser le catalogue des élèves.'
                  : 'Modifiez vos critères de recherche ou réinitialisez les filtres.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.slate500,
                height: 1.4,
              ),
            ),
            if (!isOnline && _students.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadStudents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer la lecture locale'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
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
}
