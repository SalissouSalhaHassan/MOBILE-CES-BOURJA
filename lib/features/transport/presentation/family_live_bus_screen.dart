import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/transport_repository.dart';

class FamilyLiveBusScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const FamilyLiveBusScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<FamilyLiveBusScreen> createState() => _FamilyLiveBusScreenState();
}

class _FamilyLiveBusScreenState extends State<FamilyLiveBusScreen> {
  final TransportRepository _repo = locator<TransportRepository>();

  bool _isLoading = true;
  bool _isSubscribed = false;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _liveTrip;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTransportDetails();
    // Poll bus location every 6 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_liveTrip?['id'] != null) {
        _pollLiveLocation(_liveTrip!['id']);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTransportDetails() async {
    setState(() => _isLoading = true);
    final res = await _repo.getStudentTransportDetails(widget.studentId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSubscribed = res['isSubscribed'] == true;
        _subscription = res['subscription'] != null
            ? Map<String, dynamic>.from(res['subscription'])
            : null;
        _liveTrip = res['activeTrip'] != null
            ? Map<String, dynamic>.from(res['activeTrip'])
            : null;
      });
    }
  }

  Future<void> _pollLiveLocation(int tripId) async {
    final status = await _repo.getLiveTripStatus(tripId);
    if (status != null && mounted) {
      setState(() {
        _liveTrip = status;
      });
    }
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark GPS radar theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suivi GPS en Direct',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
            ),
            Text(
              widget.studentName,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'EN DIRECT',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : !_isSubscribed
              ? _buildNotSubscribedView()
              : _buildLiveTrackingView(),
    );
  }

  Widget _buildNotSubscribedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_outlined, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'Aucun abonnement transport actif',
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cet élève n\'est pas encore inscrit à un circuit de transport scolaire.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTrackingView() {
    final driverPhone = _subscription?['driverPhone']?.toString();
    final driverName = _subscription?['driverName']?.toString() ?? 'Chauffeur Assigné';
    final vehicleNumber = _subscription?['vehicleNumber']?.toString() ?? 'Bus Edut';
    final routeName = _subscription?['routeName']?.toString() ?? 'Circuit Principal';
    final pickupStop = _subscription?['pickupStop']?.toString() ?? 'Mon Arrêt';
    final speed = (_liveTrip?['speedKmh'] as num?)?.toDouble() ?? 0.0;
    final currentStop = _liveTrip?['currentStop']?.toString() ?? 'En route vers $pickupStop';
    final etaMinutes = (_liveTrip?['estimatedArrivalMinutes'] as num?)?.toInt() ?? 5;
    final stops = (_subscription?['stops'] as List<dynamic>?) ?? [];

    return Column(
      children: [
        // Simulated Radar / Map View
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF090D16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar Grid Circles
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10, width: 1.5),
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10, width: 1.5),
                  ),
                ),

                // Pulsing Bus Marker
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        vehicleNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Live Speed & Coordinates Chip
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.speed, color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${speed.toStringAsFixed(0)} km/h',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ETA Chip
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Arrivée estimée : ~$etaMinutes min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Details Sheet
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circuit Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routeName,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Arrêt de l\'élève : $pickupStop • Chauffeur : $driverName',
                              style: AppTextStyles.caption.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      if (driverPhone != null && driverPhone.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _callDriver(driverPhone),
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('Chauffeur'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Current Status Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Position Actuelle du Bus',
                                style: TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                              Text(
                                currentStop,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stops Sequence
                  if (stops.isNotEmpty) ...[
                    const Text(
                      'Itinéraire des Arrêts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...stops.map((st) {
                      final name = st['stopName']?.toString() ?? 'Arrêt';
                      final isStudentStop = name.toLowerCase() == pickupStop.toLowerCase();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isStudentStop
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isStudentStop ? const Color(0xFF4F46E5) : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isStudentStop ? Icons.stars : Icons.radio_button_unchecked,
                              size: 16,
                              color: isStudentStop ? Colors.amber : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: isStudentStop ? Colors.white : Colors.white70,
                                  fontWeight: isStudentStop ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isStudentStop)
                              const Text(
                                'ARRÊT ÉLÈVE',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
