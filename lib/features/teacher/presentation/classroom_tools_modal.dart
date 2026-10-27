import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ClassroomToolsModal extends StatefulWidget {
  final String? className;
  const ClassroomToolsModal({super.key, this.className});

  static void show(BuildContext context, {String? className}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClassroomToolsModal(className: className),
    );
  }

  @override
  State<ClassroomToolsModal> createState() => _ClassroomToolsModalState();
}

class _ClassroomToolsModalState extends State<ClassroomToolsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Wheel selector state
  final List<String> _sampleStudents = [
    'Moussa Ibrahim',
    'Fatima Amadou',
    'Abdoulaye Oumarou',
    'Aïchatou Saley',
    'Idrissa Boubacar',
    'Zalika Harouna',
    'Mahamadou Souley',
    'Nafissa Adamou',
  ];
  String? _selectedStudent;
  bool _isSpinning = false;

  // Stopwatch state
  Timer? _timer;
  int _remainingSeconds = 300; // default 5 min
  int _initialSeconds = 300;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _selectedStudent = null;
    });

    int ticks = 0;
    const totalTicks = 20;
    Timer.periodic(const Duration(milliseconds: 100), (t) {
      ticks++;
      setState(() {
        _selectedStudent = _sampleStudents[Random().nextInt(_sampleStudents.length)];
      });
      if (ticks >= totalTicks) {
        t.cancel();
        setState(() {
          _isSpinning = false;
        });
      }
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          t.cancel();
          setState(() => _isRunning = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔔 Temps écoulé pour l\'exercice !'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
        }
      });
    }
  }

  void _setTimerDuration(int minutes) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _initialSeconds = minutes * 60;
      _remainingSeconds = _initialSeconds;
    });
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Boîte à Outils de Classe',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      widget.className ?? 'Gestion interactive du cours',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6D28D9),
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: const Color(0xFF6D28D9),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.casino_rounded), text: 'Tirage au Sort'),
              Tab(icon: Icon(Icons.timer_rounded), text: 'Chronomètre Activité'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Random Selector Tab
                _buildRandomSelectorTab(),
                // 2. Classroom Timer Tab
                _buildClassroomTimerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRandomSelectorTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isSpinning
                    ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                    : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.school_rounded, color: Colors.white70, size: 36),
                const SizedBox(height: 12),
                Text(
                  _selectedStudent ?? 'Prêt pour le tirage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _selectedStudent != null ? 22 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_selectedStudent != null && !_isSpinning) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Text(
                      'Élève sélectionné pour répondre 🎯',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSpinning ? null : _spinWheel,
              icon: Icon(_isSpinning ? Icons.refresh_rounded : Icons.casino_rounded, color: Colors.white),
              label: Text(
                _isSpinning ? 'Tirage en cours...' : 'Tirer un élève au sort',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          if (_selectedStudent != null && !_isSpinning) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⭐ +5 Points de Mérite accordés à $_selectedStudent !'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
              label: const Text('+5 Pts de Participation', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF59E0B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassroomTimerTab() {
    final progress = _initialSeconds > 0 ? _remainingSeconds / _initialSeconds : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Preset duration buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [3, 5, 10, 15, 20].map((min) {
              final isCur = _initialSeconds == min * 60;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('${min}m'),
                  selected: isCur,
                  selectedColor: const Color(0xFF6D28D9).withValues(alpha: 0.15),
                  side: BorderSide(color: isCur ? const Color(0xFF6D28D9) : const Color(0xFFCBD5E1)),
                  onSelected: (_) => _setTimerDuration(min),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Circular / Box Countdown Display
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remainingSeconds < 60 ? const Color(0xFFEF4444) : const Color(0xFF6D28D9),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  Text(
                    _isRunning ? 'EN COURS' : 'EN PAUSE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: _isRunning ? const Color(0xFF10B981) : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => _setTimerDuration(_initialSeconds ~/ 60),
                icon: const Icon(Icons.replay_rounded),
                iconSize: 26,
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                label: Text(_isRunning ? 'Pause' : 'Démarrer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? const Color(0xFFF59E0B) : const Color(0xFF6D28D9),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
