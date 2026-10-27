import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _schoolCodeController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _verificationController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _role = 'student'; // 'student' or 'teacher'
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _schoolCodeController.dispose();
    _matriculeController.dispose();
    _verificationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text.isNotEmpty &&
        _newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Les mots de passe ne correspondent pas.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await locator<AuthRepository>().resetPassword(
        role: _role,
        schoolSlug: _schoolCodeController.text.trim(),
        matriculeOrEmail: _matriculeController.text.trim(),
        verificationCodeOrPhone: _verificationController.text.trim(),
        newPassword: _newPasswordController.text.trim().isNotEmpty
            ? _newPasswordController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result != null) {
          _showSuccessDialog(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? data['username']?.toString() ?? '';
    final fullName = data['fullName']?.toString() ?? '';
    final schoolName = data['schoolName']?.toString() ?? '';
    final message = data['message']?.toString() ?? 'Opération réussie !';

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
              'Identité Confirmée !',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fullName.isNotEmpty) ...[
                    Text(
                      'Nom : $fullName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.slate800,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (schoolName.isNotEmpty) ...[
                    Text(
                      'École : $schoolName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(height: 12),
                  const Text(
                    'Votre Email de connexion :',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login', extra: {'username': email});
            },
            child: const Text(
              'Se connecter avec cet Email',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Récupération de compte',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shadowColor: Colors.black.withAlpha(13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mot de passe oublié ?',
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Retrouvez votre identifiant et définissez un nouveau mot de passe en quelques secondes.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 20),

                      // Segmented Role Switcher
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _role = 'student'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _role == 'student'
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.school_outlined,
                                          size: 18,
                                          color: _role == 'student'
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Élève',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _role == 'student'
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
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
                                    color: _role == 'teacher'
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 18,
                                          color: _role == 'teacher'
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Enseignant',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _role == 'teacher'
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // School Code
                      TextFormField(
                        controller: _schoolCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Code de l\'établissement',
                          hintText: 'ex: aiiu-niger ou 1',
                          prefixIcon: Icon(
                            Icons.business_outlined,
                            color: AppColors.slate400,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Code établissement requis'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Matricule / Admission Number
                      TextFormField(
                        controller: _matriculeController,
                        decoration: InputDecoration(
                          labelText: _role == 'student'
                              ? 'Numéro d\'admission / Matricule'
                              : 'Matricule ou Email Enseignant',
                          hintText: _role == 'student'
                              ? 'ex: MAT-2025-001'
                              : 'ex: ENS-042 ou prof@gmail.com',
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                            color: AppColors.slate400,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Matricule requis'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // PIN or Phone
                      TextFormField(
                        controller: _verificationController,
                        decoration: const InputDecoration(
                          labelText: 'Code PIN OU Téléphone enregistré',
                          hintText: 'ex: 1234 ou 96000000',
                          prefixIcon: Icon(
                            Icons.phonelink_lock_outlined,
                            color: AppColors.slate400,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Code PIN ou téléphone requis'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // New Password
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          hintText: '••••••••',
                          prefixIcon: const Icon(
                            Icons.lock_reset_outlined,
                            color: AppColors.slate400,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.slate400,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && val.length < 4) {
                            return 'Minimum 4 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          hintText: '••••••••',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleReset,
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
                                'Vérifier & Réinitialiser',
                                style: TextStyle(
                                  fontSize: 15,
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
          ],
        ),
      ),
    );
  }
}
