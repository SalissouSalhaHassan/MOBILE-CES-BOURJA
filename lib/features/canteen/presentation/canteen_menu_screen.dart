import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/canteen_repository.dart';

class CanteenMenuScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String? matricule;

  const CanteenMenuScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.matricule,
  });

  @override
  State<CanteenMenuScreen> createState() => _CanteenMenuScreenState();
}

class _CanteenMenuScreenState extends State<CanteenMenuScreen> {
  final CanteenRepository _repo = CanteenRepository();

  bool _isLoading = true;
  List<dynamic> _weeklyMenu = [];
  int _selectedDayIndex = 0;
  bool _showQrBadge = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    final res = await _repo.getWeeklyMenu();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _weeklyMenu = (res?['weeklyMenu'] as List<dynamic>?) ?? [];
      });
    }
  }

  Future<void> _preorderMeal(Map<String, dynamic> menu) async {
    final day = menu['dayOfWeek'] ?? 'Aujourd\'hui';
    final mainDish = menu['mainDish'] ?? 'Repas complet';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la commande'),
        content: Text('Voulez-vous réserver le repas du $day ($mainDish) pour 1 200 FCFA ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirmer (1 200 FCFA)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repo.preorderMeal(
        studentId: widget.studentId,
        mealDate: menu['weekStartDate'] ?? DateTime.now().toIso8601String().split('T')[0],
        menuDescription: '$mainDish (${menu['starterDish'] ?? ''} + ${menu['dessert'] ?? ''})',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ Repas réservé avec succès !' : 'Erreur lors de la réservation (Solde insuffisant).'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeMenu = _weeklyMenu.isNotEmpty && _selectedDayIndex < _weeklyMenu.length
        ? _weeklyMenu[_selectedDayIndex]
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Menu & Restauration',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_showQrBadge ? Icons.restaurant_menu_rounded : Icons.qr_code_2_rounded),
            tooltip: _showQrBadge ? 'Voir le menu' : 'Afficher mon QR de paiement',
            onPressed: () => setState(() => _showQrBadge = !_showQrBadge),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _showQrBadge
              ? _buildQrBadgeView()
              : _buildMenuView(activeMenu),
    );
  }

  Widget _buildQrBadgeView() {
    final qrData = 'EDUT-CANTEEN:${widget.studentId}:${widget.matricule ?? widget.studentName}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.contactless_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'PASS RESTAURATION SANS CONTACT',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.studentName,
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              if (widget.matricule != null)
                Text(
                  'Matricule : ${widget.matricule}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 20),

              // QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Présentez ce QR code à la caisse du réfectoire pour valider votre repas.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuView(Map<String, dynamic>? activeMenu) {
    if (_weeklyMenu.isEmpty || activeMenu == null) {
      return const Center(child: Text('Aucun menu renseigné pour cette semaine.'));
    }

    final day = activeMenu['dayOfWeek'] ?? 'Jour';
    final mainDish = activeMenu['mainDish'] ?? 'Plat du jour';
    final starter = activeMenu['starterDish'] ?? 'Entrée fraîche';
    final side = activeMenu['sideDish'] ?? 'Garniture';
    final dessert = activeMenu['dessert'] ?? 'Fruit de saison';
    final calories = activeMenu['calories'] ?? 650;
    final allergens = activeMenu['allergens']?.toString() ?? 'Aucun';
    final notes = activeMenu['notes']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Days Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_weeklyMenu.length, (index) {
                final d = _weeklyMenu[index]['dayOfWeek'] ?? 'Jour';
                final isSelected = index == _selectedDayIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.black12,
                      ),
                    ),
                    child: Text(
                      d,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Main Daily Dish Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withOpacity(0.3),
                  blurRadius: 12,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        day.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$calories kcal',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Plat Principal',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  mainDish,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Menu Course Details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Composition du Plateau Repas',
                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _dishRow(Icons.eco_rounded, 'Entrée', starter, const Color(0xFF10B981)),
                const Divider(height: 20),
                _dishRow(Icons.restaurant_rounded, 'Plat chaud', mainDish, const Color(0xFFEA580C)),
                const Divider(height: 20),
                _dishRow(Icons.grain_rounded, 'Accompagnement', side, const Color(0xFF3B82F6)),
                const Divider(height: 20),
                _dishRow(Icons.icecream_rounded, 'Dessert', dessert, const Color(0xFFEC4899)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Allergens & Nutritional Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Allergènes Déclarés',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                      ),
                      Text(
                        allergens,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pre-order Button
          ElevatedButton.icon(
            onPressed: () => _preorderMeal(activeMenu),
            icon: const Icon(Icons.bookmark_added_rounded),
            label: Text(
              'Réserver ce repas ($day)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dishRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
