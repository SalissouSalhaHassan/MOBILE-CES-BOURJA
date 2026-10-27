import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/di/injection.dart';
import '../data/canteen_repository.dart';

class StudentCanteenSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String? studentClass;

  const StudentCanteenSheet({
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
      builder: (ctx) => StudentCanteenSheet(
        studentId: studentId,
        studentName: studentName,
        studentClass: studentClass,
      ),
    );
  }

  @override
  State<StudentCanteenSheet> createState() => _StudentCanteenSheetState();
}

class _StudentCanteenSheetState extends State<StudentCanteenSheet> {
  final _repository = locator<CanteenRepository>();

  bool _isLoading = true;
  String? _error;
  bool _isSubscribed = false;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _todayMenu;
  List<dynamic> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadCanteenData();
  }

  Future<void> _loadCanteenData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _repository.getStudentCanteenDetails(widget.studentId);
      if (res['success'] == true) {
        setState(() {
          _isSubscribed = res['isSubscribed'] == true;
          _subscription = res['subscription'] as Map<String, dynamic>?;
          _wallet = res['wallet'] as Map<String, dynamic>?;
          _todayMenu = res['todayMenu'] as Map<String, dynamic>?;
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

  void _showTopupDialog() {
    double selectedAmount = 5000;
    String selectedMethod = "Flooz";
    bool isRecharging = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669)),
                SizedBox(width: 10),
                Text(
                  "Recharger la Cantine",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Élève : ${widget.studentName}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                const Text("Choisir un montant :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [2000.0, 5000.0, 10000.0].map((amt) {
                    final isSel = selectedAmount == amt;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedAmount = amt),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF059669) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "${amt.toInt()} F",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text("Moyen de paiement :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text("Moov Flooz", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        value: "Flooz",
                        groupValue: selectedMethod,
                        activeColor: const Color(0xFF059669),
                        onChanged: (v) => setDialogState(() => selectedMethod = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text("Airtel Money", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        value: "Airtel Money",
                        groupValue: selectedMethod,
                        activeColor: const Color(0xFF059669),
                        onChanged: (v) => setDialogState(() => selectedMethod = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isRecharging
                    ? null
                    : () async {
                        setDialogState(() => isRecharging = true);
                        final res = await _repository.topUpWallet(
                          studentId: widget.studentId,
                          amount: selectedAmount,
                          paymentMethod: selectedMethod,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ?? "Compte rechargé avec succès !"),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _loadCanteenData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['error']?.toString() ?? "Échec de la recharge."),
                              backgroundColor: const Color(0xFFE11D48),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isRecharging
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Payer & Recharger"),
              ),
            ],
          );
        },
      ),
    );
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
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Restaurant Scolaire & Nutrition",
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
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
                                onPressed: _loadCanteenData,
                                child: const Text("Réessayer"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildCanteenBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildCanteenBody() {
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0.0;
    final isLow = balance < 2000.0;
    final planType = _subscription?['planType'] ?? 'Ticket / À la carte';
    final specialDiet = _subscription?['specialDiet'] ?? 'Normal';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. Digital Canteen Pass (Badge) ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
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
                        Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "PASS RESTAURATION SCOLAIRE",
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
                        _isSubscribed ? "Demi-Pension" : "À la carte",
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
                              const Icon(Icons.room_service_rounded, color: Colors.amberAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  planType,
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
                              const Icon(Icons.health_and_safety_rounded, color: Colors.amberAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Régime : $specialDiet",
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
                        data: 'CANTINE-PASS-${widget.studentId}',
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

          // ─── 2. Digital Wallet Balance & Topup ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isLow ? Colors.amber.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isLow ? Colors.amber.shade300 : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.amber.shade100 : const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: isLow ? Colors.amber.shade900 : const Color(0xFF059669),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLow ? "Solde faible au réfectoire" : "Porte-monnaie Cantine",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isLow ? Colors.amber.shade900 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${balance.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} CFA",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showTopupDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Recharger"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── 3. Today's Nutritious Menu ────────────────────────────────────
          if (_todayMenu != null) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Au Menu Aujourd'hui",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                Text(
                  "Réfectoire Central",
                  style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.lunch_dining_rounded, color: Color(0xFFD97706), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _todayMenu!['name'] ?? _todayMenu!['title'] ?? 'Plat du Jour Équilibré',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _todayMenu!['description'] ?? 'Riz au gras, sauce tomate et légumes locaux.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_todayMenu!['calories'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "${_todayMenu!['calories']} kcal",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                  ],
                  if (_todayMenu!['allergens'] != null && _todayMenu!['allergens'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        "⚠️ Allergènes : ${_todayMenu!['allergens']}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9F1239)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── 4. Recent Cafeteria Meal Logs ─────────────────────────────────
          const Text(
            "Historique des Repas Consommés",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
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
                  "Aucun repas récent enregistré au réfectoire.",
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
                final menuDesc = log['menuDescription']?.toString() ?? 'Repas complet';
                final mealType = log['mealType']?.toString() ?? 'Déjeuner';
                final dateStr = log['servedAt']?.toString() ?? '';

                DateTime? parsed;
                try {
                  parsed = DateTime.parse(dateStr);
                } catch (_) {}

                final formattedTime = parsed != null
                    ? "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}"
                    : "";
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
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              menuDesc,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              mealType,
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
