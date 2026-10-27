import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/inactivity_lock_service.dart';
import '../data/auth_repository.dart';

class InactivityLockWrapper extends StatefulWidget {
  final Widget child;

  const InactivityLockWrapper({super.key, required this.child});

  @override
  State<InactivityLockWrapper> createState() => _InactivityLockWrapperState();
}

class _InactivityLockWrapperState extends State<InactivityLockWrapper> {
  final InactivityLockService _lockService = locator<InactivityLockService>();

  @override
  void initState() {
    super.initState();
    _lockService.startTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _lockService.recordActivity(),
      onPointerMove: (_) => _lockService.recordActivity(),
      onPointerUp: (_) => _lockService.recordActivity(),
      child: Stack(
        fit: StackFit.expand,
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          ValueListenableBuilder<bool>(
            valueListenable: _lockService.isLocked,
            builder: (context, isLocked, _) {
              if (!isLocked) return const SizedBox.shrink();
              return const Positioned.fill(
                child: _AppLockScreenOverlay(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppLockScreenOverlay extends StatefulWidget {
  const _AppLockScreenOverlay();

  @override
  State<_AppLockScreenOverlay> createState() => _AppLockScreenOverlayState();
}

class _AppLockScreenOverlayState extends State<_AppLockScreenOverlay> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String _displayName = 'Utilisateur';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final sessionManager = locator<SessionManager>();
    final studentName = await sessionManager.getStudentName();
    final email = await sessionManager.getEmail();

    if (mounted) {
      setState(() {
        _email = email ?? '';
        _displayName = (studentName != null && studentName.isNotEmpty)
            ? studentName
            : (_email.isNotEmpty ? _email : 'Utilisateur');
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez saisir votre mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionManager = locator<SessionManager>();
      
      // 1. First check local password hash
      bool isValid = await sessionManager.validateCurrentPassword(password);

      // 2. If not verified locally, try online authentication
      if (!isValid && _email.isNotEmpty) {
        final authRepo = locator<AuthRepository>();
        final loginRes = await authRepo.login(email: _email, password: password);
        if (loginRes.success) {
          isValid = true;
        }
      }

      if (isValid) {
        if (mounted) {
          _passwordController.clear();
          locator<InactivityLockService>().unlock();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Mot de passe incorrect. Veuillez réessayer.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de vérification: $e';
        });
      }
    }
  }

  Future<void> _logout() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      await locator<AuthRepository>().logout();
    } catch (_) {}
    locator<InactivityLockService>().unlock();
    try {
      AppRouter.router.go('/login');
    } catch (_) {
      if (mounted) {
        GoRouter.of(context).go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: const Color(0xFF0F172A).withValues(alpha: 0.90),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock icon with glowing gradient badge
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Session Verrouillée',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: Color(0xFF818CF8)),
                          const SizedBox(width: 6),
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Pour votre sécurité après 3 minutes d\'inactivité, veuillez entrer votre mot de passe pour déverrouiller.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Password input field card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6366F1), size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onSubmitted: (_) => _unlock(),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Unlock Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _unlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_open_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Déverrouiller',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logout option
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF94A3B8)),
                      label: const Text(
                        'Changer de compte / Se déconnecter',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
