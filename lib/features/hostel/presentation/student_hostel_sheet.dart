import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../data/hostel_repository.dart';

class StudentHostelSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String? studentClass;

  const StudentHostelSheet({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentClass,
  });

  static Future<void> show(
    BuildContext context, {
    required int studentId,
    required String studentName,
    String? studentClass,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentHostelSheet(
        studentId: studentId,
        studentName: studentName,
        studentClass: studentClass,
      ),
    );
  }

  @override
  State<StudentHostelSheet> createState() => _StudentHostelSheetState();
}

class _StudentHostelSheetState extends State<StudentHostelSheet> {
  final HostelRepository _repository = locator<HostelRepository>();

  bool _isLoading = true;
  bool _isBoarder = false;
  Map<String, dynamic>? _allocation;
  List<dynamic> _roommates = [];
  List<dynamic> _nightAttendance = [];
  List<dynamic> _exitPermissions = [];

  // Form Exit Pass State
  bool _showExitPassForm = false;
  bool _isSubmittingPass = false;
  final _reasonController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  String _permissionType = 'Sortie weekend';
  String _departureDate = DateTime.now().toIso8601String().substring(0, 10);
  String _returnDate = DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadHostelData();
  }

  Future<void> _loadHostelData() async {
    setState(() => _isLoading = true);
    final res = await _repository.getStudentHostelDetails(widget.studentId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isBoarder = res['isBoarder'] == true;
        _allocation = res['allocation'];
        _roommates = res['roommates'] ?? [];
        _nightAttendance = res['nightAttendance'] ?? [];
        _exitPermissions = res['exitPermissions'] ?? [];
      });
    }
  }

  Future<void> _submitExitPass() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez motiver la demande de sortie.')),
      );
      return;
    }

    setState(() => _isSubmittingPass = true);
    final res = await _repository.applyExitPermission(
      studentId: widget.studentId,
      permissionType: _permissionType,
      departureDate: _departureDate,
      returnDateExpected: _returnDate,
      guardianName: _guardianNameController.text.trim(),
      guardianPhone: _guardianPhoneController.text.trim(),
      reason: _reasonController.text.trim(),
    );

    setState(() => _isSubmittingPass = false);

    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de sortie transmise à la direction de l\'internat ! ✨'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        setState(() {
          _showExitPassForm = false;
          _reasonController.clear();
        });
        _loadHostelData();
      }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.home_work_rounded,
                    color: Color(0xFF2563EB),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Internat & Résidence",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "${widget.studentName} • ${widget.studentClass ?? 'Scolarité'}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : !_isBoarder
                    ? _buildNotBoarderNotice()
                    : _buildBoarderContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotBoarderNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.bed_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Élève Externe ou Demi-Pensionnaire",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              "${widget.studentName} n'a pas d'attribution active de lit en internat. Pour réserver une place en dortoir, veuillez contacter l'administration de l'établissement.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoarderContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Room Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _allocation?['roomType'] ?? 'Chambre Internat',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Text(
                    "Pensionnaire Actif 🇳🇪",
                    style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Chambre ${_allocation?['roomNumber'] ?? '101'}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                _allocation?['buildingName'] ?? 'Pavillon Résidentiel',
                style: const TextStyle(fontSize: 13, color: Color(0xFFBFDBFE)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.group_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "${_roommates.length} Camarade(s) de chambre",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Roommates List
        if (_roommates.isNotEmpty) ...[
          const Text(
            "Camarades de Chambre",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: _roommates.map<Widget>((r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(Icons.person, size: 16, color: Color(0xFF4338CA)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r['name'] ?? 'Élève',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                      Text(
                        r['classe'] ?? '',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Night Attendance Section
        const Row(
          children: [
            Icon(Icons.nightlight_round, color: Color(0xFF4338CA), size: 18),
            SizedBox(width: 6),
            Text(
              "Derniers Appels Nocturnes",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_nightAttendance.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "Tous les appels récents sont en ordre (Présent au dortoir).",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          )
        else
          Column(
            children: _nightAttendance.map<Widget>((na) {
              final status = na['status']?.toString() ?? 'Présent';
              final isPresent = status == 'Présent';
              final isAbsent = status.contains('Absent');

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isPresent
                      ? const Color(0xFFF0FDF4)
                      : isAbsent
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPresent
                        ? const Color(0xFFBBF7D0)
                        : isAbsent
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Appel du ${na['date']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isPresent
                            ? const Color(0xFF15803D)
                            : isAbsent
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20),

        // Exit Permissions Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.door_front_door_outlined, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 6),
                Text(
                  "Sorties & Weekends",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            if (!_showExitPassForm)
              TextButton.icon(
                onPressed: () => setState(() => _showExitPassForm = true),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Demander une sortie", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),

        if (_showExitPassForm) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Nouvelle Demande de Sortie Weekend",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _permissionType,
                  decoration: InputDecoration(
                    labelText: "Type de permission",
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Sortie weekend', child: Text("Sortie weekend")),
                    DropdownMenuItem(value: 'Permission médicale', child: Text("Permission médicale")),
                    DropdownMenuItem(value: 'Visite familiale', child: Text("Visite familiale")),
                  ],
                  onChanged: (v) => setState(() => _permissionType = v ?? 'Sortie weekend'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: "Motif détaillé *",
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showExitPassForm = false),
                      child: const Text("Annuler"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmittingPass ? null : _submitExitPass,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmittingPass
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Transmettre"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        if (_exitPermissions.isEmpty)
          const Text("Aucune autorisation de sortie active.", style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
        else
          Column(
            children: _exitPermissions.map<Widget>((ep) {
              final status = ep['status']?.toString() ?? 'En attente';
              final isApprouve = status == 'Approuvé' || status == 'Sorti';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isApprouve ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded,
                      color: isApprouve ? Colors.green : Colors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ep['permission_type'] ?? ep['permissionType'] ?? 'Sortie',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            "Du ${ep['departure_date'] ?? ep['departureDate']} au ${ep['return_date_expected'] ?? ep['returnDateExpected']}",
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isApprouve ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isApprouve ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
