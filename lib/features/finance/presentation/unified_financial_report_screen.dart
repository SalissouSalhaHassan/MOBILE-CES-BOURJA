import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/offline_store_manager.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/educational_level_helper.dart';
import '../data/finance_repository.dart';
import '../utils/unified_financial_report_pdf_generator.dart';

class UnifiedFinancialReportScreen extends StatefulWidget {
  const UnifiedFinancialReportScreen({super.key});

  @override
  State<UnifiedFinancialReportScreen> createState() =>
      _UnifiedFinancialReportScreenState();
}

class _UnifiedFinancialReportScreenState
    extends State<UnifiedFinancialReportScreen> {
  final FinanceRepository _financeRepo = getIt<FinanceRepository>();
  final SessionManager _sessionManager = getIt<SessionManager>();

  String _period = "monthly"; // "daily", "monthly", "yearly", "all"
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _report = {};
  Map<String, dynamic>? _headerConfig;
  String _sessionName = '2024–2025';
  String? _userEducationalLevel;
  String _selectedLevel = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  /// Dot-formatted currency string (10.000 CFA)
  String _formatCfa(num amount) {
    return UnifiedFinancialReportPdfGenerator.formatCfa(amount);
  }

  /// Detect effective target level for header profile resolution
  String? get _effectiveTargetLevel {
    if (_selectedLevel != 'Tous' &&
        !EducationalLevelHelper.hasAllEducationalLevels(_selectedLevel)) {
      return _selectedLevel;
    }
    if (_userEducationalLevel != null &&
        !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel)) {
      return _userEducationalLevel;
    }
    return null;
  }

  /// Available educational levels derived from header profiles & standards
  List<String> get _availableLevels {
    if (_userEducationalLevel != null &&
        !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel)) {
      return [_userEducationalLevel!];
    }
    final set = <String>{'Tous', 'Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'};
    final profiles = _headerConfig?['levelProfiles'];
    if (profiles is List) {
      for (final p in profiles) {
        if (p is Map) {
          final name = p['name']?.toString();
          if (name != null && name.isNotEmpty) set.add(name);
          final appLevels = p['applicableLevels'];
          if (appLevels is List) {
            for (final al in appLevels) {
              if (al != null && al.toString().isNotEmpty) set.add(al.toString());
            }
          }
        }
      }
    }
    return set.toList();
  }

  Future<void> _loadReport() async {
    final schoolIdStr = await _sessionManager.getSchoolId();
    final schoolId = int.tryParse(schoolIdStr ?? '9') ?? 9;

    // Load User Educational Level
    try {
      _userEducationalLevel = await _sessionManager.getEducationalLevel();
      if (_userEducationalLevel != null &&
          !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel) &&
          _selectedLevel == 'Tous') {
        _selectedLevel = _userEducationalLevel!;
      }
    } catch (_) {}

    // Check fast local cache first so UI is instant
    final date = _selectedDate;
    final dateIso = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final cacheKey = "unified_report_${schoolId}_${_period}_${dateIso}_${_effectiveTargetLevel ?? 'all'}";
    final cacheManager = locator<OfflineStoreManager>();
    final cachedData = cacheManager.getMap(
      boxName: OfflineStoreManager.boxStudentFees,
      key: cacheKey,
    );

    if (cachedData != null && cachedData.isNotEmpty && mounted) {
      setState(() {
        _report = cachedData;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    // Load Header Config and Sessions in parallel
    if (_headerConfig == null || _sessionName == '2024–2025') {
      Future.wait([
        _financeRepo.getDocumentHeader(schoolId).then((headerRes) {
          if (headerRes['success'] == true && mounted) {
            setState(() {
              _headerConfig = headerRes['data'] as Map<String, dynamic>?;
            });
          }
        }).catchError((_) {}),
        _financeRepo.getSessions(schoolId).then((sessions) {
          if (sessions.isNotEmpty && mounted) {
            final active = sessions.firstWhere(
              (s) => s['is_active'] == true || s['status']?.toString().toLowerCase() == 'actif',
              orElse: () => sessions.first,
            );
            final name = active['session_name']?.toString();
            if (name != null && name.isNotEmpty) {
              setState(() => _sessionName = name);
            }
          }
        }).catchError((_) {}),
      ]);
    }

    // Fetch report data
    final data = await _financeRepo.getUnifiedFinancialReport(
      schoolId: schoolId,
      period: _period,
      selectedDate: _selectedDate,
      level: _effectiveTargetLevel,
    );

    if (mounted) {
      setState(() {
        _report = data;
        _isLoading = false;
      });
    }
  }

  /// Direct PDF Printing via Mobile Print spooler
  Future<void> _printDirect() async {
    if (_report.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await UnifiedFinancialReportPdfGenerator.generatePdfBytes(
        report: _report,
        period: _period,
        selectedDate: _selectedDate,
        headerConfig: _headerConfig,
        sessionName: _sessionName,
        targetLevel: _effectiveTargetLevel,
        pageFormat: PdfPageFormat.a4,
      );

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'rapport_financier_unifie_$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'impression : $e"),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Export PDF and share / save locally
  Future<void> _exportPdf() async {
    if (_report.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await UnifiedFinancialReportPdfGenerator.generatePdfBytes(
        report: _report,
        period: _period,
        selectedDate: _selectedDate,
        headerConfig: _headerConfig,
        sessionName: _sessionName,
        targetLevel: _effectiveTargetLevel,
        pageFormat: PdfPageFormat.a4,
      );

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'rapport_financier_unifie_$dateStr.pdf';

      await SharePlus.instance.share(
        ShareParams(
          text: 'Rapport Financier Unifié (Recettes vs Dépenses) — Edut Pro',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: fileName,
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'export PDF : $e"),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showAddExpenseDialog() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = "Fournitures & Matériel";
    String paymentMode = "Espèces";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Nouvelle Dépense (Hors-ligne & En ligne)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: "Motif / Description de la dépense",
                  hintText: "ex: Achat rames de papier, Facture Nigelec...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Montant (FCFA)",
                  suffixText: "CFA",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: "Catégorie",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: const [
                  DropdownMenuItem(value: "Fournitures & Matériel", child: Text("Fournitures & Matériel")),
                  DropdownMenuItem(value: "Salaires & Primes", child: Text("Salaires & Primes")),
                  DropdownMenuItem(value: "Entretien & Réparations", child: Text("Entretien & Réparations")),
                  DropdownMenuItem(value: "Électricité & Eau", child: Text("Électricité & Eau")),
                  DropdownMenuItem(value: "Pédagogie & Examens", child: Text("Pédagogie & Examens")),
                  DropdownMenuItem(value: "Autres Dépenses", child: Text("Autres Dépenses")),
                ],
                onChanged: (v) => setModalState(() => category = v!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    final desc = descCtrl.text.trim();
                    if (amt <= 0 || desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Veuillez remplir tous les champs")),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final schoolIdStr = await _sessionManager.getSchoolId();
                    final schoolId = int.tryParse(schoolIdStr ?? '9') ?? 9;
                    final res = await _financeRepo.recordExpenseOffline(
                      schoolId: schoolId,
                      description: desc,
                      amount: amt,
                      category: category,
                      paymentMode: paymentMode,
                    );
                    final isOnline = res['isOnline'] == true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isOnline
                              ? "Dépense enregistrée et synchronisée instantanément avec le Web !"
                              : "Dépense enregistrée hors-ligne (en attente de synchronisation).",
                        ),
                        backgroundColor: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    );
                    _loadReport();
                  },
                  child: const Text(
                    "Enregistrer la Dépense",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCollected = (_report['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (_report['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final netBalance = (_report['netBalance'] as num?)?.toDouble() ?? (totalCollected - totalExpenses);
    final totalDebts = (_report['totalDebts'] as num?)?.toDouble() ?? 0.0;
    final expenseRatio = (_report['expenseRatio'] as num?)?.toInt() ?? 0;

    final recentPayments = (_report['recentPayments'] as List?) ?? [];
    final recentExpenses = (_report['recentExpenses'] as List?) ?? [];

    final rawCat = _report['expensesByCategory'];
    final Map<String, double> expensesByCategory = {};
    if (rawCat is Map) {
      rawCat.forEach((k, v) => expensesByCategory[k.toString()] = (v as num?)?.toDouble() ?? 0.0);
    }

    final rawModes = _report['paymentsByMode'];
    final Map<String, double> paymentsByMode = {};
    if (rawModes is Map) {
      rawModes.forEach((k, v) => paymentsByMode[k.toString()] = (v as num?)?.toDouble() ?? 0.0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Bilan Recettes vs Dépenses",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: "Imprimer le rapport",
            icon: const Icon(Icons.print_rounded, color: Color(0xFF4F46E5)),
            onPressed: _isExporting ? null : _printDirect,
          ),
          IconButton(
            tooltip: "Exporter PDF",
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48)),
            onPressed: _isExporting ? null : _exportPdf,
          ),
          IconButton(
            tooltip: "Actualiser",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReport,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE11D48),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text(
          "Ajouter Dépense",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: _showAddExpenseDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exporting indicator banner
                    if (_isExporting)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Génération du document officiel PDF...",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ),

                    // PERIOD TOGGLES & DATE SELECTOR
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildPeriodBtn("daily", "Jour"),
                          _buildPeriodBtn("monthly", "Mois"),
                          _buildPeriodBtn("yearly", "Année"),
                          _buildPeriodBtn("all", "Tout"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // DATE PICKER BUTTON
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          locale: const Locale('fr', 'FR'),
                          helpText: "Sélectionner la date du rapport",
                          cancelText: "Annuler",
                          confirmText: "Choisir",
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _loadReport();
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            Text(
                              _period == "daily"
                                  ? DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate)
                                  : _period == "monthly"
                                      ? DateFormat('MMMM yyyy', 'fr_FR').format(_selectedDate).toUpperCase()
                                      : _period == "yearly"
                                          ? "Année ${_selectedDate.year}"
                                          : "Toutes les dates",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // LEVEL / CYCLE SELECTOR (Auto En-tête Matching)
                    if (_availableLevels.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _availableLevels.map((lvl) {
                            final isSelected = _selectedLevel == lvl;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  lvl,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFF4F46E5),
                                backgroundColor: Colors.white,
                                elevation: isSelected ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _selectedLevel = lvl);
                                    _loadReport();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // OFFICIAL INSTITUTION HEADER CARD (MATCHING WEB)
                    _buildOfficialHeaderCard(),
                    const SizedBox(height: 12),

                    // TITLE BANNER (RAPPORT FINANCIER UNIFIÉ)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "RAPPORT FINANCIER UNIFIÉ (RECETTES VS DÉPENSES)",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            UnifiedFinancialReportPdfGenerator.getPeriodLabel(_period, _selectedDate).toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFDBEAFE),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4 SUMMARY CARDS
                    _buildKpiCard(
                      title: "Recettes Encaissées",
                      amount: totalCollected,
                      subtitle: "Frais scolaires perçus sur la période",
                      color: const Color(0xFF059669),
                      icon: Icons.arrow_downward_rounded,
                    ),
                    const SizedBox(height: 10),

                    _buildKpiCard(
                      title: "Charges & Dépenses",
                      amount: totalExpenses,
                      subtitle: "Ratio d'absorption: $expenseRatio% des recettes",
                      color: const Color(0xFFE11D48),
                      icon: Icons.arrow_upward_rounded,
                    ),
                    const SizedBox(height: 10),

                    _buildKpiCard(
                      title: "Solde Net Trésorerie",
                      amount: netBalance,
                      subtitle: netBalance >= 0 ? "Excédent disponible en caisse" : "Déficit d'exploitation temporaire",
                      color: netBalance >= 0 ? const Color(0xFF4F46E5) : const Color(0xFFE11D48),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    const SizedBox(height: 10),

                    _buildKpiCard(
                      title: "Créances & Impayés",
                      amount: totalDebts,
                      subtitle: "Impayés élèves à recouvrer",
                      color: const Color(0xFFD97706),
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(height: 20),

                    // ── BREAKDOWN SECTIONS (CATEGORIES & CHANNELS) ──
                    if (expensesByCategory.isNotEmpty || paymentsByMode.isNotEmpty) ...[
                      const Text(
                        "Répartition Analytique",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (expensesByCategory.isNotEmpty) ...[
                        _buildSectionHeader("Dépenses par Catégorie", const Color(0xFFE11D48)),
                        ...expensesByCategory.entries.map((e) {
                          final pct = totalExpenses > 0 ? ((e.value / totalExpenses) * 100).round() : 0;
                          return _buildMiniBreakdownTile(e.key, e.value, pct, const Color(0xFFE11D48));
                        }),
                        const SizedBox(height: 12),
                      ],
                      if (paymentsByMode.isNotEmpty) ...[
                        _buildSectionHeader("Recettes par Mode d'Encaissement", const Color(0xFF059669)),
                        ...paymentsByMode.entries.map((e) {
                          final pct = totalCollected > 0 ? ((e.value / totalCollected) * 100).round() : 0;
                          return _buildMiniBreakdownTile(e.key, e.value, pct, const Color(0xFF059669));
                        }),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // DUAL JOURNAL SECTION
                    const Text(
                      "Journal Récent des Flux",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Recent Payments
                    _buildSectionHeader("Derniers Encaissements (Recettes)", const Color(0xFF059669)),
                    if (recentPayments.isEmpty)
                      _buildEmptyList("Aucun encaissement sur cette période.")
                    else
                      ...recentPayments.map((p) {
                        final month = p['monthConcerned']?.toString();
                        final motif = (month != null && month.isNotEmpty)
                            ? "Scolarité ($month)"
                            : (p['description']?.toString() ?? p['motif']?.toString() ?? "Frais de scolarité");
                        final ref = p['reference']?.toString();
                        final dateStr = p['date']?.toString().split('T')[0] ?? '';
                        return _buildTransactionTile(
                          title: p['studentName'] ?? p['title'] ?? 'Paiement',
                          motif: motif,
                          subtitle: "${p['classe'] ?? '-'} • ${p['mode']} ${ref != null ? '• $ref ' : ''}• $dateStr",
                          amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
                          isIncome: true,
                        );
                      }),

                    const SizedBox(height: 16),

                    // Recent Expenses
                    _buildSectionHeader("Dernières Dépenses (Sorties)", const Color(0xFFE11D48)),
                    if (recentExpenses.isEmpty)
                      _buildEmptyList("Aucune dépense enregistrée sur cette période.")
                    else
                      ...recentExpenses.map((e) {
                        final desc = e['description']?.toString() ?? e['title']?.toString() ?? e['category']?.toString() ?? "Dépense";
                        final ref = e['reference']?.toString();
                        final dateStr = e['date']?.toString().split('T')[0] ?? '';
                        return _buildTransactionTile(
                          title: e['category'] ?? e['title'] ?? 'Dépense',
                          motif: desc,
                          subtitle: "${e['paymentMode'] ?? 'Espèces'} ${ref != null ? '• $ref ' : ''}• $dateStr",
                          amount: (e['amount'] as num?)?.toDouble() ?? 0.0,
                          isIncome: false,
                        );
                      }),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodBtn(String key, String label) {
    final active = _period == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _period = key);
          _loadReport();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4F46E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required double amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCfa(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBreakdownTile(String label, double amount, int pct, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$pct%",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatCfa(amount),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile({
    required String title,
    required String subtitle,
    String? motif,
    required double amount,
    required bool isIncome,
  }) {
    final color = isIncome ? const Color(0xFF059669) : const Color(0xFFE11D48);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (motif != null && motif.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        "Motif : ",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isIncome ? const Color(0xFF4F46E5) : const Color(0xFFE11D48),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          motif,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${isIncome ? '+' : '-'}${_formatCfa(amount)}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyList(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildOfficialHeaderCard() {
    final resolvedHeader = EducationalLevelHelper.getActiveLevelHeaderConfig(
      _headerConfig,
      targetLevel: _effectiveTargetLevel,
    );

    final country = resolvedHeader['country']?.toString() ?? 'RÉPUBLIQUE DU NIGER';
    final ministry = resolvedHeader['ministry']?.toString() ?? 'Ministère de l\'Éducation Nationale';
    final school = resolvedHeader['schoolName']?.toString() ?? 'ÉCOLE EXCELLENCE';
    final service = resolvedHeader['service']?.toString() ?? 'Service de la Scolarité';
    final address = resolvedHeader['address']?.toString() ?? 'Niamey, Niger';
    final phone = resolvedHeader['phone']?.toString() ?? resolvedHeader['schoolPhone']?.toString() ?? '+227 90 00 00 00';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ministry,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      school.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (service.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        service,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      "$address | Tél: $phone",
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Text(
                      "SESSION : $_sessionName",
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Édité le : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
