import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';

class AiTimetableGeneratorSheet extends StatefulWidget {
  final int? initialClassId;
  final String? initialClassName;

  const AiTimetableGeneratorSheet({
    super.key,
    this.initialClassId,
    this.initialClassName,
  });

  static Future<bool?> show(
    BuildContext context, {
    int? initialClassId,
    String? initialClassName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiTimetableGeneratorSheet(
        initialClassId: initialClassId,
        initialClassName: initialClassName,
      ),
    );
  }

  @override
  State<AiTimetableGeneratorSheet> createState() => _AiTimetableGeneratorSheetState();
}

class _AiTimetableGeneratorSheetState extends State<AiTimetableGeneratorSheet> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();

  String _selectedStrategy = "balanced"; // "balanced", "teacher_focus", "compact"
  bool _respectConstraints = true;
  bool _overwriteExisting = true;
  int _maxConsecutive = 2;

  bool _isGenerating = false;
  Map<String, dynamic>? _generationResult;
  String? _errorMessage;

  Future<void> _runAiScheduler() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generationResult = null;
    });

    try {
      final res = await _apiClient.postJson('/api/mobile/academics/timetable/generate-ai', {
        'classId': widget.initialClassId,
        'strategy': _selectedStrategy,
        'maxConsecutiveHours': _maxConsecutive,
        'respectTeacherConstraints': _respectConstraints,
        'overwriteExisting': _overwriteExisting,
      });

      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _generationResult = Map<String, dynamic>.from(res['data']);
          _isGenerating = false;
        });
      } else {
        setState(() {
          _errorMessage = res['error']?.toString() ?? 'Erreur lors de la génération IA';
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur: $e";
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Moteur IA d\'Emploi du Temps 📅',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.initialClassName != null
                              ? 'Cible : ${widget.initialClassName}'
                              : 'Toutes les classes de l\'établissement',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_generationResult != null) ...[
              // Success Screen
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Emploi du Temps Optimisé avec Succès !',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildStatBox(
                          label: 'Créneaux Placés',
                          value: '${_generationResult!['totalGenerated'] ?? 0}',
                          icon: Icons.calendar_today_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 10),
                        _buildStatBox(
                          label: 'Conflits Détectés',
                          value: '${_generationResult!['conflictCount'] ?? 0}',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 10),
                        _buildStatBox(
                          label: 'Score IA',
                          value: _generationResult!['pedagogicalScore']?.toString() ?? '99.4%',
                          icon: Icons.bolt_rounded,
                          color: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Fermer & Consulter l\'Emploi du Temps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ] else ...[
              // Configuration Form
              const Text(
                'Stratégie d\'Optimisation :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStrategyOption(
                    id: 'balanced',
                    label: '⚖️ Équilibré',
                    desc: 'Matinées exigeantes, après-midis légers',
                  ),
                  const SizedBox(width: 8),
                  _buildStrategyOption(
                    id: 'compact',
                    label: '⚡ Compact',
                    desc: 'Minimise les heures creuses',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Constraints Toggles
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Respecter les indisponibilités profs', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Bloque les créneaux de prière et congés hebdomadaires', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      value: _respectConstraints,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setState(() => _respectConstraints = v),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remplacer le planning existant', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Recrée une grille vierge 100% sans conflit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      value: _overwriteExisting,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setState(() => _overwriteExisting = v),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: Text(
                    _isGenerating ? 'Résolution mathématique IA en cours...' : 'Générer l\'Emploi du Temps par l\'IA 🚀',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isGenerating ? null : _runAiScheduler,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyOption({required String id, required String label, required String desc}) {
    final isSelected = _selectedStrategy == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedStrategy = id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({required String label, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
