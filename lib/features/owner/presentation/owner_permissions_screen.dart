import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/owner_repository.dart';

class OwnerPermissionsScreen extends StatefulWidget {
  const OwnerPermissionsScreen({super.key});

  @override
  State<OwnerPermissionsScreen> createState() => _OwnerPermissionsScreenState();
}

class _OwnerPermissionsScreenState extends State<OwnerPermissionsScreen> {
  final OwnerRepository _repository = locator<OwnerRepository>();

  static const List<_PermissionModule> _modules = [
    _PermissionModule('Students', 'Etudiants', Icons.school_rounded),
    _PermissionModule('Finance', 'Finance', Icons.account_balance_wallet_rounded),
    _PermissionModule('HR', 'RH', Icons.badge_rounded),
    _PermissionModule('Attendance', 'Presence', Icons.fact_check_rounded),
    _PermissionModule('Academics', 'Academique', Icons.auto_stories_rounded),
    _PermissionModule('Hostel', 'Internat', Icons.apartment_rounded),
    _PermissionModule('Security', 'Securite', Icons.shield_rounded),
    _PermissionModule('Messaging', 'Messagerie', Icons.message_rounded),
    _PermissionModule('Inventory', 'Stock', Icons.inventory_2_rounded),
  ];

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _roles = [];
  int? _selectedRoleId;
  final TextEditingController _newRoleController = TextEditingController();
  final Map<String, Map<String, bool>> _editedPermissions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newRoleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final roles = await _repository.getRolesWithPermissions();
    if (!mounted) return;

    final nextRoleId = _selectedRoleId != null &&
            roles.any((role) => role['id'] == _selectedRoleId)
        ? _selectedRoleId
        : (roles.isNotEmpty ? roles.first['id'] as int : null);

    setState(() {
      _roles = roles;
      _selectedRoleId = nextRoleId;
      _isLoading = false;
    });

    if (nextRoleId != null) {
      _selectRole(nextRoleId);
    }
  }

  void _selectRole(int roleId) {
    final role = _roles.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['id'] == roleId,
          orElse: () => null,
        );
    if (role == null) return;

    final rolePermissions = List<Map<String, dynamic>>.from(
      role['permissions'] as List? ?? const [],
    );

    _editedPermissions
      ..clear()
      ..addEntries(
        _modules.map((module) {
          final existing = rolePermissions.cast<Map<String, dynamic>?>().firstWhere(
                (row) =>
                    (row?['module_name'] ?? '').toString().toLowerCase() ==
                    module.name.toLowerCase(),
                orElse: () => null,
              );
          return MapEntry(
            module.name,
            {
              'can_view': existing?['can_view'] == true,
              'can_edit': existing?['can_edit'] == true,
              'can_delete': existing?['can_delete'] == true,
            },
          );
        }),
      );

    setState(() {
      _selectedRoleId = roleId;
    });
  }

  Future<void> _createRole() async {
    final roleName = _newRoleController.text.trim();
    if (roleName.isEmpty) return;

    setState(() => _isSaving = true);
    final result = await _repository.createRole(roleName);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Role cree avec succes.'
              : (result['error']?.toString() ?? 'Erreur de creation'),
        ),
      ),
    );

    if (result['success'] == true) {
      _newRoleController.clear();
      await _load();
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedRoleId == null) return;

    setState(() => _isSaving = true);
    final payload = _modules
        .map(
          (module) => {
            'module_name': module.name,
            'can_view': _editedPermissions[module.name]?['can_view'] == true,
            'can_edit': _editedPermissions[module.name]?['can_edit'] == true,
            'can_delete': _editedPermissions[module.name]?['can_delete'] == true,
          },
        )
        .toList();

    final result = await _repository.updateRolePermissions(
      roleId: _selectedRoleId!,
      permissions: payload,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Permissions enregistrees.'
              : (result['error']?.toString() ?? 'Erreur de sauvegarde'),
        ),
      ),
    );

    if (result['success'] == true) {
      await _load();
    }
  }

  Future<void> _deleteSelectedRole() async {
    if (_selectedRoleId == null) return;
    final role = _selectedRole;
    if (role == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le role'),
        content: Text(
          'Supprimer ${(role['role_name'] ?? 'ce role').toString()} ?',
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
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    final result = await _repository.deleteRole(_selectedRoleId!);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Role supprime.'
              : (result['error']?.toString() ?? 'Erreur de suppression'),
        ),
      ),
    );

    if (result['success'] == true) {
      await _load();
    }
  }

  Map<String, dynamic>? get _selectedRole {
    if (_selectedRoleId == null) return null;
    for (final role in _roles) {
      if (role['id'] == _selectedRoleId) return role;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final role = _selectedRole;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('Permissions'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _savePermissions,
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Enregistrer',
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
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildCreateRoleCard(),
                  const SizedBox(height: 16),
                  _buildRolesCard(),
                  const SizedBox(height: 16),
                  if (role != null) _buildPermissionsEditor(role),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestion des permissions',
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez un role puis activez les acces aux modules du mobile.',
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveau role', style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          TextField(
            controller: _newRoleController,
            decoration: const InputDecoration(
              hintText: 'Ex: Censeur, Surveillant, Bibliothecaire',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _createRole,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Creer le role'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roles disponibles', style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          if (_roles.isEmpty)
            const Text('Aucun role trouve.')
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _roles.map((role) {
                final selected = role['id'] == _selectedRoleId;
                return ChoiceChip(
                  label: Text(
                    '${role['role_name']} (${role['users_count'] ?? 0})',
                  ),
                  selected: selected,
                  onSelected: (_) => _selectRole(role['id'] as int),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionsEditor(Map<String, dynamic> role) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (role['role_name'] ?? 'Role').toString(),
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${role['users_count'] ?? 0} utilisateur(s)',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : _deleteSelectedRole,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.danger,
                tooltip: 'Supprimer le role',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._modules.map(_buildModulePermissionCard),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePermissions,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulePermissionCard(_PermissionModule module) {
    final values = _editedPermissions[module.name] ??
        {
          'can_view': false,
          'can_edit': false,
          'can_delete': false,
        };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEEF2FF),
                child: Icon(module.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(module.label, style: AppTextStyles.bodyBold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toggleChip(
                label: 'Lecture',
                value: values['can_view'] == true,
                onChanged: (v) => _setPermission(module.name, 'can_view', v),
              ),
              _toggleChip(
                label: 'Modification',
                value: values['can_edit'] == true,
                onChanged: (v) => _setPermission(module.name, 'can_edit', v),
              ),
              _toggleChip(
                label: 'Suppression',
                value: values['can_delete'] == true,
                onChanged: (v) => _setPermission(module.name, 'can_delete', v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }

  void _setPermission(String moduleName, String key, bool value) {
    setState(() {
      _editedPermissions[moduleName] = {
        ...?_editedPermissions[moduleName],
        key: value,
      };
    });
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBF0F5)),
    );
  }
}

class _PermissionModule {
  const _PermissionModule(this.name, this.label, this.icon);

  final String name;
  final String label;
  final IconData icon;
}
