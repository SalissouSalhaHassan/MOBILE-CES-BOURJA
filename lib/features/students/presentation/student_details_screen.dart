import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/students_repository.dart';

class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({
    super.key,
    required this.studentId,
  });

  final int studentId;

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  final StudentsRepository _repository = locator<StudentsRepository>();
  bool _isLoading = true;
  bool _canEditStudent = false;
  Map<String, dynamic>? _student;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    final student = await _repository.getStudentDetails(widget.studentId);
    if (!mounted) return;
    setState(() {
      _canEditStudent =
          profile.permissions.contains(AppPermissions.studentsEdit);
      _student = student;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Details etudiant'),
        actions: [
          if (_student != null && _canEditStudent)
            IconButton(
              onPressed: () async {
                final updated = await context.push(
                  '/students/form',
                  extra: _student,
                );
                if (updated == true) {
                  _load();
                }
              },
              icon: const Icon(Icons.edit_rounded),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _student == null
              ? Center(
                  child: Text(
                    'Etudiant introuvable',
                    style: AppTextStyles.bodyBold,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildSection(
                      'Identite',
                      [
                        _line('Admission', _student!['num_admission']),
                        _line('Nom', _student!['nom_etudiant']),
                        _line('Nom arabe', _student!['nom_arabe']),
                        _line('Sexe', _student!['sexe']),
                        _line('Religion', _student!['religion']),
                        _line('Date naissance', _student!['date_naissance']),
                        _line('Lieu naissance', _student!['lieu_naissance']),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Academique',
                      [
                        _line('Session', _student!['session']),
                        _line('Niveau', _student!['educational_level']),
                        _line('Classe', _student!['classe']),
                        _line('Section', _student!['section']),
                        _line('Categorie', _student!['categorie']),
                        _line('Statut', _student!['statut']),
                        _line('Conduite', _student!['behavior_score']),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Famille et contact',
                      [
                        _line('Tuteur', _student!['nom_pere']),
                        _line('Mobile', _student!['mobile']),
                        _line('WhatsApp', _student!['whatsapp']),
                        _line('CNIC tuteur', _student!['cnic_pere']),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Finances',
                      [
                        _line('Frais mensuels', _student!['frais_mensuels']),
                        _line('Ancien solde', _student!['ancien_solde']),
                        _line(
                          'Frais inscription',
                          _student!['frais_inscription'],
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final rawPhoto = (_student!['photo_path'] ??
            _student!['photo_url'] ??
            _student!['photo'] ??
            _student!['avatar'])
        ?.toString();

    Widget fallbackIcon() => const Icon(
          Icons.person_rounded,
          size: 34,
          color: Color(0xFF6366F1),
        );

    Widget imageWidget = fallbackIcon();
    if (rawPhoto != null && rawPhoto.trim().isNotEmpty) {
      final trimmed = rawPhoto.trim();
      if (trimmed.startsWith('data:image')) {
        try {
          imageWidget = Image.memory(
            base64Decode(trimmed.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackIcon(),
          );
        } catch (_) {}
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        imageWidget = Image.network(
          trimmed,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackIcon(),
        );
      } else if (trimmed.startsWith('/')) {
        imageWidget = Image.network(
          '${MobileApiConfig.baseUrl}$trimmed',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackIcon(),
        );
      } else {
        imageWidget = Image.network(
          '${MobileApiConfig.baseUrl}/$trimmed',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackIcon(),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageWidget,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_student!['nom_etudiant'] ?? 'Etudiant').toString(),
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_student!['educational_level'] ?? '-'} • ${_student!['classe'] ?? '-'}',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 8),
                _statusBadge((_student!['statut'] ?? 'Actif').toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _line(String label, dynamic value) {
    final text = value?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(
              (text == null || text.isEmpty) ? '-' : text,
              style: AppTextStyles.bodyBold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final active = status.toLowerCase().contains('actif');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: active ? const Color(0xFF059669) : const Color(0xFFDC2626),
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
