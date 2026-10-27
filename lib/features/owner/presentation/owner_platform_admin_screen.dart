import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/owner_repository.dart';

class OwnerPlatformAdminScreen extends StatefulWidget {
  const OwnerPlatformAdminScreen({super.key});

  @override
  State<OwnerPlatformAdminScreen> createState() =>
      _OwnerPlatformAdminScreenState();
}

class _OwnerPlatformAdminScreenState extends State<OwnerPlatformAdminScreen> {
  final OwnerRepository _repository = locator<OwnerRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _repository.getPlatformStats();
    final schools = await _repository.getSchools();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _schools = schools;
      _isLoading = false;
    });
  }

  Future<void> _openSchoolEditor(Map<String, dynamic> school) async {
    var plan = (school['plan'] ?? 'basic').toString();
    var status = (school['status'] ?? 'active').toString();

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
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                final result = await _repository.updateSchool(
                                  schoolId: school['id'] as int,
                                  plan: plan,
                                  status: status,
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
                                          ? 'Etablissement mis a jour.'
                                          : (result['error']?.toString() ??
                                              'Erreur de mise a jour'),
                                    ),
                                  ),
                                );
                                if (result['success'] == true) {
                                  await _load();
                                }
                              },
                        child: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateSchoolForm() async {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    var plan = 'basic';
    var status = 'active';

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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nouvelle ecole', style: AppTextStyles.heading3),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: _decoration('Nom de l ecole'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: slugController,
                        decoration: _decoration('Slug / sous-domaine'),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  final result = await _repository.createSchool(
                                    name: nameController.text,
                                    slug: slugController.text,
                                    plan: plan,
                                    status: status,
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
                                            ? 'Ecole creee avec succes.'
                                            : (result['error']?.toString() ??
                                                'Erreur creation ecole'),
                                      ),
                                    ),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          child: Text(_isSaving ? 'Creation...' : 'Creer'),
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

  Future<void> _toggleSchoolStatus(Map<String, dynamic> school) async {
    final current = (school['status'] ?? 'active').toString().toLowerCase();
    final next = current.contains('active') ? 'suspended' : 'active';
    setState(() => _isSaving = true);
    final result = await _repository.updateSchool(
      schoolId: school['id'] as int,
      status: next,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Statut mis a jour.'
              : (result['error']?.toString() ?? 'Erreur de statut'),
        ),
      ),
    );
    if (result['success'] == true) {
      await _load();
    }
  }

  Future<void> _deleteSchool(Map<String, dynamic> school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer ecole'),
          content: Text(
            'Supprimer ${(school['name'] ?? 'cette ecole').toString()} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    final result = await _repository.deleteSchool(school['id'] as int);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Ecole supprimee.'
              : (result['error']?.toString() ?? 'Erreur suppression'),
        ),
      ),
    );
    if (result['success'] == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('Gestion Plateforme'),
        actions: [
          IconButton(
            onPressed: _openCreateSchoolForm,
            icon: const Icon(Icons.add_business_rounded),
            tooltip: 'Nouvelle ecole',
          ),
        ],
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
                    childAspectRatio: 1.35,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _statCard(
                        'Ecoles',
                        '${_stats['totalSchools'] ?? 0}',
                        Icons.apartment_rounded,
                      ),
                      _statCard(
                        'Eleves',
                        '${_stats['totalStudents'] ?? 0}',
                        Icons.groups_rounded,
                      ),
                      _statCard(
                        'Utilisateurs',
                        '${_stats['totalUsers'] ?? 0}',
                        Icons.manage_accounts_rounded,
                      ),
                      _statCard(
                        'Revenu',
                        _money((_stats['revenue'] as num?)?.toDouble() ?? 0),
                        Icons.trending_up_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openCreateSchoolForm,
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Ajouter une ecole'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Etablissements', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  if (_schools.isEmpty)
                    _empty('Aucun etablissement trouve.')
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
        borderRadius: BorderRadius.circular(22),
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
          Text('Slug: ${school['slug'] ?? '-'}', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text('Plan: ${school['plan'] ?? '-'}', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            'Expiration: ${expiry == null || expiry.isEmpty ? '-' : expiry}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => _openSchoolEditor(school),
                child: const Text('Modifier'),
              ),
              TextButton(
                onPressed: _isSaving ? null : () => _toggleSchoolStatus(school),
                child: Text(
                  ((school['status'] ?? 'active')
                          .toString()
                          .toLowerCase()
                          .contains('active'))
                      ? 'Suspendre'
                      : 'Activer',
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => _deleteSchool(school),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _empty(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Center(child: Text(message, style: AppTextStyles.body)),
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

  String _money(double value) => '${value.toStringAsFixed(0)} CFA';
}
