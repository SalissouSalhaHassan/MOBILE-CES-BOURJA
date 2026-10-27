import 'package:flutter/material.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/family_repository.dart';

class FamilyHostelScreen extends StatefulWidget {
  const FamilyHostelScreen({super.key});

  @override
  State<FamilyHostelScreen> createState() => _FamilyHostelScreenState();
}

class _FamilyHostelScreenState extends State<FamilyHostelScreen> {
  final FamilyRepository _repository = locator<FamilyRepository>();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _allocation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final studentId =
          int.tryParse(await locator<SessionManager>().getStudentId() ?? '');
      if (studentId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Profil élève introuvable.";
        });
        return;
      }

      _allocation = await _repository.getHostelAllocation(
        studentId: studentId,
      );
    } catch (e) {
      _errorMessage = "Erreur de chargement: $e";
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _allocation?['hostel_rooms'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Hébergement & Internat'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _allocation == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.hotel_rounded,
                                  size: 40,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage ??
                                    'Aucune chambre d’internat attribuée pour le moment.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.slate500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Status card with gradient
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
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
                                  'INTERNAT ACTIF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Occupé',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              room?['building_name']?.toString() ?? 'Bâtiment',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Chambre N° ${room?['room_number']?.toString() ?? '-'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Details Card
                      _infoCard(
                        title: 'Détails de la chambre',
                        icon: Icons.meeting_room_rounded,
                        color: const Color(0xFFD97706),
                        lines: [
                          'Bâtiment: ${room?['building_name'] ?? '-'}',
                          'Numéro de chambre: ${room?['room_number'] ?? '-'}',
                          'Type de chambre: ${room?['room_type'] ?? 'Mixte'}',
                          'Capacité de la chambre: ${room?['capacity'] ?? '1'} personne(s)',
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Allocation Card
                      _infoCard(
                        title: 'Détails de l’affectation',
                        icon: Icons.assignment_ind_rounded,
                        color: const Color(0xFF2563EB),
                        lines: [
                          'Statut actuel: ${_allocation?['status'] ?? 'Occupé'}',
                          'Date d’entrée: ${_allocation?['join_date']?.toString().split('T').first ?? '-'}',
                          'Date de sortie: ${_allocation?['leave_date']?.toString().split('T').first ?? 'En cours'}',
                          'Frais par trimestre: ${room?['cost_per_term'] ?? '0'} FCFA',
                        ],
                      ),
                      if (_allocation?['remarks'] != null &&
                          _allocation?['remarks']?.toString().trim().isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _infoCard(
                          title: 'Remarques / Observations',
                          icon: Icons.notes_rounded,
                          color: const Color(0xFF7C3AED),
                          lines: [
                            _allocation?['remarks']?.toString() ?? '',
                          ],
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.slate900,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.slate700,
                    fontSize: 12,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
