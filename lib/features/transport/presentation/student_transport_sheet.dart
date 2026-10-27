import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection.dart';
import '../data/transport_repository.dart';

class StudentTransportSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String? studentClass;

  const StudentTransportSheet({
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
      builder: (ctx) => StudentTransportSheet(
        studentId: studentId,
        studentName: studentName,
        studentClass: studentClass,
      ),
    );
  }

  @override
  State<StudentTransportSheet> createState() => _StudentTransportSheetState();
}

class _StudentTransportSheetState extends State<StudentTransportSheet> {
  final _repository = locator<TransportRepository>();

  bool _isLoading = true;
  String? _error;
  bool _isSubscribed = false;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _activeTrip;
  List<dynamic> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadTransportData();
  }

  Future<void> _loadTransportData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _repository.getStudentTransportDetails(widget.studentId);
      if (res['success'] == true) {
        setState(() {
          _isSubscribed = res['isSubscribed'] == true;
          _subscription = res['subscription'] as Map<String, dynamic>?;
          _activeTrip = res['activeTrip'] as Map<String, dynamic>?;
          _recentLogs = (res['recentLogs'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['error']?.toString() ?? "Erreur de chargement";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
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
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.directions_bus_filled_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Transport Scolaire & Trajet",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        "${widget.studentName} • ${widget.studentClass ?? 'Élève'}",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadTransportData,
                                child: const Text("Réessayer"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : !_isSubscribed || _subscription == null
                        ? _buildNotSubscribedView()
                        : _buildSubscribedView(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSubscribedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.no_transfer_rounded, size: 56, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Non inscrit au transport scolaire",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          Text(
            "L'élève ${widget.studentName} n'a pas encore d'abonnement actif à une ligne de bus scolaire pour cette année académique.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Contactez l'administration de l'établissement ou le service de transport pour souscrire à une ligne.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribedView() {
    final sub = _subscription!;
    final routeName = sub['routeName'] ?? 'Ligne Scolaire';
    final vehicleNumber = sub['vehicleNumber'] ?? 'Bus';
    final driverName = sub['driverName'] ?? 'Chauffeur attitré';
    final driverPhone = sub['driverPhone'] as String?;
    final pickupStop = sub['pickupStop'] ?? 'Arrêt Principal';
    final tripType = sub['tripType'] ?? 'Aller-Retour';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. Digital Bus Pass (Badge) ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "CARTE DE TRANSPORT SCOLAIRE",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tripType,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Classe : ${widget.studentClass ?? 'Inscrit'}",
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.route_rounded, color: Colors.amberAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  routeName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.pin_drop_rounded, color: Colors.amberAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Arrêt : $pickupStop",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: 'SCAN-BUS-${widget.studentId}',
                        version: QrVersions.auto,
                        size: 80.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 2. Live Bus Circuit Status ────────────────────────────────────
          if (_activeTrip != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "CIRCUIT EN DIRECT",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${_activeTrip!['tripType']} • Démarré à ${_activeTrip!['startTime'] ?? '07:00'}",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          "Arrêt actuel : ${_activeTrip!['currentStop'] ?? 'En circulation'}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─── 3. Driver & Vehicle Card ──────────────────────────────────────
          const Text(
            "Chauffeur & Véhicule",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Bus Immatriculé : $vehicleNumber",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (driverPhone != null && driverPhone.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _callDriver(driverPhone),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text("Appeler"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── 4. Recent Boarding Log ────────────────────────────────────────
          const Text(
            "Derniers Pointages & Trajets",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          if (_recentLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  "Aucun historique de pointage récent.",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentLogs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final log = _recentLogs[i] as Map<String, dynamic>;
                final eventType = log['eventType']?.toString() ?? 'Pointage';
                final stopName = log['stopName']?.toString() ?? 'Arrêt';
                final isBoarding = eventType.contains('Montée');
                final dateStr = log['scanTime']?.toString() ?? '';

                DateTime? parsed;
                try {
                  parsed = DateTime.parse(dateStr);
                } catch (_) {}

                final formattedTime = parsed != null
                    ? "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}"
                    : "N/A";
                final formattedDate = parsed != null
                    ? "${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}"
                    : "";

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isBoarding ? Colors.blue.shade50 : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isBoarding ? Icons.login_rounded : Icons.logout_rounded,
                          color: isBoarding ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventType,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              "Arrêt : $stopName",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
