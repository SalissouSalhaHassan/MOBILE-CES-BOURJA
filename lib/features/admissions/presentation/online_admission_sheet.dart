import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/di/injection.dart';
import '../data/admissions_repository.dart';

class FacultyData {
  final String name;
  final IconData icon;
  final List<String> departments;
  final List<String> programs;

  const FacultyData({
    required this.name,
    required this.icon,
    required this.departments,
    required this.programs,
  });
}

class OnlineAdmissionSheet extends StatefulWidget {
  final String? defaultParentPhone;

  const OnlineAdmissionSheet({
    super.key,
    this.defaultParentPhone,
  });

  static Future<void> show(
    BuildContext context, {
    String? defaultParentPhone,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OnlineAdmissionSheet(
        defaultParentPhone: defaultParentPhone,
      ),
    );
  }

  @override
  State<OnlineAdmissionSheet> createState() => _OnlineAdmissionSheetState();
}

class _OnlineAdmissionSheetState extends State<OnlineAdmissionSheet> {
  final AdmissionsRepository _repository = locator<AdmissionsRepository>();
  final ImagePicker _imagePicker = ImagePicker();

  int _selectedTabIndex = 0; // 0: Nouvelle Candidature, 1: Suivi Dossier

  // Pathway: 'university' or 'general'
  String _pathway = 'university';

  // Form Fields
  final _formKey = GlobalKey<FormState>();

  // Student Identity
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _placeOfBirthController = TextEditingController(text: 'Niamey');
  final _nationalityController = TextEditingController(text: 'Nigérienne');
  final _candidatePhoneController = TextEditingController();
  final _candidateWhatsappController = TextEditingController();
  final _candidateEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Niamey');
  String _gender = 'M';

  // University Track Specifics
  int _selectedFacultyIndex = 0;
  String _selectedDepartment = "Informatique & Génie Logiciel";
  String _selectedProgram = "Licence Informatique & Génie Logiciel (L1-L3)";
  String _degreeLevel = 'Licence 1';
  String _studyMode = 'Présentiel / Temps plein';
  final String _academicYear = '2026–2027';

  // School Track Specifics
  String _targetSchoolClass = '6ème A';

  // Baccalaureate & Academic Background
  String _bacSeries = 'Série D';
  String _bacYear = '2026';
  String _bacMention = 'Bien';
  final _bacRollNumberController = TextEditingController();
  final _previousSchoolController = TextEditingController();
  final _previousGradeAvgController = TextEditingController();

  // Sponsor / Parent / Guardian
  final _parentNameController = TextEditingController();
  String _parentRelation = 'Père';
  final _parentPhoneController = TextEditingController();
  final _parentWhatsappController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _parentProfessionController = TextEditingController();

  // Documents & Notes
  String? _photoBase64;
  String? _idCardBase64;
  String? _bacTranscriptBase64;
  String? _bacCertificateBase64;
  String? _higherEdTranscriptBase64;
  String? _cvBase64;
  final _medicalNotesController = TextEditingController();
  bool _honorDeclaration = true;

  // Form state
  bool _isSubmitting = false;
  Map<String, dynamic>? _successResult;

  // Tracking List
  final _trackingQueryController = TextEditingController();
  bool _isLoadingTracking = false;
  List<Map<String, dynamic>> _trackedApplications = [];

  // University Faculties Data
  final List<FacultyData> _faculties = const [
    FacultyData(
      name: "Faculté des Sciences & Technologies",
      icon: Icons.computer_rounded,
      departments: [
        "Informatique & Génie Logiciel",
        "Réseaux & Télécoms",
        "Génie Civil & Architecture",
        "Mathématiques & IA"
      ],
      programs: [
        "Licence Informatique & Génie Logiciel (L1-L3)",
        "Licence Réseaux, Systèmes & Cybersécurité (L1-L3)",
        "Licence Génie Civil & BTP (L1-L3)",
        "Master Big Data, IA & Cloud Computing (M1-M2)",
        "Master Ingénierie Logicielle & Systèmes Distribués (M1-M2)",
        "Doctorat en Sciences & Technologies de l'Information",
      ],
    ),
    FacultyData(
      name: "Faculté des Sciences Économiques & de Gestion",
      icon: Icons.account_balance_wallet_rounded,
      departments: [
        "Finance & Comptabilité",
        "Management & RH",
        "Marketing & Commerce International",
        "Banque & Microfinance"
      ],
      programs: [
        "Licence Comptabilité, Contrôle & Audit (L1-L3)",
        "Licence Gestion des Entreprises & Administration (L1-L3)",
        "Licence Marketing Digital & E-Commerce (L1-L3)",
        "Master Banque, Finance & Marchés (M1-M2)",
        "Master Management Stratégique & Gestion de Projets (M1-M2)",
        "Doctorat en Sciences de Gestion",
      ],
    ),
    FacultyData(
      name: "Faculté des Sciences Juridiques & Politiques",
      icon: Icons.gavel_rounded,
      departments: [
        "Droit Privé & des Affaires",
        "Droit Public & Relations Internationales",
        "Sciences Politiques"
      ],
      programs: [
        "Licence en Droit Privé des Affaires (L1-L3)",
        "Licence en Droit Public & Carrières Juridiques (L1-L3)",
        "Master Droit Minier, Pétrolier & Énergies (M1-M2)",
        "Master Diplomatie & Coopération Internationale (M1-M2)",
      ],
    ),
    FacultyData(
      name: "Faculté des Sciences de la Santé & Médicales",
      icon: Icons.medical_services_rounded,
      departments: [
        "Médecine Générale",
        "Pharmacie",
        "Sciences Infirmières & Obstétricales",
        "Santé Publique"
      ],
      programs: [
        "Doctorat d'État en Médecine Générale",
        "Licence en Sciences Infirmières (L1-L3)",
        "Licence Sage-Femme / Maïeutique (L1-L3)",
        "Master en Santé Publique & Épidémiologie (M1-M2)",
      ],
    ),
    FacultyData(
      name: "École Supérieure de Communication & Journalisme",
      icon: Icons.newspaper_rounded,
      departments: [
        "Journalisme & Médias",
        "Communication d'Entreprise & Relations Publiques"
      ],
      programs: [
        "Licence Journalisme Multimédia (L1-L3)",
        "Licence Communication & Relations Publiques (L1-L3)",
        "Master Communication Digitale & Médias Sociaux (M1-M2)",
      ],
    ),
  ];

  final List<String> _degreeLevels = const [
    'Licence 1',
    'Licence 2',
    'Licence 3',
    'Master 1',
    'Master 2',
    'Doctorat',
    'BTS / DUTS'
  ];

  final List<String> _studyModes = const [
    'Présentiel / Temps plein',
    'Cours du soir / Professionnel',
    'Formation en ligne / Distanciel',
    'Alternance / Stage',
  ];

  final List<String> _schoolClasses = const [
    'CI', 'CP', 'CE1', 'CE2', 'CM1', 'CM2',
    '6ème A', '6ème B', '5ème A', '5ème B', '4ème A', '4ème B', '3ème A', '3ème B',
    '2nde C', '2nde A', '1ère D', '1ère C', '1ère A', 'Terminale D', 'Terminale C', 'Terminale A', 'Terminale F4', 'Terminale G2'
  ];

  final List<String> _bacSeriesList = const [
    'Série D (Scientifique)',
    'Série C (Maths & Sciences)',
    'Série A4 (Littéraire)',
    'Série E (Maths & Technique)',
    'Série F4 (Génie Civil)',
    'Série G2 (Gestion & Compta)',
    'Bac Professionnel',
    'Autre diplôme équivalent',
    'En cours d\'obtention (Terminale)',
  ];

  final List<String> _bacYears = const [
    '2026', '2025', '2024', '2023', '2022', '2021', '2020', '2019 ou antérieur'
  ];

  final List<String> _bacMentions = const [
    'Très Bien (≥ 16/20)',
    'Bien (14 - 15.99/20)',
    'Assez Bien (12 - 13.99/20)',
    'Passable (10 - 11.99/20)',
    'En attente des résultats',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.defaultParentPhone != null) {
      _parentPhoneController.text = widget.defaultParentPhone!;
      _trackingQueryController.text = widget.defaultParentPhone!;
      _loadTrackedApplications();
    }
    _syncFacultySelections(0);
  }

  void _syncFacultySelections(int index) {
    setState(() {
      _selectedFacultyIndex = index;
      final fac = _faculties[index];
      _selectedDepartment = fac.departments.first;
      _selectedProgram = fac.programs.first;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _placeOfBirthController.dispose();
    _nationalityController.dispose();
    _candidatePhoneController.dispose();
    _candidateWhatsappController.dispose();
    _candidateEmailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _bacRollNumberController.dispose();
    _previousSchoolController.dispose();
    _previousGradeAvgController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentWhatsappController.dispose();
    _parentEmailController.dispose();
    _parentProfessionController.dispose();
    _medicalNotesController.dispose();
    _trackingQueryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(String base64) onSelected, {ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          onSelected(base64String);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Document joint avec succès !"),
              backgroundColor: Color(0xFF059669),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 18));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitAdmission() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir les champs obligatoires (*)"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_honorDeclaration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez certifier sur l'honneur l'exactitude des renseignements."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final isUniv = _pathway == 'university';
    final targetClass = isUniv ? _selectedProgram : _targetSchoolClass;
    final educationLevel = isUniv ? 'Université / Supérieur' : 'Cycle Scolaire / Secondaire';

    final res = await _repository.submitApplication(
      studentFirstName: _firstNameController.text.trim(),
      studentLastName: _lastNameController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      gender: _gender,
      placeOfBirth: _placeOfBirthController.text.trim(),
      nationality: _nationalityController.text.trim(),
      educationLevel: educationLevel,
      faculty: isUniv ? _faculties[_selectedFacultyIndex].name : null,
      department: isUniv ? _selectedDepartment : null,
      degreeProgram: isUniv ? _selectedProgram : targetClass,
      degreeLevel: isUniv ? _degreeLevel : null,
      studyMode: isUniv ? _studyMode : null,
      academicYear: _academicYear,
      targetClass: targetClass,
      candidateEmail: _candidateEmailController.text.trim().isNotEmpty ? _candidateEmailController.text.trim() : null,
      candidatePhone: _candidatePhoneController.text.trim().isNotEmpty ? _candidatePhoneController.text.trim() : null,
      candidateWhatsapp: _candidateWhatsappController.text.trim().isNotEmpty ? _candidateWhatsappController.text.trim() : null,
      bacSeries: _bacSeries,
      bacYear: _bacYear,
      bacMention: _bacMention,
      bacRollNumber: _bacRollNumberController.text.trim().isNotEmpty ? _bacRollNumberController.text.trim() : null,
      previousSchool: _previousSchoolController.text.trim().isNotEmpty ? _previousSchoolController.text.trim() : null,
      previousGradeAvg: _previousGradeAvgController.text.trim().isNotEmpty ? _previousGradeAvgController.text.trim() : null,
      parentName: _parentNameController.text.trim(),
      parentRelation: _parentRelation,
      parentPhone: _parentPhoneController.text.trim().isNotEmpty ? _parentPhoneController.text.trim() : _candidatePhoneController.text.trim(),
      parentWhatsapp: _parentWhatsappController.text.trim().isNotEmpty ? _parentWhatsappController.text.trim() : null,
      parentEmail: _parentEmailController.text.trim().isNotEmpty ? _parentEmailController.text.trim() : null,
      parentProfession: _parentProfessionController.text.trim().isNotEmpty ? _parentProfessionController.text.trim() : null,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      city: _cityController.text.trim(),
      medicalNotes: _medicalNotesController.text.trim().isNotEmpty ? _medicalNotesController.text.trim() : null,
      photoUrl: _photoBase64,
      idCardPassportUrl: _idCardBase64,
      bacTranscriptUrl: _bacTranscriptBase64,
      bacCertificateUrl: _bacCertificateBase64,
      higherEdTranscriptUrl: _higherEdTranscriptBase64,
      cvUrl: _cvBase64,
    );

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      setState(() {
        _successResult = {
          'applicationNumber': res['applicationNumber'] ?? 'ADM-2026',
          'studentName': "${_lastNameController.text.trim().toUpperCase()} ${_firstNameController.text.trim()}",
          'program': isUniv ? _selectedProgram : _targetSchoolClass,
          'faculty': isUniv ? _faculties[_selectedFacultyIndex].name : 'Cycle Scolaire',
          'academicYear': _academicYear,
          'phone': _candidatePhoneController.text.trim().isNotEmpty ? _candidatePhoneController.text.trim() : _parentPhoneController.text.trim(),
        };
      });
      _trackingQueryController.text = _parentPhoneController.text.trim().isNotEmpty ? _parentPhoneController.text.trim() : _candidatePhoneController.text.trim();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Erreur lors de la soumission.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTrackedApplications() async {
    final query = _trackingQueryController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoadingTracking = true);

    // If query starts with UNIV- or ADM-, search by applicationNumber, else search by phone
    final isAppNumber = query.toUpperCase().startsWith('UNIV-') || query.toUpperCase().startsWith('ADM-');
    final list = await _repository.checkApplicationStatus(
      phone: isAppNumber ? null : query,
      applicationNumber: isAppNumber ? query : null,
    );

    if (mounted) {
      setState(() {
        _trackedApplications = list;
        _isLoadingTracking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            "Inscriptions & Admissions",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text("🇳🇪", style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      Text(
                        _pathway == 'university'
                            ? "Pôle Universitaire (LMD) • Année 2026–2027"
                            : "Cycle Scolaire Général • Collège & Lycée",
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          // Main Tabs (Nouvelle Candidature vs Suivi des Dossiers)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedTabIndex == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_document,
                            size: 16,
                            color: _selectedTabIndex == 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Nouvelle Candidature",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedTabIndex == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedTabIndex = 1);
                      _loadTrackedApplications();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedTabIndex == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 16,
                            color: _selectedTabIndex == 1 ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Suivi du Dossier",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedTabIndex == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content Body
          Expanded(
            child: _selectedTabIndex == 0
                ? (_successResult != null ? _buildSuccessReceipt() : _buildApplicationForm())
                : _buildTrackingView(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. APPLICATION FORM (Matching Web Experience)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildApplicationForm() {
    final activeFaculty = _faculties[_selectedFacultyIndex];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Pathway Switcher (Université LMD vs Cycle Scolaire)
          _buildPathwaySelector(),
          const SizedBox(height: 16),

          // SECTION 1: Choix de la formation
          _buildCardSection(
            stepNumber: "1",
            title: _pathway == 'university' ? "Filière & Faculté (LMD)" : "Niveau & Classe Demandée",
            subtitle: "Sélectionnez votre cursus d'admission 2026–2027",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pathway == 'university') ...[
                  // Faculty Selector
                  const Text("Faculté / Établissement *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedFacultyIndex,
                        items: List.generate(_faculties.length, (idx) {
                          return DropdownMenuItem<int>(
                            value: idx,
                            child: Row(
                              children: [
                                Icon(_faculties[idx].icon, size: 18, color: const Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _faculties[idx].name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        onChanged: (idx) {
                          if (idx != null) _syncFacultySelections(idx);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Department Selector
                  const Text("Département d'affiliation *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: activeFaculty.departments.contains(_selectedDepartment) ? _selectedDepartment : activeFaculty.departments.first,
                        items: activeFaculty.departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDepartment = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Degree Program (Filière)
                  const Text("Filière & Programme d'études *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF059669)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: activeFaculty.programs.contains(_selectedProgram) ? _selectedProgram : activeFaculty.programs.first,
                        items: activeFaculty.programs.map((prog) {
                          return DropdownMenuItem(
                            value: prog,
                            child: Text(
                              prog,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedProgram = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Degree Level & Study Mode
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Cycle / Niveau *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _degreeLevel,
                                  items: _degreeLevels.map((lvl) {
                                    return DropdownMenuItem(value: lvl, child: Text(lvl, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _degreeLevel = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Mode d'études *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _studyMode,
                                  items: _studyModes.map((mode) {
                                    return DropdownMenuItem(
                                      value: mode,
                                      child: Text(
                                        mode.split(' / ').first,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _studyMode = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // School Class Selector
                  const Text("Classe demandée (Collège / Lycée / Primaire) *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _targetSchoolClass,
                        items: _schoolClasses.map((cls) {
                          return DropdownMenuItem(value: cls, child: Text(cls, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _targetSchoolClass = val);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 2: Identité de l'Étudiant(e) / Élève
          _buildCardSection(
            stepNumber: "2",
            title: "Identité & État Civil du Candidat",
            subtitle: "Renseignez les informations officielles d'état civil",
            child: Column(
              children: [
                // Photo Identity Picker
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showPhotoOptionSheet(),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF10B981), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _photoBase64 != null
                              ? ClipOval(
                                  child: Image.memory(
                                    base64Decode(_photoBase64!.split(',').last),
                                    fit: BoxFit.cover,
                                    width: 84,
                                    height: 84,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_rounded, color: Color(0xFF059669), size: 28),
                                    SizedBox(height: 2),
                                    Text("Photo d'id.", style: TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _photoBase64 != null ? "Photo enregistrée ✓ (Appuyez pour changer)" : "Ajouter une photo d'identité récente",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _photoBase64 != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Last Name & First Name
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputDecoration("Nom de famille *", hint: "ex: HASSAN"),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration("Prénom(s) *", hint: "ex: Salissou"),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // DOB & Gender
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _selectDateOfBirth,
                        decoration: _inputDecoration(
                          "Date de naissance *",
                          hint: "AAAA-MM-JJ",
                          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF059669)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _gender,
                            items: const [
                              DropdownMenuItem(value: 'M', child: Text("Masculin", style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'F', child: Text("Féminin", style: TextStyle(fontSize: 12.5))),
                            ],
                            onChanged: (v) => setState(() => _gender = v ?? 'M'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Place of Birth & Nationality
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _placeOfBirthController,
                        decoration: _inputDecoration("Lieu de naissance", hint: "ex: Niamey"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _nationalityController,
                        decoration: _inputDecoration("Nationalité", hint: "ex: Nigérienne"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Candidate Contacts
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _candidatePhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration("Tél. direct candidat", hint: "+227 90 00 00 00"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _candidateWhatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration("WhatsApp direct", hint: "+227 90 00 00 00"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _candidateEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration("Email de l'étudiant", hint: "candidat@email.com"),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _addressController,
                        decoration: _inputDecoration("Adresse / Quartier", hint: "ex: Plateau"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: _inputDecoration("Ville", hint: "Niamey"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 3: Parcours Baccalauréat & Académique
          _buildCardSection(
            stepNumber: "3",
            title: "Cursus Antérieur & Baccalauréat",
            subtitle: "Informations sur vos études secondaires et diplômes",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Série du Baccalauréat *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _bacSeries,
                      items: _bacSeriesList.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _bacSeries = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Année du Bac *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _bacYear,
                                items: _bacYears.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12.5)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _bacYear = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Mention obtenue", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _bacMention,
                                items: _bacMentions.map((m) => DropdownMenuItem(value: m, child: Text(m.split(' (').first, style: const TextStyle(fontSize: 12.5)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _bacMention = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bacRollNumberController,
                        decoration: _inputDecoration("N° Table / Matricule Bac", hint: "ex: 12345-BAC"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _previousGradeAvgController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration("Moyenne générale", hint: "ex: 13.50 / 20"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _previousSchoolController,
                  decoration: _inputDecoration("Lycée / Université d'origine", hint: "ex: Lycée Privé Korombé / Univ. Niamey"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 4: Pièces Jointes & Documents
          _buildCardSection(
            stepNumber: "4",
            title: "Pièces Justificatives Numérisées",
            subtitle: "Prenez en photo ou joignez vos diplômes et justificatifs",
            child: Column(
              children: [
                _buildDocumentTile(
                  icon: Icons.badge_rounded,
                  title: "Pièce d'identité / Acte de naissance",
                  description: "CNI, Passeport valide ou volet d'acte",
                  isUploaded: _idCardBase64 != null,
                  onTap: () => _pickImage((b64) => _idCardBase64 = b64),
                ),
                const SizedBox(height: 8),
                _buildDocumentTile(
                  icon: Icons.description_rounded,
                  title: "Relevé de notes du Baccalauréat",
                  description: "Notes officielles avec cachet de l'Office du Bac",
                  isUploaded: _bacTranscriptBase64 != null,
                  onTap: () => _pickImage((b64) => _bacTranscriptBase64 = b64),
                ),
                const SizedBox(height: 8),
                _buildDocumentTile(
                  icon: Icons.workspace_premium_rounded,
                  title: "Attestation / Diplôme du Bac",
                  description: "Certificat de réussite au Baccalauréat",
                  isUploaded: _bacCertificateBase64 != null,
                  onTap: () => _pickImage((b64) => _bacCertificateBase64 = b64),
                ),
                if (_pathway == 'university') ...[
                  const SizedBox(height: 8),
                  _buildDocumentTile(
                    icon: Icons.history_edu_rounded,
                    title: "Relevés universitaires antérieurs",
                    description: "Requis si inscription en L2, L3 ou Master",
                    isUploaded: _higherEdTranscriptBase64 != null,
                    onTap: () => _pickImage((b64) => _higherEdTranscriptBase64 = b64),
                  ),
                  const SizedBox(height: 8),
                  _buildDocumentTile(
                    icon: Icons.file_present_rounded,
                    title: "Curriculum Vitae (CV)",
                    description: "Parcours académique & stages (recommandé en Master)",
                    isUploaded: _cvBase64 != null,
                    onTap: () => _pickImage((b64) => _cvBase64 = b64),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 5: Responsable Légal & Déclaration
          _buildCardSection(
            stepNumber: "5",
            title: "Responsable Légal & Répondant",
            subtitle: "Coordonnées de la personne à contacter pour le suivi",
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _parentNameController,
                        decoration: _inputDecoration("Nom complet du Responsable *", hint: "ex: Amadou HASSAN"),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _parentRelation,
                            items: const [
                              DropdownMenuItem(value: 'Père', child: Text("Père", style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'Mère', child: Text("Mère", style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'Tuteur Légal', child: Text("Tuteur", style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'Employeur / Sponsor', child: Text("Sponsor", style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'Candidat Autonome', child: Text("Autonome", style: TextStyle(fontSize: 12.5))),
                            ],
                            onChanged: (v) => setState(() => _parentRelation = v ?? 'Père'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _parentPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration("Téléphone Responsable *", hint: "+227 90 00 00 00"),
                        validator: (v) {
                          if (_candidatePhoneController.text.trim().isNotEmpty) return null;
                          return v == null || v.trim().isEmpty ? 'Contact requis' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _parentWhatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration(
                          "WhatsApp Responsable",
                          hint: "+227 90 00 00 00",
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF059669)),
                            tooltip: "Copier le numéro",
                            onPressed: () {
                              setState(() {
                                _parentWhatsappController.text = _parentPhoneController.text.trim();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _parentProfessionController,
                        decoration: _inputDecoration("Profession", hint: "ex: Cadre d'entreprise"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _parentEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration("Email", hint: "tuteur@email.com"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _medicalNotesController,
                  decoration: _inputDecoration("Remarques particulières ou santé", hint: "Allergies, groupe sanguin, besoin spécifique..."),
                ),
                const SizedBox(height: 14),

                // Déclaration sur l'honneur
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _honorDeclaration,
                        activeColor: const Color(0xFF059669),
                        onChanged: (val) => setState(() => _honorDeclaration = val ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          "Je certifie sur l'honneur l'exactitude des renseignements fournis ci-dessus et je m'engage à fournir les originaux lors de la rentrée solennelle.",
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SUBMIT BUTTON
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAdmission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Enregistrement en cours...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text("Soumettre ma candidature officielle 🚀", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PATHWAY TOGGLE (UNIVERSITE vs CYCLE SCOLAIRE)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPathwaySelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _pathway = 'university'),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _pathway == 'university' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _pathway == 'university'
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 16,
                      color: _pathway == 'university' ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Supérieur (LMD)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _pathway == 'university' ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _pathway = 'general'),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _pathway == 'general' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _pathway == 'general'
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 16,
                      color: _pathway == 'general' ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Scolaire Général",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _pathway == 'general' ? const Color(0xFF059669) : const Color(0xFF64748B),
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

  // ─────────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCardSection({
    required String stepNumber,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDocumentTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUploaded ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUploaded ? const Color(0xFFDCFCE7) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUploaded ? Icons.check_circle_rounded : icon,
              color: isUploaded ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isUploaded ? const Color(0xFF166534) : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  isUploaded ? "Document numérisé et prêt ✓" : description,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isUploaded ? const Color(0xFF15803D) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded ? const Color(0xFF16A34A) : Colors.white,
              foregroundColor: isUploaded ? Colors.white : const Color(0xFF0F172A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: isUploaded ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isUploaded ? "Remplacer" : "Joindre",
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Photo d'identité du candidat", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF059669)),
                title: const Text("Prendre une photo instantanée"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage((b64) => _photoBase64 = b64, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF059669)),
                title: const Text("Choisir depuis la galerie"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage((b64) => _photoBase64 = b64, source: ImageSource.gallery);
                },
              ),
              if (_photoBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text("Supprimer la photo", style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _photoBase64 = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. SUCCESS RECEIPT (Matching Web Admission Receipt with QR Code)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSuccessReceipt() {
    final appNumber = _successResult!['applicationNumber']?.toString() ?? 'ADM-2026';
    final studentName = _successResult!['studentName']?.toString() ?? '';
    final program = _successResult!['program']?.toString() ?? '';
    final faculty = _successResult!['faculty']?.toString() ?? '';
    final phone = _successResult!['phone']?.toString() ?? '';

    final qrPayload = "EDUT-ADMISSION:$appNumber:$studentName:$program:2026-2027";

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Success Pill
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
          ),
        ),
        const SizedBox(height: 14),

        const Center(
          child: Text(
            "Candidature Enregistrée ! 🎉",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            "Votre dossier officiel d'admission a été transmis au jury d'admission.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 20),

        // Official Receipt Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header of receipt
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("RÉCÉPISSÉ D'ADMISSION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF059669))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("En attente d'examen", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Application Number Highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Text("NUMÉRO DE DOSSIER OFFICIEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    SelectableText(
                      appNumber,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Official QR Code
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 130,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text("Scannez pour authentifier ou suivre le dossier", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // Summary fields
              _receiptRow("Candidat", studentName),
              _receiptRow("Cursus", program),
              _receiptRow("Établissement", faculty),
              _receiptRow("Année Académique", "2026–2027"),
              _receiptRow("Contact de suivi", phone),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: appNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Numéro de dossier copié dans le presse-papier !"),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text("Copier le N°"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 1;
                    _trackingQueryController.text = appNumber;
                  });
                  _loadTrackedApplications();
                },
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text("Suivre mon dossier"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: () {
            setState(() {
              _successResult = null;
              _firstNameController.clear();
              _lastNameController.clear();
              _dobController.clear();
              _candidatePhoneController.clear();
              _photoBase64 = null;
              _idCardBase64 = null;
              _bacTranscriptBase64 = null;
              _bacCertificateBase64 = null;
            });
          },
          child: const Text("Déposer une autre candidature", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. TRACKING VIEW (Matching Web Application Tracker)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTrackingView() {
    return Column(
      children: [
        // Search Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _trackingQueryController,
                  decoration: InputDecoration(
                    labelText: "Numéro de téléphone ou dossier",
                    hintText: "+227 90... ou UNIV-2026-...",
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8)),
                  ),
                  onFieldSubmitted: (_) => _loadTrackedApplications(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadTrackedApplications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List of tracked applications
        Expanded(
          child: _isLoadingTracking
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
              : _trackedApplications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.folder_open_rounded, size: 40, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Aucun dossier trouvé",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Saisissez le numéro de téléphone utilisé lors du dépôt ou le numéro de dossier (ex: UNIV-2026-... ou ADM-2026-...).",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trackedApplications.length,
                      itemBuilder: (context, index) {
                        final app = _trackedApplications[index];
                        final status = app['status']?.toString() ?? 'En attente';
                        final matricule = app['generated_matricule'] ?? app['generatedMatricule'];
                        final appNumber = app['application_number'] ?? app['applicationNumber'] ?? 'Dossier';
                        final firstName = app['student_first_name'] ?? app['studentFirstName'] ?? '';
                        final lastName = app['student_last_name'] ?? app['studentLastName'] ?? '';
                        final program = app['degree_program'] ?? app['degreeProgram'] ?? app['target_class'] ?? app['targetClass'] ?? '';
                        final faculty = app['faculty']?.toString() ?? '';

                        final isAccepted = status == 'Admis / Accepté' || status == 'Admis sous condition';
                        final isRejected = status == 'Refusé';

                        Color badgeBg = const Color(0xFFFEF3C7);
                        Color badgeFg = const Color(0xFFD97706);
                        if (isAccepted) {
                          badgeBg = const Color(0xFFDCFCE7);
                          badgeFg = const Color(0xFF16A34A);
                        } else if (isRejected) {
                          badgeBg = const Color(0xFFFEE2E2);
                          badgeFg = const Color(0xFFDC2626);
                        } else if (status == 'En examen') {
                          badgeBg = const Color(0xFFDBEAFE);
                          badgeFg = const Color(0xFF2563EB);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isAccepted ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isAccepted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.folder_special_rounded, size: 16, color: Color(0xFF059669)),
                                      const SizedBox(width: 6),
                                      Text(
                                        appNumber,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: badgeFg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Text(
                                "$lastName $firstName",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                faculty.isNotEmpty ? "$program • $faculty" : program,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),

                              if (matricule != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("MATRICULE ÉTUDIANT ATTRIBUÉ", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                            SelectableText(
                                              matricule.toString(),
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF065F46)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
