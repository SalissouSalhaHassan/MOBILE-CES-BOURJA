import 'package:flutter/material.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SchoolClinicScreen extends StatefulWidget {
  const SchoolClinicScreen({super.key});

  @override
  State<SchoolClinicScreen> createState() => _SchoolClinicScreenState();
}

class _SchoolClinicScreenState extends State<SchoolClinicScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController(text: "Moussa Ibrahim");
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController(text: "37.5");

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _visits = [];
  String _selectedStatus = "Retour en classe";
  final List<String> _selectedSymptoms = [];

  final List<String> _symptomsList = [
    "Fièvre",
    "Maux de tête",
    "Maux de ventre",
    "Blessure sportive",
    "Nausées / Vomissements",
    "Crise d'asthme",
    "Vertiges / Malaise",
    "Piqûre / Allergie",
  ];

  @override
  void initState() {
    super.initState();
    _loadClinicData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _studentNameController.dispose();
    _reasonController.dispose();
    _treatmentController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  Future<void> _loadClinicData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson('/api/mobile/health');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _visits = List<Map<String, dynamic>>.from(res['data']['visits'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewVisitDialog() {
    _reasonController.clear();
    _treatmentController.clear();
    _selectedSymptoms.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.local_hospital_rounded, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text("Nouveau Passage Infirmerie", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _studentNameController,
                        decoration: const InputDecoration(
                          labelText: "Nom de l'élève & Classe",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _temperatureController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Température (°C)",
                                suffixText: "°C",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: "Décision",
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Retour en classe", child: Text("Retour classe", style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: "Sous observation", child: Text("Observation", style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: "Évacué / Renvoyé à domicile", child: Text("Renvoyé maison", style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) => setDialogState(() => _selectedStatus = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text("Symptômes observés :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _symptomsList.map((s) {
                          final isSel = _selectedSymptoms.contains(s);
                          return FilterChip(
                            label: Text(s, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.slate700)),
                            selected: isSel,
                            selectedColor: const Color(0xFFEF4444),
                            onSelected: (sel) {
                              setDialogState(() {
                                if (sel) {
                                  _selectedSymptoms.add(s);
                                } else {
                                  _selectedSymptoms.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: "Motif / Description",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _treatmentController,
                        decoration: const InputDecoration(
                          labelText: "Soins / Médicaments administrés",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => _isSubmitting = true);
                          await _apiClient.postJson('/api/mobile/health', {
                            'studentId': 1,
                            'studentName': _studentNameController.text.trim(),
                            'className': '3ème A',
                            'reason': _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : 'Consultation infirmerie',
                            'symptoms': _selectedSymptoms.isNotEmpty ? _selectedSymptoms : ['Consultation générale'],
                            'treatment': _treatmentController.text.trim().isNotEmpty ? _treatmentController.text.trim() : 'Repos & surveillance',
                            'temperature': '${_temperatureController.text.trim()}°C',
                            'status': _selectedStatus,
                          });
                          setDialogState(() => _isSubmitting = false);
                          if (mounted) {
                            Navigator.pop(context);
                            _loadClinicData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Consultation enregistrée et alerte envoyée au parent ! 🏥"),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  child: const Text("Enregistrer & Alerter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Infirmerie & Santé Scolaire", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Suivi médical & registre des consultations", style: TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewVisitDialog,
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Nouvelle Consultation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadClinicData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI Overview
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard("Visites du Jour", "${_visits.length}", Icons.health_and_safety_rounded, const Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard("Alertes Parents", "${_visits.length}", Icons.notification_important_rounded, const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Registre des Passages Récent :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  ..._visits.map((v) => _buildVisitCard(v)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> v) {
    final name = v['studentName'] ?? 'Élève';
    final cls = v['className'] ?? 'Classe';
    final reason = v['reason'] ?? 'Consultation';
    final treatment = v['treatment'] ?? 'Soins';
    final temp = v['temperature'] ?? '37.0°C';
    final status = v['status'] ?? 'Retour en classe';
    final symptoms = (v['symptoms'] as List?)?.join(', ') ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$name ($cls)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Temp: $temp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Motif : $reason', style: const TextStyle(fontSize: 12, color: AppColors.slate700, fontWeight: FontWeight.w600)),
          if (symptoms.isNotEmpty)
            Text('Symptômes : $symptoms', style: const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
          Text('Soins : $treatment', style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Statut : $status', style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold)),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 4),
                  Text('Parent notifié', style: TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
