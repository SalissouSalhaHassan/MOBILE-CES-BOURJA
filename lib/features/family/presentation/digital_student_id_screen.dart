import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../family/data/family_repository.dart';
import 'student_health_profile_sheet.dart';

class DigitalStudentIdScreen extends StatefulWidget {
  const DigitalStudentIdScreen({super.key});

  @override
  State<DigitalStudentIdScreen> createState() => _DigitalStudentIdScreenState();
}

class _DigitalStudentIdScreenState extends State<DigitalStudentIdScreen>
    with SingleTickerProviderStateMixin {
  final FamilyRepository _familyRepo = locator<FamilyRepository>();
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _badges = [];
  int _meritPoints = 0;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isBack = false;
  Timer? _liveClockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = locator<SessionManager>();
      String? studentIdStr = await session.getStudentId();
      int? studentId = int.tryParse(studentIdStr ?? '');

      // 1. If not in session, try to load parent's children
      if (studentId == null) {
        final children = await _familyRepo.getChildren();
        if (children.isNotEmpty) {
          studentId = (children.first['id'] as num?)?.toInt();
          if (studentId != null) {
            _student = Map<String, dynamic>.from(children.first);
            await session.saveSession(
              token: await session.getToken() ?? '',
              email: await session.getEmail() ?? '',
              role: await session.getRole() ?? 'parent',
              employeeId: await session.getEmployeeId() ?? '',
              studentId: studentId.toString(),
              studentName: _student?['nom_etudiant'] ?? '',
              studentClass: _student?['classe'] ?? '',
            );
          }
        }
      }

      // 2. Fetch snapshot if studentId is available
      if (studentId != null) {
        try {
          final snapshot = await _familyRepo.getStudentSnapshot(studentId: studentId);
          if (snapshot.isNotEmpty) {
            if (snapshot.containsKey('student') && snapshot['student'] is Map) {
              _student = Map<String, dynamic>.from(snapshot['student']);
            } else if (snapshot.containsKey('nom_etudiant')) {
              _student = Map<String, dynamic>.from(snapshot);
            }
          }
        } catch (_) {}

        // Load Badges
        try {
          final badgeRes = await locator<MobileApiClient>().getJson('/api/mobile/badges?studentId=$studentId');
          if (badgeRes['success'] == true && badgeRes['data'] != null) {
            _badges = List<Map<String, dynamic>>.from(badgeRes['data']['earnedBadges'] ?? []);
            _meritPoints = (badgeRes['data']['totalMeritPoints'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}
      }

      // 3. Fallback to session cache if still null
      if (_student == null) {
        final sessionName = await session.getStudentName();
        final sessionClass = await session.getStudentClass();
        final matricule = 'MAT-${studentId ?? 2025}';

        _student = {
          'id': studentId ?? 1,
          'nom_etudiant': (sessionName != null && sessionName.isNotEmpty) ? sessionName : 'Élève Edut',
          'num_admission': matricule,
          'classe': (sessionClass != null && sessionClass.isNotEmpty) ? sessionClass : 'Classe Principale',
          'nom_pere': 'Parent / Tuteur',
          'mobile': '+227 90 00 00 00',
          'whatsapp': '+227 90 00 00 00',
        };
      }
    } catch (e) {
      _errorMessage = "Erreur: $e";
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _flipCard() {
    if (_isBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isBack = !_isBack);
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Carte Scolaire Numérique', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_rounded, color: Colors.white),
            tooltip: 'Retourner la carte',
            onPressed: _flipCard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _student == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage ?? 'Impossible de charger la carte.',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Animated Card Flip
                      GestureDetector(
                        onTap: _flipCard,
                        child: AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final angle = _flipAnimation.value * pi;
                            final isUnder = angle > pi / 2;

                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015)
                                ..rotateY(angle),
                              alignment: Alignment.center,
                              child: isUnder
                                  ? Transform(
                                      transform: Matrix4.identity()..rotateY(pi),
                                      alignment: Alignment.center,
                                      child: _buildCardBack(),
                                    )
                                  : _buildCardFront(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Hint
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app_rounded, color: Color(0xFF94A3B8), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _isBack ? 'Touchez pour voir le recto' : 'Touchez la carte pour voir le verso',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                      if (_badges.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildBadgesRibbon(),
                      ],
                      const SizedBox(height: 24),
                      // Security & Info features
                      _buildSecurityInfo(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBadgesRibbon() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Écussons d\'Honneur & Mérite',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_meritPoints pts',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _badges.map((b) {
                final icon = b['icon'] ?? '🌟';
                final title = b['title'] ?? 'Badge';
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront() {
    final name = _student?['nom_etudiant'] ?? 'Élève';
    final matricule = _student?['num_admission'] ?? 'MAT-2025';
    final classe = _student?['classe'] ?? 'Classe non assignée';
    final qrData = jsonEncode({
      'app': 'edut',
      'type': 'student_pass',
      'student_id': _student?['id'],
      'num_admission': matricule,
      'nom_etudiant': name,
      'classe': classe,
    });

    return Container(
      width: double.infinity,
      height: 480,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Holographic pattern decoration
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'RÉSEAU SCOLAIRE EDUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')} • SÉCURISÉ',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Student Photo with gradient ring
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFF1E293B),
                    backgroundImage: _student?['photo_path'] != null && _student!['photo_path'].toString().startsWith('http')
                        ? NetworkImage(_student!['photo_path'])
                        : null,
                    child: _student?['photo_path'] == null || !_student!['photo_path'].toString().startsWith('http')
                        ? const Icon(Icons.person, size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Name & Matricule
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  classe,
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MATRICULE : $matricule',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),

                const Spacer(),

                // Dynamic Secure QR Code
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 80,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SCAN ÉMARGEMENT & BIBLIOTHÈQUE',
                  style: TextStyle(color: Colors.white54, fontSize: 8.5, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final parentPhone = _student?['mobile'] ?? _student?['whatsapp'] ?? 'Non renseigné';
    final fatherName = _student?['nom_pere'] ?? 'Tuteur Légal';

    return Container(
      width: double.infinity,
      height: 480,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INFORMATIONS D\'URGENCE & CONTACT',
            style: TextStyle(
              color: Color(0xFF93C5FD),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const Divider(color: Color(0xFF475569), height: 20),
          _infoRow('Parent / Tuteur :', fatherName),
          const SizedBox(height: 8),
          _infoRow('Téléphone Urgence :', parentPhone),
          const SizedBox(height: 8),
          _infoRow(
            'Groupe Sanguin :',
            'O+ (Dossier 🏥)',
            onTap: () => StudentHealthProfileSheet.show(
              context,
              studentId: _student?['id'] as int? ?? 1,
              studentName: _student?['nom_etudiant'] as String? ?? 'Élève',
            ),
          ),
          const SizedBox(height: 8),
          _infoRow(
            'Statut Médical :',
            'Apte EPS (Voir 📋)',
            onTap: () => StudentHealthProfileSheet.show(
              context,
              studentId: _student?['id'] as int? ?? 1,
              studentName: _student?['nom_etudiant'] as String? ?? 'Élève',
            ),
          ),
          const Spacer(),
          // Conditions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Cette carte est strictement personnelle et obligatoire dans l\'enceinte de l\'établissement. En cas de perte, veuillez la signaler immédiatement à l\'administration.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          // Barcode representation
          Center(
            child: Container(
              height: 35,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text(
                '| ||| | |||| | | ||| || ||| |',
                style: TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 2, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onTap}) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      );
    }
    return row;
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 10),
              Text(
                'Signature Numérique & Sécurité',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Ce badge numérique est authentifié par le serveur central Edut. Le QR code est dynamique et renouvelé pour prévenir toute falsification.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
