import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _schoolCodeController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _activationPinController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _role = 'student'; // 'student' or 'teacher'
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _schoolCodeController.dispose();
    _matriculeController.dispose();
    _activationPinController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Les mots de passe ne correspondent pas.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await locator<AuthRepository>().register(
      role: _role,
      schoolSlug: _schoolCodeController.text.trim(),
      matriculeOrEmail: _matriculeController.text.trim(),
      username: _usernameController.text.replaceAll(' ', ''),
      fullName: _fullNameController.text.trim(),
      password: _passwordController.text,
      activationPin: _activationPinController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        _showSuccessDialog();
      } else {
        setState(() {
          _errorMessage = result.message ?? "Erreur lors de l'inscription.";
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text(
              'Succès !',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Votre compte a été créé avec succès et associé à votre profil. Vous pouvez maintenant vous connecter.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login', extra: {'username': _usernameController.text.trim()});
            },
            child: const Text(
              'Se connecter',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEEF2F6),
              Color(0xFFE0E7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Logo & Title
                const Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.school,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Inscription Edut',
                    style: AppTextStyles.heading1.copyWith(fontSize: 26),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Créer un compte étudiant ou enseignant',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                // Register Card
                Card(
                  elevation: 4,
                  shadowColor: Colors.black.withAlpha(13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role Picker
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _role = 'student'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _role == 'student' ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: _role == 'student'
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Étudiant',
                                          style: TextStyle(
                                            color: _role == 'student' ? AppColors.slate900 : AppColors.slate500,
                                            fontSize: 13,
                                            fontWeight: _role == 'student' ? FontWeight.bold : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _role = 'teacher'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _role == 'teacher' ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: _role == 'teacher'
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Enseignant',
                                          style: TextStyle(
                                            color: _role == 'teacher' ? AppColors.slate900 : AppColors.slate500,
                                            fontSize: 13,
                                            fontWeight: _role == 'teacher' ? FontWeight.bold : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // School Code Input
                          TextFormField(
                            controller: _schoolCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Code Établissement',
                              hintText: 'Ex: 1 ou excellence',
                              prefixIcon: Icon(Icons.business_outlined, color: AppColors.slate400),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Saisir le code établissement' : null,
                          ),
                          const SizedBox(height: 14),

                          // Matricule Input
                          TextFormField(
                            controller: _matriculeController,
                            decoration: InputDecoration(
                              labelText: _role == 'student' ? "Numéro Matricule / Admission" : "Matricule ou Email Enseignant",
                              hintText: _role == 'student' ? 'Ex: EDUT-2024-000003' : 'Ex: prof@ecole.com',
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.slate400),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Saisir votre matricule ou email' : null,
                          ),
                          const SizedBox(height: 14),

                          // Code d'activation (PIN) Input
                          TextFormField(
                            controller: _activationPinController,
                            decoration: const InputDecoration(
                              labelText: "Code d'activation (PIN)",
                              hintText: 'Code secret à 6 chiffres',
                              prefixIcon: Icon(Icons.shield_outlined, color: AppColors.slate400),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? "Saisir le code d'activation" : null,
                          ),
                          const SizedBox(height: 14),

                          // Nom Complet Input
                          TextFormField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom Complet',
                              hintText: 'Votre nom et prénom',
                              prefixIcon: Icon(Icons.person_outline, color: AppColors.slate400),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Saisir votre nom complet' : null,
                          ),
                          const SizedBox(height: 14),

                          // Nom d'utilisateur Input
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: "Nom d'utilisateur",
                              hintText: 'Ex: ali.diallo',
                              prefixIcon: Icon(Icons.alternate_email_outlined, color: AppColors.slate400),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? "Saisir le nom d'utilisateur" : null,
                          ),
                          const SizedBox(height: 14),

                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.slate400),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.slate400,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: Validators.validatePassword,
                          ),
                          const SizedBox(height: 14),

                          // Confirm Password Input
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            decoration: const InputDecoration(
                              labelText: 'Confirmer le mot de passe',
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline, color: AppColors.slate400),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Confirmer le mot de passe' : null,
                          ),
                          const SizedBox(height: 16),

                          // Error display
                          if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.danger, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Register Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "S'inscrire",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Déjà inscrit ? Se connecter',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
