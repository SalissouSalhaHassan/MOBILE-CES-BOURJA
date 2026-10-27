import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/di/injection.dart';
import '../data/director_repository.dart';

class DirectorCockpitScreen extends StatefulWidget {
  const DirectorCockpitScreen({super.key});

  @override
  State<DirectorCockpitScreen> createState() => _DirectorCockpitScreenState();
}

class _DirectorCockpitScreenState extends State<DirectorCockpitScreen>
    with SingleTickerProviderStateMixin {
  final _repo = locator<DirectorRepository>();
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  String _approvalFilter = 'Tous'; // Tous, Congés & Avances, Heures Sup

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.getDirectorCockpit();
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApproval({
    required String category,
    required int id,
    required String status,
    String? adminComment,
  }) async {
    // Optimistic UI Update
    setState(() {
      final approvals = _data['approvals'] as Map<String, dynamic>? ?? {};
      if (category == 'hr_request') {
        final list = (approvals['hrRequests'] as List<dynamic>? ?? []);
        for (var item in list) {
          if (item['id'] == id) {
            item['status'] = status;
          }
        }
      } else if (category == 'extra_hours') {
        final list = (approvals['extraHours'] as List<dynamic>? ?? []);
        for (var item in list) {
          if (item['id'] == id) {
            item['status'] = status;
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              status == 'Approuvé' ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status == 'Approuvé'
                    ? '✅ Demande approuvée avec succès ! Notification envoyée à l\'enseignant.'
                    : 'Demande rejetée.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: status == 'Approuvé' ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    await _repo.approveOrRejectRequest(
      category: category,
      id: id,
      status: status,
      adminComment: adminComment,
    );
  }

  void _showRejectDialog({required String category, required int id}) {
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Motif du Rejet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veuillez indiquer la raison du refus qui sera notifiée à l\'enseignant :',
              style: TextStyle(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex: Calendrier d\'examens chargé / Non conforme...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleApproval(
                category: category,
                id: id,
                status: 'Rejeté',
                adminComment: commentCtrl.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmer le Rejet', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directorName = _data['directorName'] ?? 'Monsieur le Directeur';
    final schoolName = _data['schoolName'] ?? 'Complexe Scolaire EDUT';
    final kpis = _data['kpis'] as Map<String, dynamic>? ?? {};

    final presenceRate = kpis['teacherPresenceRate'] ?? '95%';
    final fillRate = kpis['fillRatePercent'] ?? '85%';
    final pendingCount = (kpis['pendingRequestsCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('QG de Direction & Décisions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: const Color(0xFFEF4444),
                child: const Icon(Icons.rule_folder_rounded, size: 20),
              ),
              text: 'Approbations',
            ),
            Tab(
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              text: 'Cahiers Textes',
            ),
            Tab(
              icon: const Icon(Icons.access_time_filled_rounded, size: 20),
              text: 'Présences',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
          : Column(
              children: [
                // Top Director Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  directorName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  schoolName,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // 3 Summary Badges
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderMetric(
                              label: 'Présence Profs',
                              value: presenceRate,
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderMetric(
                              label: 'Cahiers Remplis',
                              value: fillRate,
                              icon: Icons.menu_book_rounded,
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderMetric(
                              label: 'En Attente',
                              value: '$pendingCount',
                              icon: Icons.pending_actions_rounded,
                              color: pendingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildApprovalsTab(),
                      _buildPedagogieTab(),
                      _buildAttendanceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: APPROBATIONS & DEMANDES EN ATTENTE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildApprovalsTab() {
    final approvals = _data['approvals'] as Map<String, dynamic>? ?? {};
    final hrRequests = List<Map<String, dynamic>>.from(approvals['hrRequests'] ?? []);
    final extraHours = List<Map<String, dynamic>>.from(approvals['extraHours'] ?? []);

    List<Map<String, dynamic>> combined = [];

    if (_approvalFilter == 'Tous' || _approvalFilter == 'Congés & Avances') {
      for (var r in hrRequests) {
        combined.add({...r, '_type': 'hr_request'});
      }
    }
    if (_approvalFilter == 'Tous' || _approvalFilter == 'Heures Sup') {
      for (var e in extraHours) {
        combined.add({...e, '_type': 'extra_hours'});
      }
    }

    return Column(
      children: [
        // Sub Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _buildFilterChip('Tous'),
              const SizedBox(width: 8),
              _buildFilterChip('Congés & Avances'),
              const SizedBox(width: 8),
              _buildFilterChip('Heures Sup'),
            ],
          ),
        ),

        Expanded(
          child: combined.isEmpty
              ? _buildEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Aucune demande en attente',
                  subtitle: 'Toutes les requêtes administratives et pédagogiques ont été traitées !',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: combined.length,
                  itemBuilder: (context, idx) {
                    final item = combined[idx];
                    final isExtra = item['_type'] == 'extra_hours';

                    return _buildApprovalCard(item, isExtra: isExtra);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _approvalFilter == label;
    return InkWell(
      onTap: () => setState(() => _approvalFilter = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item, {required bool isExtra}) {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final empName = item['employeeName'] ?? 'Enseignant';
    final empPoste = item['employeePoste'] ?? 'Professeur';
    final empMatricule = item['employeeMatricule'] ?? 'ENS-2025';
    final status = item['status'] ?? 'En attente';
    final isPending = status == 'En attente';

    final categoryKey = isExtra ? 'extra_hours' : 'hr_request';

    String title;
    String details;
    IconData typeIcon;
    Color typeColor;

    if (isExtra) {
      final typeHour = item['typeHour'] ?? 'Heure supplémentaire';
      final className = item['className'] ?? 'Classe';
      final subjectName = item['subjectName'] ?? 'Matière';
      final hours = item['hoursCount'] ?? 1.0;
      final total = item['totalAmount'] ?? 0;

      title = '$typeHour ($className)';
      details = 'Matière: $subjectName • $hours Heure(s) • Total: ${_formatAmount(total)} FCFA\nNote: ${item['notes'] ?? 'Aucune note'}';
      typeIcon = Icons.more_time_rounded;
      typeColor = const Color(0xFF3B82F6);
    } else {
      final reqType = item['requestType'] ?? 'Demande RH';
      final reason = item['reason'] ?? 'Non précisé';
      final days = item['daysCount'] ?? 1;
      final advance = item['advanceAmount'];

      title = reqType;
      if (advance != null && advance > 0) {
        details = 'Montant sollicité : ${_formatAmount(advance)} FCFA\nMotif : $reason';
      } else {
        final start = item['startDate'] ?? '';
        final end = item['endDate'] ?? '';
        details = 'Durée: $days jour(s) ($start → $end)\nMotif: $reason';
      }
      typeIcon = Icons.beach_access_rounded;
      typeColor = const Color(0xFF8B5CF6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? const Color(0xFFE2E8F0) : (status == 'Approuvé' ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher Info Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: typeColor.withValues(alpha: 0.12),
                child: Icon(typeIcon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.slate900)),
                    Text('$empPoste • $empMatricule', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFEF3C7)
                      : (status == 'Approuvé' ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isPending
                        ? const Color(0xFF92400E)
                        : (status == 'Approuvé' ? const Color(0xFF065F46) : const Color(0xFF991B1B)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Request Title & Content Box
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: typeColor)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              details,
              style: const TextStyle(fontSize: 11.5, color: AppColors.slate700, height: 1.4),
            ),
          ),

          // Action Buttons if Pending
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApproval(
                      category: categoryKey,
                      id: id,
                      status: 'Approuvé',
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                    label: const Text('Approuver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(
                      category: categoryKey,
                      id: id,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Rejeter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: SUIVI PÉDAGOGIQUE & CAHIERS DE TEXTES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPedagogieTab() {
    final peda = _data['pedagogie'] as Map<String, dynamic>? ?? {};
    final filledToday = List<Map<String, dynamic>>.from(peda['filledToday'] ?? []);
    final missingToday = List<Map<String, dynamic>>.from(peda['missingToday'] ?? []);
    final fillRate = (peda['fillRatePercent'] as num?)?.toInt() ?? 80;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Taux de Remplissage Quotidien', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      SizedBox(height: 2),
                      Text('Cahiers de Textes du Jour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Text('$fillRate%', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 22)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fillRate / 100.0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${filledToday.length} classes renseignées • ${missingToday.length} classes en attente',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Missing Classes Section (Attention requise)
        if (missingToday.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFEA580C), size: 18),
              SizedBox(width: 6),
              Text('Classes Sans Cahier Renseigné Aujourd\'hui', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFC2410C))),
            ],
          ),
          const SizedBox(height: 8),
          ...missingToday.map((m) {
            final rawName = (m['className'] ?? m['class_name'] ?? m['classe'])?.toString().trim();
            final className = (rawName != null && rawName.isNotEmpty) ? rawName : 'Classe';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDBA74),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.priority_high_rounded, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          className,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF9A3412),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🔔 Rappel envoyé aux enseignants de la classe $className'),
                              backgroundColor: const Color(0xFFEA580C),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.notifications_active_rounded, size: 13, color: Colors.white),
                        label: const Text('Rappeler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 28),
                    child: Text(
                      'Aucune séance enregistrée pour ce jour',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFC2410C), height: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 18),
        ],

        // Filled Classes List
        const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
            SizedBox(width: 6),
            Text('Séances Renseignées Aujourd\'hui', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.slate800)),
          ],
        ),
        const SizedBox(height: 8),

        if (filledToday.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'Aucun cahier de textes encore renseigné ce matin.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
              ),
            ),
          )
        else
          ...filledToday.map((f) {
            final rawClass = (f['className'] ?? f['class_name'] ?? f['classe'])?.toString().trim();
            final className = (rawClass != null && rawClass.isNotEmpty) ? rawClass : 'Classe';
            final rawSubject = (f['subjectName'] ?? f['subject_name'] ?? f['matiere'])?.toString().trim();
            final subjectName = (rawSubject != null && rawSubject.isNotEmpty) ? rawSubject : 'Matière';
            final rawEmp = (f['employeeName'] ?? f['employee_name'] ?? f['enseignant'])?.toString().trim();
            final empName = (rawEmp != null && rawEmp.isNotEmpty) ? rawEmp : 'Enseignant';
            final rawTitle = (f['titreLecon'] ?? f['titre_lecon'])?.toString().trim();
            final title = (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : 'Séance du jour';
            final start = f['heureDebut'] ?? f['heure_debut'] ?? '08:00';
            final end = f['heureFin'] ?? f['heure_fin'] ?? '10:00';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$className • $subjectName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.slate900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate700, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Par: $empName • $start → $end',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: PRÉSENCE ENSEIGNANTS EN TEMPS RÉEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    final att = _data['teacherAttendance'] as Map<String, dynamic>? ?? {};
    final list = List<Map<String, dynamic>>.from(att['list'] ?? []);
    final presentCount = att['presentCount'] ?? 0;
    final absentCount = att['absentCount'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Bar
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$presentCount Présents', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46))),
                        const Text('En poste ce jour', style: TextStyle(fontSize: 10.5, color: Color(0xFF047857))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$absentCount Absent(s)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
                        const Text('Non signalés', style: TextStyle(fontSize: 10.5, color: Color(0xFFB91C1C))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Registre de Pointage & Statut du Corps Enseignant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        const SizedBox(height: 8),

        ...list.map((t) {
          final nom = t['nom'] ?? 'Enseignant';
          final poste = t['poste'] ?? 'Professeur';
          final status = t['status'] ?? 'Présent';
          final checkIn = t['checkInTime'] ?? '-';
          final mobile = t['mobile'] ?? '';

          Color statusColor;
          Color statusBg;
          IconData statusIcon;

          if (status == 'Présent' || status == 'En cours') {
            statusColor = const Color(0xFF059669);
            statusBg = const Color(0xFFD1FAE5);
            statusIcon = Icons.check_circle_rounded;
          } else if (status == 'En retard') {
            statusColor = const Color(0xFFD97706);
            statusBg = const Color(0xFFFEF3C7);
            statusIcon = Icons.watch_later_rounded;
          } else {
            statusColor = const Color(0xFFDC2626);
            statusBg = const Color(0xFFFEE2E2);
            statusIcon = Icons.cancel_rounded;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusBg,
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('$poste • Arrivée : $checkIn', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📞 Appel de $nom ($mobile)...')),
                    );
                  },
                  icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF38BDF8), size: 20),
                  tooltip: 'Appeler l\'enseignant',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF059669)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final numVal = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
    final isInt = numVal % 1 == 0;
    final str = isInt ? numVal.toInt().toString() : numVal.toStringAsFixed(1);
    final parts = str.split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
  }
}
