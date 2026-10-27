import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class InspectionDialog extends StatefulWidget {
  final Map<String, dynamic> seance;
  final VoidCallback onValidated;

  const InspectionDialog({
    super.key,
    required this.seance,
    required this.onValidated,
  });

  static Future<void> show(BuildContext context, {required Map<String, dynamic> seance, required VoidCallback onValidated}) {
    return showDialog(
      context: context,
      builder: (_) => InspectionDialog(seance: seance, onValidated: onValidated),
    );
  }

  @override
  State<InspectionDialog> createState() => _InspectionDialogState();
}

class _InspectionDialogState extends State<InspectionDialog> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedStatus = 'Validé';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'Validé', 'label': 'Viser & Valider la séance', 'color': Color(0xFF10B981), 'icon': Icons.verified_rounded},
    {'value': 'Rejeté', 'label': 'Rejeter pour non-conformité', 'color': Color(0xFFEF4444), 'icon': Icons.cancel_rounded},
    {'value': 'En attente', 'label': 'Observations / Révision demandée', 'color': Color(0xFFF59E0B), 'icon': Icons.pending_actions_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _remarksController.text = widget.seance['observation'] ?? '';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitVisa() async {
    setState(() => _isSubmitting = true);
    try {
      final seanceId = widget.seance['id'];
      final res = await _apiClient.postJson('/api/mobile/pedagogie/inspect', {
        'seanceId': seanceId,
        'status': _selectedStatus,
        'inspectorRemarks': _remarksController.text.trim(),
      });

      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          widget.onValidated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Visa d\'inspection enregistré : $_selectedStatus'),
              backgroundColor: _selectedStatus == 'Validé' ? AppColors.success : AppColors.warning,
            ),
          );
        }
      } else {
        throw Exception(res['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.seance['titre_lecon'] ?? widget.seance['titreLecon'] ?? 'Séance pédagogique';
    final teacher = widget.seance['teacher_name'] ?? widget.seance['employee_name'] ?? 'Enseignant';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rate_review_rounded, color: Color(0xFF0F766E), size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Visa & Inspection Pédagogique',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Enseignant : $teacher', style: const TextStyle(color: AppColors.slate600, fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Décision de l\'inspecteur / Direction :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              ..._statusOptions.map((opt) {
                final isSelected = opt['value'] == _selectedStatus;
                final Color color = opt['color'];
                return InkWell(
                  onTap: () => setState(() => _selectedStatus = opt['value']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(opt['icon'], color: color, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            opt['label'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? color : AppColors.slate700,
                            ),
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 16),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Text(
                'Directives pédagogiques / Observations :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ex: Progression conforme au programme. Soigner la trace écrite...',
                  hintStyle: TextStyle(color: AppColors.slate400, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppColors.slate500)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitVisa,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Apposer le visa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
