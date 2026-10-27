import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../finance/utils/receipt_generator.dart';
import '../../finance/data/finance_repository.dart';
import '../data/family_repository.dart';
import '../data/payment_gateway_service.dart';
import 'mobile_money_payment_dialog.dart';

class FamilyFinanceScreen extends StatefulWidget {
  const FamilyFinanceScreen({super.key});

  @override
  State<FamilyFinanceScreen> createState() => _FamilyFinanceScreenState();
}

class _FamilyFinanceScreenState extends State<FamilyFinanceScreen> {
  final FamilyRepository _repository = locator<FamilyRepository>();
  final FinanceRepository _financeRepository = locator<FinanceRepository>();
  final PaymentGatewayService _gatewayService = PaymentGatewayService();

  bool _isLoading = true;
  String? _errorMessage;
  int? _studentId;
  int? _schoolId;
  String _studentName = '';
  String _studentClass = '—';
  String _role = 'student';

  List<Map<String, dynamic>> _fees = [];
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = const {
    'totalExpected': 0.0,
    'totalPaid': 0.0,
    'totalReduction': 0.0,
    'totalBalance': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = locator<SessionManager>();
      _role = await session.getRole() ?? 'student';
      _studentId = int.tryParse(await session.getStudentId() ?? '');
      _schoolId = int.tryParse(await session.getSchoolId() ?? '');
      _studentName = await session.getStudentName() ?? 'Eleve';
      _studentClass = await session.getStudentClass() ?? '—';

      // Sync latest student profile from API
      try {
        final token = await session.getToken() ?? '';
        if (token.isNotEmpty) {
          final apiProfile = await locator<MobileApiClient>().getMeProfile(token);
          if (apiProfile != null && apiProfile.studentId != null) {
            final freshStudentId = int.tryParse(apiProfile.studentId!);
            if (freshStudentId != null) {
              _studentId = freshStudentId;
              _schoolId = int.tryParse(apiProfile.schoolId ?? '') ?? _schoolId;
              _studentName = apiProfile.studentName ?? _studentName;
              _studentClass = apiProfile.studentClass ?? _studentClass;
              await session.saveSession(
                token: token,
                email: await session.getEmail() ?? '',
                role: _role,
                employeeId: await session.getEmployeeId() ?? '',
                userId: await session.getUserId(),
                schoolId: _schoolId?.toString(),
                studentId: _studentId?.toString(),
                studentName: _studentName,
                studentClass: _studentClass,
              );
            }
          }
        }
      } catch (e) {
        debugPrint("[FamilyFinance] Profile sync fallback: $e");
      }

      if (_studentId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aucun eleve lie a ce compte.';
        });
        return;
      }

      final finance = await _repository.getFinanceOverview(
        studentId: _studentId!,
        schoolId: _schoolId,
      );
      _fees = List<Map<String, dynamic>>.from(finance['fees'] as List? ?? []);
      _payments = List<Map<String, dynamic>>.from(finance['payments'] as List? ?? []);
      _summary = Map<String, dynamic>.from(finance['summary'] as Map? ?? {});

      // Fallback: If payments array is empty but fee has paid amount, generate receipt record
      if (_payments.isEmpty && _fees.isNotEmpty) {
        for (final f in _fees) {
          final p = (f['total_paid'] as num?)?.toDouble() ?? 0.0;
          if (p > 0) {
            _payments.add({
              'id': f['id'] ?? 1,
              'fee_id': f['id'],
              'amount': p,
              'date_paid': DateTime.now().toIso8601String(),
              'payment_mode': 'Paiement scolarité',
              'month_concerned': 'Frais annuels de scolarité',
              'reference': 'REC-${f['id'] ?? 1}',
              'recorded_by': 'Admin Scolarité',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  void _openMobileMoneyDialog() {
    if (_studentId == null) return;
    final balance = (_summary['totalBalance'] as num?)?.toDouble() ?? 0;
    
    showDialog(
      context: context,
      builder: (ctx) => MobileMoneyPaymentDialog(
        studentId: _studentId!,
        studentName: _studentName,
        defaultAmount: balance > 0 ? balance : 25000,
        onPaymentSuccess: (result) {
          _loadData();
        },
      ),
    );
  }

  Future<void> _shareReceipt(Map<String, dynamic> payment) async {
    final fee = _fees.firstWhere(
      (item) => item['id'] == payment['fee_id'],
      orElse: () => _fees.isNotEmpty ? _fees.first : <String, dynamic>{},
    );

    Map<String, dynamic>? headerConfig;
    if (_schoolId != null) {
      try {
        final res = await _financeRepository.getDocumentHeader(_schoolId!);
        if (res['success'] == true) {
          headerConfig = res['data'] as Map<String, dynamic>?;
        }
      } catch (e) {
        debugPrint("Error fetching document header in family: $e");
      }
    }

    final studentIdStr = _studentId != null ? 'CARD-EDUT-$_studentId' : '—';

    if (!mounted) return;
    final feeStudent = fee['students'] as Map<String, dynamic>? ?? {};
    await ReceiptGenerator.showFormatAndActionDialog(
      context: context,
      student: {
        ...feeStudent,
        'nom_etudiant': _studentName,
        'classe': _studentClass,
        'num_admission': studentIdStr,
        'educational_level': feeStudent['educational_level'] ?? fee['educational_level'] ?? '',
        'session_name': fee['session_name'] ?? (fee['session_id'] != null ? 'Session ${fee['session_id']}' : '2024–2025'),
      },
      payment: payment,
      totalExpected: (fee['total_expected'] as num?)?.toDouble() ?? (_summary['totalExpected'] as num?)?.toDouble() ?? 0,
      remainingBalance: (fee['balance'] as num?)?.toDouble() ?? (_summary['totalBalance'] as num?)?.toDouble() ?? 0,
      allPayments: _payments,
      headerConfig: headerConfig,
    );
  }

  Future<void> _openGateway(PaymentGatewayOption gateway) async {
    final amount = (_summary['totalBalance'] as num?)?.toDouble() ?? 0;
    if (_studentId == null || amount <= 0) return;
    final ok = await _gatewayService.launchGateway(
      gateway: gateway,
      studentId: _studentId!,
      amount: amount,
      studentName: _studentName,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la passerelle.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Finance & Mobile Money 🇳🇪'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_errorMessage!, textAlign: TextAlign.center),
                ))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildMobileMoneyBanner(),
                      const SizedBox(height: 16),
                      _buildDigitalIdCard(),
                      if (_role == 'parent') ...[
                        const SizedBox(height: 16),
                        _buildGatewayCard(),
                      ],
                      const SizedBox(height: 20),
                      Text('Frais scolaires', style: AppTextStyles.heading3),
                      const SizedBox(height: 12),
                      if (_fees.isEmpty)
                        _buildEmptyCard('Aucun dossier financier disponible.')
                      else
                        ..._fees.map(_buildFeeCard),
                      const SizedBox(height: 20),
                      Text('Reçus et paiements', style: AppTextStyles.heading3),
                      const SizedBox(height: 12),
                      if (_payments.isEmpty)
                        _buildEmptyCard('Aucun paiement enregistré.')
                      else
                        ..._payments.map(_buildPaymentCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_studentName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metric('Attendu', _summary['totalExpected'])),
              Expanded(child: _metric('Payé', _summary['totalPaid'])),
              Expanded(child: _metric('Reste', _summary['totalBalance'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyBanner() {
    final balance = (_summary['totalBalance'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smartphone, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Guichet Mobile Money Direct 🇳🇪', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('Airtel Money, Moov Money, Flooz, Orange & Wave', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              onPressed: _openMobileMoneyDialog,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(
                balance > 0 
                    ? 'Payer le Solde (${balance.toStringAsFixed(0)} FCFA)' 
                    : 'Payer via Mobile Money',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalIdCard() {
    final studentIdStr = _studentId != null ? 'CARD-EDUT-$_studentId' : 'CARD-EDUT-00';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigo.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CARTE SCOLAIRE NUMÉRIQUE 🪪', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w900, fontSize: 11)),
                  Text('Établissement Scolaire Edut Pro', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4)),
                ),
                child: const Text('VALIDE', style: TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.bold, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 70,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.shade400.withOpacity(0.5)),
                ),
                child: const Icon(Icons.person, color: Colors.white54, size: 40),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Matricule: $studentIdStr', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w700, fontSize: 11)),
                    const SizedBox(height: 2),
                    const Text('Niveau: Enseignement Général', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              QrImageView(
                data: 'https://edut.ne/verify/student/$studentIdStr',
                version: QrVersions.auto,
                size: 64,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0.0;
    return Column(
      children: [
        Text('${amount.toStringAsFixed(0)} F', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildGatewayCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Autres passerelles externes', style: AppTextStyles.bodyBold),
          const SizedBox(height: 8),
          const Text(
            'Lancez une page de paiement compatible Stripe, CinetPay ou un intégrateur local.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...PaymentGatewayService.gateways.map((gateway) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(gateway.label, style: AppTextStyles.bodyBold),
              subtitle: Text(gateway.description),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openGateway(gateway),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> fee) {
    final expected = (fee['total_expected'] as num?)?.toDouble() ?? 0;
    final paid = (fee['total_paid'] as num?)?.toDouble() ?? 0;
    final balance = (fee['balance'] as num?)?.toDouble() ?? 0;
    final isSolde = balance <= 0 && expected > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session ${fee['session_id'] ?? '2024–2025'}', style: AppTextStyles.bodyBold),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSolde ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSolde ? 'SOLDÉ' : 'EN COURS',
                  style: TextStyle(
                    color: isSolde ? const Color(0xFF059669) : const Color(0xFFD97706),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: expected > 0 ? (paid / expected).clamp(0, 1) : 0,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isSolde ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text('Attendu', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${expected.toStringAsFixed(0)} F', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    children: [
                      const Text('Payé', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${paid.toStringAsFixed(0)} F', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: balance > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: balance > 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text('Reste', style: TextStyle(fontSize: 10, color: balance > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${balance.toStringAsFixed(0)} F', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: balance > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669))),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (balance > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: Text(
                  'Payer cette tranche via Mobile Money (${balance.toStringAsFixed(0)} FCFA)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_studentId == null) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => MobileMoneyPaymentDialog(
                      studentId: _studentId!,
                      studentName: _studentName,
                      defaultAmount: balance,
                      feeId: fee['id'],
                      onPaymentSuccess: (result) => _loadData(),
                    ),
                  );
                },
              ),
            ),
          ],
          if (paid > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFFC8D2FF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text(
                  'Exporter / Imprimer le Reçu Officiel (A5 / A4)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final payment = _payments.isNotEmpty
                      ? _payments.first
                      : {
                          'id': fee['id'] ?? 1,
                          'fee_id': fee['id'],
                          'amount': paid,
                          'date_paid': DateTime.now().toIso8601String(),
                          'payment_mode': 'Paiement scolarité',
                        };
                  _shareReceipt(payment);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final date = payment['date_paid'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(payment['date_paid'] as String))
        : DateFormat('dd/MM/yyyy').format(DateTime.now());
    final ref = payment['reference'] ?? 'REC-${payment['id'] ?? 1}';
    final mode = payment['payment_mode'] ?? 'Espèces';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${amount.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ref,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ENCAISSÉ',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mode: $mode',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Text(
                'Date: $date',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text(
                'Télécharger / Imprimer le Reçu (PDF)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _shareReceipt(payment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEBF0F5)),
    );
  }
}
