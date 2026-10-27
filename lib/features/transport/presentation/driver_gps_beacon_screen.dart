import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/transport_repository.dart';

class DriverGpsBeaconScreen extends StatefulWidget {
  final int tripId;
  final String routeName;
  final String vehicleNumber;
  final List<dynamic> stops;

  const DriverGpsBeaconScreen({
    super.key,
    required this.tripId,
    required this.routeName,
    required this.vehicleNumber,
    required this.stops,
  });

  @override
  State<DriverGpsBeaconScreen> createState() => _DriverGpsBeaconScreenState();
}

class _DriverGpsBeaconScreenState extends State<DriverGpsBeaconScreen> {
  final TransportRepository _repo = locator<TransportRepository>();

  bool _isBroadcasting = false;
  Timer? _beaconTimer;
  int _currentStopIndex = 0;
  double _currentSpeed = 35.0;
  int _pingsSent = 0;

  // Base coordinates (Niamey city center baseline)
  double _lat = 13.5126;
  double _lng = 2.1126;

  @override
  void dispose() {
    _beaconTimer?.cancel();
    super.dispose();
  }

  void _toggleBroadcast() {
    if (_isBroadcasting) {
      _beaconTimer?.cancel();
      setState(() {
        _isBroadcasting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🛑 Diffusion GPS arrêtée.')),
      );
    } else {
      setState(() {
        _isBroadcasting = true;
      });
      _sendPing();
      // Send live GPS ping every 5 seconds
      _beaconTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendPing();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛰️ Balise GPS active — Diffusion en temps réel lancée !'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _sendPing() async {
    // Simulate slight movement along the route
    _lat += 0.0002;
    _lng += 0.00015;

    final currentStopName = widget.stops.isNotEmpty && _currentStopIndex < widget.stops.length
        ? widget.stops[_currentStopIndex]['stopName']?.toString()
        : 'En transit';

    final success = await _repo.sendGpsPing(
      tripId: widget.tripId,
      latitude: _lat,
      longitude: _lng,
      speedKmh: _currentSpeed,
      currentStop: currentStopName,
      estimatedArrivalMinutes: 4,
    );

    if (success && mounted) {
      setState(() {
        _pingsSent++;
      });
    }
  }

  void _nextStop() {
    if (_currentStopIndex < widget.stops.length - 1) {
      setState(() {
        _currentStopIndex++;
      });
      _sendPing();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStopName = widget.stops.isNotEmpty && _currentStopIndex < widget.stops.length
        ? widget.stops[_currentStopIndex]['stopName']?.toString()
        : 'Départ';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
              'Balise GPS Conducteur',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
            ),
            Text(
              '${widget.vehicleNumber} · ${widget.routeName}',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Radar Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isBroadcasting ? AppColors.success.withValues(alpha: 0.5) : Colors.white10,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isBroadcasting
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.slate600.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cell_tower,
                      size: 48,
                      color: _isBroadcasting ? AppColors.success : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isBroadcasting ? 'DIFFUSION ACTIVE' : 'BALISE EN PAUSE',
                    style: TextStyle(
                      color: _isBroadcasting ? AppColors.success : Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isBroadcasting
                      ? '$_pingsSent signaux GPS envoyés vers le serveur'
                      : 'Appuyez ci-dessous pour démarrer le circuit',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Current Stop Controller
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROCHAIN ARRÊT CIBLÉ',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          currentStopName ?? 'Terminus',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _nextStop,
                        icon: const Icon(Icons.skip_next, size: 16),
                        label: const Text('Arrêt Suivant'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Start / Stop Main Beacon Button
            ElevatedButton.icon(
              onPressed: _toggleBroadcast,
              icon: Icon(_isBroadcasting ? Icons.pause_circle_filled : Icons.play_circle_filled),
              label: Text(
                _isBroadcasting ? 'Arrêter la Balise' : 'Démarrer le Circuit (GPS Live)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBroadcasting ? AppColors.danger : AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
