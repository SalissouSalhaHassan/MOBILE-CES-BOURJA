import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/owner_repository.dart';

class OwnerSubscriptionScreen extends StatefulWidget {
  const OwnerSubscriptionScreen({super.key});

  @override
  State<OwnerSubscriptionScreen> createState() =>
      _OwnerSubscriptionScreenState();
}

class _OwnerSubscriptionScreenState extends State<OwnerSubscriptionScreen> {
  final OwnerRepository _repository = locator<OwnerRepository>();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await _repository.getSubscriptionSummary();
    final schools = await _repository.getSchools();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _schools = schools;
      _isLoading = false;
    });
  }

  Future<void> _openEditor(Map<String, dynamic> school) async {
    var plan = (school['plan'] ?? 'basic').toString();
    var status = (school['status'] ?? 'active').toString();
    final expiryController = TextEditingController(
      text: school['subscription_expiry']?.toString().split('T').first ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F8FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (school['name'] ?? 'Ecole').toString(),
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: plan,
                        items: const ['basic', 'pro', 'premium', 'enterprise']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => plan = value ?? 'basic');
                        },
                        decoration: _decoration('Plan'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const ['active', 'suspended', 'trialing']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => status = value ?? 'active');
                        },
                        decoration: _decoration('Statut'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: expiryController,
                        decoration: _decoration('Expiration (YYYY-MM-DD)'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  final expiry = expiryController.text.trim();
                                  final expiryIso = expiry.isEmpty
                                      ? ''
                                      : '${expiry}T00:00:00';
                                  setState(() => _isSaving = true);
                                  final result = await _repository.updateSchool(
                                    schoolId: school['id'] as int,
                                    plan: plan,
                                    status: status,
                                    subscriptionExpiry:
                                        expiryIso.isEmpty ? null : expiryIso,
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['success'] == true
                                            ? 'Abonnement mis a jour.'
                                            : (result['error']?.toString() ??
                                                'Erreur abonnement'),
                                      ),
                                    ),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          child: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('Gestion des Abonnements'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _card(
                        'Total',
                        '${_summary['total'] ?? 0}',
                        Icons.layers_rounded,
                      ),
                      _card(
                        'Actifs',
                        '${_summary['active'] ?? 0}',
                        Icons.verified_rounded,
                      ),
                      _card(
                        'Suspendus',
                        '${_summary['suspended'] ?? 0}',
                        Icons.pause_circle_rounded,
                      ),
                      _card(
                        'Expires',
                        '${_summary['expired'] ?? 0}',
                        Icons.event_busy_rounded,
                      ),
                      _card(
                        'Basic',
                        '${_summary['basic'] ?? 0}',
                        Icons.looks_one_rounded,
                      ),
                      _card(
                        'Pro / Premium',
                        '${(_summary['pro'] ?? 0) + (_summary['premium'] ?? 0)}',
                        Icons.workspace_premium_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Ecoles et abonnements', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  if (_schools.isEmpty)
                    _empty()
                  else
                    ..._schools.map(_schoolCard),
                ],
              ),
            ),
    );
  }

  Widget _schoolCard(Map<String, dynamic> school) {
    final expiry = school['subscription_expiry']?.toString().split('T').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Text(
                  (school['name'] ?? 'Ecole').toString(),
                  style: AppTextStyles.bodyBold,
                ),
              ),
              _pill((school['status'] ?? 'active').toString()),
            ],
          ),
          const SizedBox(height: 6),
          Text('Plan: ${school['plan'] ?? '-'}', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            'Expiration: ${expiry == null || expiry.isEmpty ? '-' : expiry}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openEditor(school),
              child: const Text('Modifier abonnement'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String label, String value, IconData icon) {
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
          Icon(icon, color: AppColors.primary),
          const Spacer(),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading3),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    final active = text.toLowerCase().contains('active');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? const Color(0xFF059669) : const Color(0xFFDC2626),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Center(
        child: Text(
          'Aucun abonnement trouve.',
          style: AppTextStyles.body,
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
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
    );
  }
}
