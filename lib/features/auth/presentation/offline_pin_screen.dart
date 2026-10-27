import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/services/inactivity_lock_service.dart';
import '../../../core/auth/role_redirect.dart';

class OfflinePinScreen extends StatefulWidget {
  final bool isSettingPin;

  const OfflinePinScreen({super.key, this.isSettingPin = false});

  @override
  State<OfflinePinScreen> createState() => _OfflinePinScreenState();
}

class _OfflinePinScreenState extends State<OfflinePinScreen> {
  final List<String> _enteredPin = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _firstPinForSetup;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (widget.isSettingPin) return;
    final bioService = locator<BiometricAuthService>();
    final available = await bioService.isBiometricAvailable();
    if (mounted) {
      setState(() => _canUseBiometrics = available);
      if (available) {
        _handleBiometricUnlock();
      }
    }
  }

  Future<void> _handleBiometricUnlock() async {
    final bioService = locator<BiometricAuthService>();
    final authenticated = await bioService.authenticate(
      reason: 'Déverrouillez votre session Edut hors-ligne avec votre empreinte ou visage',
    );

    if (authenticated && mounted) {
      _unlockAndNavigate();
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin.add(digit);
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _processPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
        _errorMessage = null;
      });
    }
  }

  Future<void> _processPin() async {
    final sessionManager = locator<SessionManager>();
    final pin = _enteredPin.join();

    setState(() => _isLoading = true);

    try {
      if (widget.isSettingPin) {
        // Mode Setup / Confirmation
        if (_firstPinForSetup == null) {
          setState(() {
            _firstPinForSetup = pin;
            _enteredPin.clear();
            _isLoading = false;
          });
          return;
        } else {
          if (_firstPinForSetup == pin) {
            await sessionManager.setOfflinePin(pin);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Code PIN hors-ligne configuré avec succès !'),
                  backgroundColor: Color(0xFF059669),
                ),
              );
              _unlockAndNavigate();
            }
          } else {
            setState(() {
              _firstPinForSetup = null;
              _enteredPin.clear();
              _errorMessage = 'Les deux codes ne correspondent pas. Recommencez.';
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Mode Unlock
      final isValid = await sessionManager.validateOfflinePin(pin);
      if (isValid && mounted) {
        _unlockAndNavigate();
      } else {
        setState(() {
          _enteredPin.clear();
          _errorMessage = 'Code PIN incorrect. Veuillez réessayer.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _enteredPin.clear();
        _errorMessage = 'Erreur d’authentification: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _unlockAndNavigate() async {
    if (locator.isRegistered<InactivityLockService>()) {
      locator<InactivityLockService>().unlock();
      locator<InactivityLockService>().recordActivity();
    }

    final sessionManager = locator<SessionManager>();
    final role = await sessionManager.getRole() ?? 'staff';

    if (mounted) {
      context.go(getHomeRouteForRole(role));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirming = widget.isSettingPin && _firstPinForSetup != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.lock_clock_rounded, color: Color(0xFF38BDF8), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isSettingPin
                    ? (isConfirming ? 'Confirmez le code PIN' : 'Créer votre code PIN')
                    : 'Déverrouillage Hors-ligne',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isSettingPin
                    ? (isConfirming
                        ? 'Tapez à nouveau les 4 chiffres pour confirmer'
                        : 'Ce code vous permettra d\'accéder à l\'application sans connexion Internet')
                    : 'Entrez votre code à 4 chiffres ou utilisez la biométrie',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 32),

              // PIN Indicators (4 Dots)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],

              const Spacer(),

              // Custom Keypad
              AbsorbPointer(
                absorbing: _isLoading,
                child: Opacity(
                  opacity: _isLoading ? 0.6 : 1.0,
                  child: _buildKeypad(),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions (Biometric or Switch to regular login)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B), size: 18),
                    label: const Text(
                      'Connexion classique',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                  if (_canUseBiometrics && !widget.isSettingPin)
                    IconButton(
                      icon: const Icon(Icons.fingerprint, color: Color(0xFF38BDF8), size: 36),
                      onPressed: _handleBiometricUnlock,
                      tooltip: 'Empreinte digitale / Face ID',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'DEL'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 72);
                }
                if (key == 'DEL') {
                  return InkWell(
                    onTap: _onDeletePressed,
                    borderRadius: BorderRadius.circular(36),
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 26),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => _onDigitPressed(key),
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF334155), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
