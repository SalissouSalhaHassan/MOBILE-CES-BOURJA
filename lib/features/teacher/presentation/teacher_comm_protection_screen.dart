import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/teacher_repository.dart';
import '../../../core/di/injection.dart';

class TeacherCommProtectionScreen extends StatefulWidget {
  const TeacherCommProtectionScreen({super.key});

  @override
  State<TeacherCommProtectionScreen> createState() => _TeacherCommProtectionScreenState();
}

class _TeacherCommProtectionScreenState extends State<TeacherCommProtectionScreen> {
  final _teacherRepo = locator<TeacherRepository>();
  bool _isLoading = true;

  bool _dndEnabled = true;
  String _startHour = '17:00';
  String _endHour = '07:30';
  bool _dndWeekends = true;
  final _autoReplyController = TextEditingController();
  List<String> _cannedResponses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoReplyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _teacherRepo.getCommProtectionSettings();
      setState(() {
        _dndEnabled = data['dndEnabled'] ?? true;
        _startHour = data['dndStartHour'] ?? '17:00';
        _endHour = data['dndEndHour'] ?? '07:30';
        _dndWeekends = data['dndWeekends'] ?? true;
        _autoReplyController.text = data['autoReplyMessage'] ?? 'Bonjour. Le professeur est actuellement hors de ses heures de disponibilité scolaire.';
        _cannedResponses = (data['cannedResponses'] as List?)?.map((e) => e.toString()).toList() ?? [
          'Bien reçu, merci pour votre signalement.',
          'Je ferai le point avec l\'élève dès demain en classe.',
          'Veuillez contacter l\'administration pour ce sujet.',
        ];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    try {
      await _teacherRepo.saveCommProtectionSettings(
        dndEnabled: _dndEnabled,
        dndStartHour: _startHour,
        dndEndHour: _endHour,
        dndWeekends: _dndWeekends,
        autoReplyMessage: _autoReplyController.text.trim(),
        cannedResponses: _cannedResponses,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres de protection et réponses rapides enregistrés ! 🛡️✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddCannedDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle Réponse Rapide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Ex: L\'élève a bien rattrapé son devoir.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _cannedResponses.add(ctrl.text.trim()));
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Protection & Réponses Rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Enregistrer',
            onPressed: _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Protection Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF334155)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bouclier Vie Privée Enseignant', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Protection automatique contre les messages tardifs des parents d\'élèves.', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 1. Office Hours & DND
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.nightlight_round, color: Color(0xFF6D28D9), size: 20),
                              SizedBox(width: 8),
                              Text('Mode "Ne Pas Déranger" (DND)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Switch(
                            value: _dndEnabled,
                            activeThumbColor: const Color(0xFF6D28D9),
                            onChanged: (v) => setState(() => _dndEnabled = v),
                          ),
                        ],
                      ),
                      if (_dndEnabled) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Début silence :', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                                    child: Text(_startHour, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Fin silence :', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                                    child: Text(_endHour, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bloquer aussi le Week-end (Sam-Dim)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                            Checkbox(
                              value: _dndWeekends,
                              activeColor: const Color(0xFF6D28D9),
                              onChanged: (v) => setState(() => _dndWeekends = v ?? true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text('Message de Réponse Automatique :', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _autoReplyController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Canned Quick Replies (الردود السريعة الجاهزة)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 20),
                              SizedBox(width: 8),
                              Text('Réponses Rapides Préenregistrées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6D28D9)),
                            onPressed: _showAddCannedDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Boutons de réponse en 1 clic utilisables directement lors des échanges avec les parents.', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                      const SizedBox(height: 12),
                      ..._cannedResponses.map((res) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.quickreply_rounded, color: Color(0xFF6D28D9), size: 16),
                              const SizedBox(width: 10),
                              Expanded(child: Text(res, style: const TextStyle(fontSize: 12, color: Color(0xFF4C1D95)))),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.slate400),
                                onPressed: () => setState(() => _cannedResponses.remove(res)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text('Enregistrer mes Préférences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
