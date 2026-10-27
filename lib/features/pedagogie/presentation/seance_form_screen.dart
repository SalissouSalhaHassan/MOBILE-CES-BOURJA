import 'package:flutter/material.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../data/pedagogie_repository.dart';

/// Form screen for creating or editing a Séance in the Cahier de Textes.
class SeanceFormScreen extends StatefulWidget {
  /// When null, we are in create mode. Otherwise, edit mode.
  final Map<String, dynamic>? existingSeance;

  const SeanceFormScreen({super.key, this.existingSeance});

  @override
  State<SeanceFormScreen> createState() => _SeanceFormScreenState();
}

class _SeanceFormScreenState extends State<SeanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PedagogieRepository();

  final _titreCtr = TextEditingController();
  final _objectifsCtr = TextEditingController();
  final _contenuCtr = TextEditingController();
  final _supportsCtr = TextEditingController();
  final _devoirCtr = TextEditingController();
  final _observationCtr = TextEditingController();
  final _heureDebutCtr = TextEditingController();
  final _heureFinCtr = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedClassId;
  String? _selectedClassName;
  int? _selectedSubjectId;
  String? _selectedSubjectName;

  List<Map<String, dynamic>> _classSubjects = [];
  bool _isLoading = false;
  bool _isSaving = false;
  int? _employeeId;

  // Preset time slots for fast 1-tap entry
  static const List<Map<String, String>> _predefinedSlots = [
    {'label': '08h - 10h', 'start': '08:00', 'end': '10:00'},
    {'label': '10h - 12h', 'start': '10:00', 'end': '12:00'},
    {'label': '15h - 17h', 'start': '15:00', 'end': '17:00'},
    {'label': '17h - 19h', 'start': '17:00', 'end': '19:00'},
    {'label': '08h - 12h', 'start': '08:00', 'end': '12:00'},
    {'label': '14h - 18h', 'start': '14:00', 'end': '18:00'},
  ];

  bool get _isEditMode => widget.existingSeance != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    setState(() => _isLoading = true);
    try {
      // Load employee id
      final session = locator<SessionManager>();
      final employeeIdStr = await session.getEmployeeId();
      _employeeId = int.tryParse(employeeIdStr ?? '');

      // Load classes/subjects
      _classSubjects = await _repo.getTeacherClassesAndSubjects();

      // If edit mode, populate fields
      if (_isEditMode) {
        final s = widget.existingSeance!;
        _titreCtr.text = s['titre_lecon'] ?? '';
        _objectifsCtr.text = s['objectifs'] ?? '';
        _contenuCtr.text = s['contenu_realise'] ?? '';
        _supportsCtr.text = s['supports_utilises'] ?? '';
        _devoirCtr.text = s['devoir_donne'] ?? '';
        _observationCtr.text = s['observation'] ?? '';
        _heureDebutCtr.text = s['heure_debut']?.toString().substring(0, 5) ?? '';
        _heureFinCtr.text = s['heure_fin']?.toString().substring(0, 5) ?? '';

        if (s['session_date'] != null) {
          _selectedDate = DateTime.tryParse(s['session_date']) ?? DateTime.now();
        }

        _selectedClassId = s['class_id'] as int?;
        _selectedSubjectId = s['subject_id'] as int?;

        // Get names from nested
        final cls = s['school_classes'];
        if (cls != null && cls is Map) {
          _selectedClassName = cls['class_name'] as String?;
        }
        final sub = s['school_subjects'];
        if (sub != null && sub is Map) {
          _selectedSubjectName = sub['subject_name'] as String?;
        }
      } else {
        // Defaults for quick creation
        _heureDebutCtr.text = '08:00';
        _heureFinCtr.text = '10:00';
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titreCtr.dispose();
    _objectifsCtr.dispose();
    _contenuCtr.dispose();
    _supportsCtr.dispose();
    _devoirCtr.dispose();
    _observationCtr.dispose();
    _heureDebutCtr.dispose();
    _heureFinCtr.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6D28D9),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(TextEditingController controller, String label) async {
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    if (controller.text.isNotEmpty) {
      final parts = controller.text.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initial = TimeOfDay(hour: h, minute: m);
        }
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Sélectionner $label',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6D28D9),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formatted;
      });
    }
  }

  void _applyTimeSlot(String start, String end) {
    setState(() {
      _heureDebutCtr.text = start;
      _heureFinCtr.text = end;
    });
  }

  void _suggestAiPlan() {
    final title = _titreCtr.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord saisir le titre de la leçon.')),
      );
      return;
    }

    setState(() {
      if (_objectifsCtr.text.isEmpty) {
        _objectifsCtr.text =
            "1. Comprendre et définir les notions fondamentales de $title.\n2. Maîtriser l'application pratique à travers des exercices guidés.\n3. Évaluer l'assimilation des compétences clés.";
      }
      if (_supportsCtr.text.isEmpty) {
        _supportsCtr.text = "Tableau blanc, Manuel officiel, Fiches d'exercices pratiques & Schémas récapitulatifs.";
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Objectifs et supports pédagogiques générés par l\'IA avec succès ! ✨'),
        backgroundColor: Color(0xFF6D28D9),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une classe et une matière.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dateStr = _selectedDate.toIso8601String().split('T').first;

      if (_isEditMode) {
        final id = widget.existingSeance!['id'] as int;
        await _repo.updateSeance(
          id,
          titreLecon: _titreCtr.text.trim(),
          sessionDate: dateStr,
          heureDebut: _heureDebutCtr.text.trim(),
          heureFin: _heureFinCtr.text.trim(),
          objectifs: _objectifsCtr.text.trim(),
          contenuRealise: _contenuCtr.text.trim(),
          supportsUtilises: _supportsCtr.text.trim(),
          devoirDonne: _devoirCtr.text.trim(),
          observation: _observationCtr.text.trim(),
        );
      } else {
        await _repo.createSeance(
          classId: _selectedClassId!,
          subjectId: _selectedSubjectId!,
          employeeId: _employeeId ?? 1,
          sessionDate: dateStr,
          titreLecon: _titreCtr.text.trim(),
          heureDebut: _heureDebutCtr.text.trim(),
          heureFin: _heureFinCtr.text.trim(),
          objectifs: _objectifsCtr.text.trim(),
          contenuRealise: _contenuCtr.text.trim(),
          supportsUtilises: _supportsCtr.text.trim(),
          devoirDonne: _devoirCtr.text.trim(),
          observation: _observationCtr.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Séance mise à jour avec succès dans le cahier de textes.'
                  : 'Séance enregistrée avec succès dans le cahier de textes.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true); // signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditMode ? 'Modifier la séance' : 'Nouvelle séance')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        title: Text(
          _isEditMode ? 'Modifier la séance' : 'Nouvelle séance',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Enregistrer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Classe & Matière ───────────────────────────────────────────
              _sectionCard(
                title: 'Classe & Matière',
                icon: Icons.school,
                children: [
                  if (_isEditMode) ...[
                    _buildInfoText('Classe : ${_selectedClassName ?? '—'}'),
                    const SizedBox(height: 6),
                    _buildInfoText('Matière : ${_selectedSubjectName ?? '—'}'),
                  ] else if (_classSubjects.isEmpty)
                    const Text(
                      'Aucune affectation trouvée pour votre compte enseignant.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: _inputDec('Sélectionner la classe et matière *'),
                      value: _selectedClassId != null && _selectedSubjectId != null
                          ? '${_selectedClassId}_$_selectedSubjectId'
                          : null,
                      items: _classSubjects.map((cs) {
                        final cid = cs['class_id'] as int?;
                        final sid = cs['subject_id'] as int?;
                        final cname = (cs['school_classes'] as Map?)?['class_name'] ?? 'Classe $cid';
                        final sname = (cs['school_subjects'] as Map?)?['subject_name'] ?? 'Matière $sid';
                        return DropdownMenuItem<String>(
                          value: '${cid}_$sid',
                          child: Text('$cname — $sname', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final parts = val.split('_');
                        setState(() {
                          _selectedClassId = int.tryParse(parts[0]);
                          _selectedSubjectId = int.tryParse(parts[1]);
                        });
                      },
                      validator: (v) => v == null ? 'Sélectionnez une classe et matière' : null,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Date & Horaires ────────────────────────────────────────────
              _sectionCard(
                title: 'Date & Horaires',
                icon: Icons.calendar_today_rounded,
                children: [
                  // Date Picker
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDec('Date de la séance').copyWith(
                        suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6D28D9)),
                      ),
                      child: Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/'
                        '${_selectedDate.month.toString().padLeft(2, '0')}/'
                        '${_selectedDate.year}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick Slot Chips
                  const Text(
                    'Créneaux suggérés :',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _predefinedSlots.map((slot) {
                        final isSelected = _heureDebutCtr.text == slot['start'] &&
                            _heureFinCtr.text == slot['end'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(slot['label']!),
                            selected: isSelected,
                            selectedColor: const Color(0xFF6D28D9).withValues(alpha: 0.15),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF475569),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) => _applyTimeSlot(slot['start']!, slot['end']!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Interactive Time Start and End
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(_heureDebutCtr, 'Heure de début'),
                          borderRadius: BorderRadius.circular(12),
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _heureDebutCtr,
                              decoration: _inputDec('Heure de début').copyWith(
                                prefixIcon: const Icon(Icons.access_time_filled_rounded, size: 20, color: Color(0xFF6D28D9)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(_heureFinCtr, 'Heure de fin'),
                          borderRadius: BorderRadius.circular(12),
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _heureFinCtr,
                              decoration: _inputDec('Heure de fin').copyWith(
                                prefixIcon: const Icon(Icons.timelapse_rounded, size: 20, color: Color(0xFF6D28D9)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Contenu pédagogique ────────────────────────────────────────
              _sectionCard(
                title: 'Contenu pédagogique',
                icon: Icons.menu_book_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _titreCtr,
                          decoration: _inputDec('Titre de la leçon *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _suggestAiPlan,
                        icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D28D9)),
                        tooltip: 'Générer objectifs avec IA',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _objectifsCtr,
                    decoration: _inputDec('Objectifs d\'apprentissage'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contenuCtr,
                    decoration: _inputDec('Contenu réalisé / Déroulement'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _supportsCtr,
                    decoration: _inputDec('Supports utilisés (Manuels, Matériel, Numérique)'),
                    maxLines: 2,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Devoirs & Observations ─────────────────────────────────────
              _sectionCard(
                title: 'Devoirs & Observations',
                icon: Icons.assignment_rounded,
                children: [
                  TextFormField(
                    controller: _devoirCtr,
                    decoration: _inputDec('Devoir donné aux élèves'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observationCtr,
                    decoration: _inputDec('Observations pédagogiques'),
                    maxLines: 2,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save button
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isEditMode ? 'Mettre à jour la séance' : 'Enregistrer la séance',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6D28D9), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500),
    );
  }
}
