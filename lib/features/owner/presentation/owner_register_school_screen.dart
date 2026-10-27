import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/owner_repository.dart';

class OwnerRegisterSchoolScreen extends StatefulWidget {
  const OwnerRegisterSchoolScreen({super.key});

  @override
  State<OwnerRegisterSchoolScreen> createState() =>
      _OwnerRegisterSchoolScreenState();
}

class _OwnerRegisterSchoolScreenState extends State<OwnerRegisterSchoolScreen> {
  final OwnerRepository _repository = locator<OwnerRepository>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _schoolNameController;
  late final TextEditingController _slugController;
  late final TextEditingController _customDomainController;
  late final TextEditingController _adminNameController;
  late final TextEditingController _adminUsernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isSaving = false;
  bool _success = false;
  String _createdSlug = '';
  String _plan = 'basic';
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _schoolNameController = TextEditingController();
    _slugController = TextEditingController();
    _customDomainController = TextEditingController();
    _adminNameController = TextEditingController();
    _adminUsernameController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _slugController.dispose();
    _customDomainController.dispose();
    _adminNameController.dispose();
    _adminUsernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final result = await _repository.createSchool(
      name: _schoolNameController.text,
      slug: _slugController.text,
      plan: _plan,
      status: _status,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      setState(() {
        _success = true;
        _createdSlug = _slugController.text.trim().toLowerCase();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['error']?.toString() ?? 'Erreur creation ecole',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('Lien d\'Inscription'),
      ),
      body: _success ? _successView() : _formView(),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEBF0F5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFECFDF5),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ecole creee avec succes',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Adresse proposee:',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 6),
              SelectableText(
                '$_createdSlug.edut.pro',
                style: AppTextStyles.bodyBold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'La creation de l etablissement est terminee. Le compte administrateur pourra ensuite etre finalise depuis le flux web ou la console proprietaire.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionCard(
            title: 'Etablissement',
            child: Column(
              children: [
                _textField(
                  controller: _schoolNameController,
                  label: 'Nom de l ecole',
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _slugController,
                  label: 'Slug / sous-domaine',
                  helper:
                      'Exemple: mon-ecole donne mon-ecole.edut.pro',
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _customDomainController,
                  label: 'Domaine personnalise',
                  required: false,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _plan,
                  items: const ['basic', 'pro', 'premium', 'enterprise']
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _plan = value ?? 'basic');
                  },
                  decoration: _decoration('Plan'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: const ['active', 'suspended', 'trialing']
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _status = value ?? 'active');
                  },
                  decoration: _decoration('Statut'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Administrateur',
            child: Column(
              children: [
                _textField(
                  controller: _adminNameController,
                  label: 'Nom complet admin',
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _adminUsernameController,
                  label: 'Identifiant admin',
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  obscure: true,
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _confirmPasswordController,
                  label: 'Confirmer mot de passe',
                  obscure: true,
                ),
                const SizedBox(height: 10),
                Text(
                  'Le formulaire mobile reprend les champs du web. L etablissement est cree immediatement depuis ce flux proprietaire.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_isSaving ? 'Creation...' : 'Creer l ecole'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    bool required = true,
    bool obscure = false,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: required
          ? (value) => (value == null || value.trim().isEmpty)
              ? 'Champ requis'
              : null
          : null,
      decoration: _decoration(label).copyWith(helperText: helper),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
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
