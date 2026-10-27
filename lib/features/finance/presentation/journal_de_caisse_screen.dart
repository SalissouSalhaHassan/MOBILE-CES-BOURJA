import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/educational_level_helper.dart';
import '../data/finance_repository.dart';
import '../utils/journal_de_caisse_pdf_generator.dart';
import '../utils/receipt_generator.dart';

class JournalDeCaisseScreen extends StatefulWidget {
  const JournalDeCaisseScreen({super.key});

  @override
  State<JournalDeCaisseScreen> createState() => _JournalDeCaisseScreenState();
}

class _JournalDeCaisseScreenState extends State<JournalDeCaisseScreen> {
  final FinanceRepository _repository = locator<FinanceRepository>();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  bool _isLoading = true;
  String? _errorMessage;
  int _schoolId = 1;
  int? _selectedSessionId;
  String _selectedSessionName = '';

  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _rawPayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  Map<String, dynamic>? _headerConfig;
  String? _userEducationalLevel;

  // Filter States
  String _classFilter = 'Toutes classes';
  String _levelFilter = 'Tous niveaux';
  String _cashierFilter = 'Tous caissiers';
  String _modeFilter = 'Tous modes';
  String _statusFilter = 'Tous';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _studentSearchController = TextEditingController();
  final TextEditingController _refSearchController = TextEditingController();

  // Export Paper Format
  PdfPageFormat _selectedPaperSize = PdfPageFormat.a4;
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _refSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionManager = locator<SessionManager>();
      final schoolIdStr = await sessionManager.getSchoolId();
      _schoolId = int.tryParse(schoolIdStr ?? '') ?? 1;
      _userEducationalLevel = await sessionManager.getEducationalLevel();
      if (_userEducationalLevel != null &&
          !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel)) {
        _levelFilter = _userEducationalLevel!;
      }

      // Parallel fetch: sessions, header config, and payments journal
      final sessionRes = await _repository.getSessions(_schoolId);
      _sessions = sessionRes;

      if (_sessions.isNotEmpty) {
        final activeSession = _sessions.firstWhere(
          (s) => s['is_active'] == true || (s['status']?.toString().toLowerCase() == 'actif'),
          orElse: () => _sessions.first,
        );
        _selectedSessionId = (activeSession['id'] as num?)?.toInt();
        _selectedSessionName = activeSession['session_name']?.toString() ?? '';
      }

      // Fetch document header
      try {
        final headerRes = await _repository.getDocumentHeader(_schoolId);
        if (headerRes['success'] == true) {
          _headerConfig = headerRes['data'] as Map<String, dynamic>?;
        }
      } catch (e) {
        debugPrint("Error fetching document header: $e");
      }

      await _fetchJournalData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur de chargement: $e";
      });
    }
  }

  Future<void> _fetchJournalData() async {
    try {
      final payments = await _repository.getPaymentsJournal(
        schoolId: _schoolId,
        sessionId: _selectedSessionId,
      );

      // If active session has no payments, try fallback without session restriction
      List<Map<String, dynamic>> finalPayments = payments;
      if (finalPayments.isEmpty && _selectedSessionId != null) {
        final allSessionPayments = await _repository.getPaymentsJournal(
          schoolId: _schoolId,
          sessionId: null,
        );
        if (allSessionPayments.isNotEmpty) {
          finalPayments = allSessionPayments;
        }
      }

      if (mounted) {
        setState(() {
          _rawPayments = finalPayments;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Impossible de récupérer les paiements: $e";
        });
      }
    }
  }

  void _applyFilters() {
    final studentQuery = _studentSearchController.text.trim().toLowerCase();
    final refQuery = _refSearchController.text.trim().toLowerCase();

    setState(() {
      _filteredPayments = _rawPayments.where((p) {
        // 0. User Educational Level Scoping
        if (_userEducationalLevel != null &&
            !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel)) {
          final lvl = (p['educational_level'] ?? '').toString();
          final cls = (p['classe'] ?? '').toString();
          final sec = (p['section'] ?? '').toString();
          final fil = (p['filiere'] ?? '').toString();
          // If fields are populated, check level. If both are empty and it's a pending offline payment, don't drop it.
          final hasLevelInfo = lvl.isNotEmpty || cls.isNotEmpty;
          if (hasLevelInfo && !EducationalLevelHelper.isStudentInEducationalLevel(
            educationalLevel: lvl,
            className: cls,
            sectionName: sec,
            filiere: fil,
            activeLevel: _userEducationalLevel,
          )) {
            return false;
          }
        }

        // 1. Classe
        if (_classFilter != 'Toutes classes') {
          final classe = (p['classe'] ?? '').toString();
          if (classe.toLowerCase() != _classFilter.toLowerCase()) return false;
        }

        // 2. Niveau
        if (_levelFilter != 'Tous niveaux') {
          final lvl = (p['educational_level'] ?? '').toString();
          final cls = (p['classe'] ?? '').toString();
          final stage = EducationalLevelHelper.inferEducationalStage(
            educationalLevel: lvl,
            className: cls,
          );
          final filterStage = EducationalLevelHelper.inferEducationalStage(
            educationalLevel: _levelFilter,
            className: _levelFilter,
          );
          if (stage != filterStage &&
              !lvl.toLowerCase().contains(_levelFilter.toLowerCase())) {
            return false;
          }
        }

        // 3. Caissier
        if (_cashierFilter != 'Tous caissiers') {
          final recordedBy = (p['recorded_by'] ?? '').toString();
          if (recordedBy.toLowerCase() != _cashierFilter.toLowerCase()) return false;
        }

        // 4. Mode Paiement
        if (_modeFilter != 'Tous modes') {
          final mode = (p['payment_mode'] ?? '').toString();
          if (mode.toLowerCase() != _modeFilter.toLowerCase()) return false;
        }

        // 5. Statut
        if (_statusFilter != 'Tous') {
          final status = (p['fee_status'] ?? '').toString().toLowerCase();
          final filter = _statusFilter.toLowerCase();
          final normStatus = status.replaceAll('é', 'e');
          final normFilter = filter.replaceAll('é', 'e');
          if (normStatus != normFilter && !status.contains(filter)) return false;
        }

        // 6. Dates
        if (p['date_paid'] != null) {
          try {
            final datePaid = DateTime.parse(p['date_paid'].toString());
            if (_startDate != null &&
                datePaid.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) {
              return false;
            }
            if (_endDate != null &&
                datePaid.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
              return false;
            }
          } catch (_) {}
        }

        // 7. Student Search
        if (studentQuery.isNotEmpty) {
          final name = (p['student_name'] ?? p['nom_etudiant'] ?? '').toString().toLowerCase();
          final matricule = (p['num_admission'] ?? '').toString().toLowerCase();
          if (!name.contains(studentQuery) && !matricule.contains(studentQuery)) return false;
        }

        // 8. Reference Search
        if (refQuery.isNotEmpty) {
          final ref = (p['reference'] ?? '').toString().toLowerCase();
          if (!ref.contains(refQuery)) return false;
        }

        return true;
      }).toList();
    });
  }

  bool get _isSessionFrozen {
    if (_selectedSessionId == null) return false;
    final current = _sessions.firstWhere(
      (s) => (s['id'] as num?)?.toInt() == _selectedSessionId,
      orElse: () => {},
    );
    if (current.isEmpty) return false;
    final status = current['status']?.toString().toLowerCase().trim() ?? '';
    final isActive = current['is_active'] == true;
    return !isActive ||
        status == 'clôturé' ||
        status == 'cloture' ||
        status == 'verrouillé' ||
        status == 'verrouille' ||
        status == 'archivé' ||
        status == 'archive';
  }

  void _showSessionSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "Sélectionner la Session",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final item = _sessions[index];
                      final id = (item['id'] as num?)?.toInt();
                      final name = item['session_name']?.toString() ?? '';
                      final isActive = item['is_active'] == true;
                      final status = item['status']?.toString().toLowerCase().trim() ?? '';
                      final isClosed = !isActive ||
                          status == 'clôturé' ||
                          status == 'cloture' ||
                          status == 'verrouillé' ||
                          status == 'verrouille' ||
                          status == 'archivé' ||
                          status == 'archive';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isClosed
                              ? Colors.amber.shade100
                              : (isActive ? AppColors.success.withAlpha(25) : AppColors.slate100),
                          child: Icon(
                            isClosed ? Icons.lock_clock_rounded : Icons.calendar_today,
                            color: isClosed
                                ? Colors.amber.shade800
                                : (isActive ? AppColors.success : AppColors.slate500),
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: id == _selectedSessionId ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isClosed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  border: Border.all(color: Colors.amber.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Clôturée 🔒",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: id == _selectedSessionId ? const Icon(Icons.check, color: AppColors.primary) : null,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedSessionId = id;
                            _selectedSessionName = name;
                            _isLoading = true;
                          });
                          _fetchJournalData();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetFilters() {
    setState(() {
      _classFilter = 'Toutes classes';
      _levelFilter = (_userEducationalLevel != null &&
              !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel))
          ? _userEducationalLevel!
          : 'Tous niveaux';
      _cashierFilter = 'Tous caissiers';
      _modeFilter = 'Tous modes';
      _statusFilter = 'Tous';
      _startDate = null;
      _endDate = null;
      _studentSearchController.clear();
      _refSearchController.clear();
      _applyFilters();
    });
  }

  // Unique Lists for Dropdowns
  List<String> get _uniqueClasses {
    final set = <String>{'Toutes classes'};
    for (final p in _rawPayments) {
      if (_userEducationalLevel != null &&
          !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel)) {
        final lvl = (p['educational_level'] ?? '').toString();
        final cls = (p['classe'] ?? '').toString();
        final sec = (p['section'] ?? '').toString();
        final fil = (p['filiere'] ?? '').toString();
        if (!EducationalLevelHelper.isStudentInEducationalLevel(
          educationalLevel: lvl,
          className: cls,
          sectionName: sec,
          filiere: fil,
          activeLevel: _userEducationalLevel,
        )) {
          continue;
        }
      }
      final c = p['classe']?.toString().trim();
      if (c != null && c.isNotEmpty && c != '-') set.add(c);
    }
    return set.toList();
  }

  List<String> get _uniqueLevels {
    if (_userEducationalLevel != null &&
        !EducationalLevelHelper.hasAllEducationalLevels(_userEducationalLevel)) {
      return [_userEducationalLevel!];
    }
    final set = <String>{'Tous niveaux', 'Primaire', 'Collège', 'Lycée', 'Université'};
    for (final p in _rawPayments) {
      final l = p['educational_level']?.toString().trim();
      if (l != null && l.isNotEmpty && l != '-') set.add(l);
    }
    return set.toList();
  }

  List<String> get _uniqueCashiers {
    final set = <String>{'Tous caissiers'};
    for (final p in _rawPayments) {
      final c = p['recorded_by']?.toString().trim();
      if (c != null && c.isNotEmpty) set.add(c);
    }
    return set.toList();
  }

  List<String> get _paymentModes => [
        'Tous modes',
        'Espèces',
        'Mobile Money',
        'Carte Bancaire',
        'Chèque',
        'Virement',
      ];

  List<String> get _statusOptions => [
        'Tous',
        'Soldé',
        'Partiel',
        'Impayé',
      ];

  // Totals & KPIs
  double get _totalCollected => _filteredPayments.fold(
        0.0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
      );

  double get _totalReductions => _filteredPayments.fold(
        0.0,
        (sum, p) => sum + ((p['reduction'] as num?)?.toDouble() ?? 0.0),
      );

  double get _totalExpected => _filteredPayments.fold(
        0.0,
        (sum, p) => sum + ((p['total_expected'] as num?)?.toDouble() ?? 0.0),
      );

  double get _recoveryRate => _totalExpected > 0 ? (_totalCollected / _totalExpected) * 100 : 0.0;

  String _formatCfa(double amount) {
    return '${_currencyFormat.format(amount).replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ')} CFA';
  }

  String get _filterSummaryText {
    final parts = <String>[];
    if (_classFilter != 'Toutes classes') parts.add('Classe: $_classFilter');
    if (_levelFilter != 'Tous niveaux') parts.add('Niveau: $_levelFilter');
    if (_cashierFilter != 'Tous caissiers') parts.add('Caissier: $_cashierFilter');
    if (_modeFilter != 'Tous modes') parts.add('Mode: $_modeFilter');
    if (_startDate != null) parts.add('Du: ${_dateFormat.format(_startDate!)}');
    if (_endDate != null) parts.add('Au: ${_dateFormat.format(_endDate!)}');
    if (parts.isEmpty) return 'Toutes transactions confondues';
    return parts.join(' | ');
  }

  // EXPORT ACTIONS
  Future<void> _exportPdf() async {
    try {
      final bytes = await JournalDeCaissePdfGenerator.generatePdfBytes(
        payments: _filteredPayments,
        totalCollected: _totalCollected,
        totalReductions: _totalReductions,
        totalExpected: _totalExpected,
        periodOrFilterDesc: _filterSummaryText,
        levelFilter: _levelFilter,
        classFilter: _classFilter,
        cashierFilter: _cashierFilter,
        headerConfig: _headerConfig,
        pageFormat: _selectedPaperSize,
      );

      final formatStr = _selectedPaperSize == PdfPageFormat.a5 ? 'A5' : 'A4';
      final fileName = 'journal_de_caisse_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}_$formatStr.pdf';

      await SharePlus.instance.share(
        ShareParams(
          text: 'Rapport Officiel — Journal de Caisse ($formatStr)',
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
          SnackBar(content: Text("Erreur lors de l'export PDF: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _printDirect() async {
    try {
      final bytes = await JournalDeCaissePdfGenerator.generatePdfBytes(
        payments: _filteredPayments,
        totalCollected: _totalCollected,
        totalReductions: _totalReductions,
        totalExpected: _totalExpected,
        periodOrFilterDesc: _filterSummaryText,
        levelFilter: _levelFilter,
        classFilter: _classFilter,
        cashierFilter: _cashierFilter,
        headerConfig: _headerConfig,
        pageFormat: _selectedPaperSize,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'journal_de_caisse_${_selectedPaperSize == PdfPageFormat.a5 ? "A5" : "A4"}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'impression: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final buffer = StringBuffer();
      // UTF-8 BOM for Excel
      buffer.write('\uFEFF');
      buffer.writeln('N°;Date;Reference;Eleve;Classe;Niveau;Mode;Caissier;Montant CFA');

      for (int i = 0; i < _filteredPayments.length; i++) {
        final p = _filteredPayments[i];
        final date = p['date_paid'] != null ? _dateFormat.format(DateTime.parse(p['date_paid'].toString())) : '-';
        final ref = (p['reference'] ?? '').toString().replaceAll(';', ',');
        final name = (p['student_name'] ?? p['nom_etudiant'] ?? '').toString().replaceAll(';', ',');
        final classe = (p['classe'] ?? '').toString().replaceAll(';', ',');
        final level = (p['educational_level'] ?? '').toString().replaceAll(';', ',');
        final mode = (p['payment_mode'] ?? '').toString().replaceAll(';', ',');
        final cashier = (p['recorded_by'] ?? '').toString().replaceAll(';', ',');
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;

        buffer.writeln('${i + 1};$date;$ref;$name;$classe;$level;$mode;$cashier;${amount.toStringAsFixed(0)}');
      }

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final fileName = 'journal_de_caisse_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'text/csv',
            name: fileName,
          ),
        ],
        text: 'Export CSV — Journal de Caisse',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur export CSV: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0B0F19);
    const cardDark = Color(0xFF131A2A);
    const borderDark = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Journal de caisse",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            Row(
              children: [
                Text(
                  _selectedSessionName.isNotEmpty ? "Session : $_selectedSessionName" : "Gestion Financière",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
                if (_isSessionFrozen) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withAlpha(80),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade600, width: 0.5),
                    ),
                    child: const Text(
                      "🔒 Clôturée",
                      style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF818CF8)),
            onPressed: _showSessionSelector,
            tooltip: "Changer de Session",
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded, color: const Color(0xFF38BDF8)),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: _showFilters ? "Masquer filtres" : "Afficher filtres",
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadInitialData,
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                          child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchJournalData,
                  color: const Color(0xFF38BDF8),
                  backgroundColor: cardDark,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. FILTRES AVANCÉS (Collapsible)
                        if (_showFilters) _buildAdvancedFiltersCard(cardDark, borderDark),

                        const SizedBox(height: 12),

                        // 2. RAPPORT ACTUEL & QUICK ACTIONS
                        _buildReportHeaderAndActions(cardDark, borderDark),

                        const SizedBox(height: 12),

                        // 3. KPI SUMMARY CARDS (4 cards)
                        _buildKpiCardsGrid(),

                        const SizedBox(height: 16),

                        // 4. TRANSACTIONS TABLE / LIST
                        _buildTransactionsTableSection(cardDark, borderDark),

                        const SizedBox(height: 16),

                        // 5. CLOUD SYNC FOOTER
                        _buildSyncFooter(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  1. FILTRES AVANCÉS CARD (MATCHING WEB SCREENSHOT)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAdvancedFiltersCard(Color cardBg, Color borderCol) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text(
                    "FILTRES AVANCÉS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 14, color: Color(0xFF94A3B8)),
                label: const Text("Réinitialiser", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
            ],
          ),
          // Row 0: Session Scolaire
          if (_sessions.isNotEmpty) ...[
            _buildDarkDropdown(
              label: "ANNÉE / SESSION SCOLAIRE",
              value: _selectedSessionId != null
                  ? (_sessions.firstWhere(
                      (s) => (s['id'] as num?)?.toInt() == _selectedSessionId,
                      orElse: () => {'session_name': 'Toutes les sessions'},
                    )['session_name']?.toString() ?? 'Toutes les sessions')
                  : 'Toutes les sessions',
              items: [
                'Toutes les sessions',
                ..._sessions.map((s) => s['session_name']?.toString() ?? '').where((s) => s.isNotEmpty),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  if (val == 'Toutes les sessions') {
                    _selectedSessionId = null;
                    _selectedSessionName = 'Toutes les sessions';
                  } else {
                    final found = _sessions.firstWhere(
                      (s) => s['session_name']?.toString() == val,
                      orElse: () => {},
                    );
                    _selectedSessionId = (found['id'] as num?)?.toInt();
                    _selectedSessionName = val;
                  }
                  _isLoading = true;
                });
                _fetchJournalData();
              },
            ),
            const SizedBox(height: 10),
          ],

          // Row 1: Classe & Niveau
          Row(
            children: [
              Expanded(
                child: _buildDarkDropdown(
                  label: "CLASSE",
                  value: _classFilter,
                  items: _uniqueClasses,
                  onChanged: (val) {
                    if (val != null) {
                      _classFilter = val;
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDarkDropdown(
                  label: "NIVEAU",
                  value: _levelFilter,
                  items: _uniqueLevels,
                  onChanged: (val) {
                    if (val != null) {
                      _levelFilter = val;
                      _applyFilters();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Caissier & Mode Paiement
          Row(
            children: [
              Expanded(
                child: _buildDarkDropdown(
                  label: "CAISSIER",
                  value: _cashierFilter,
                  items: _uniqueCashiers,
                  onChanged: (val) {
                    if (val != null) {
                      _cashierFilter = val;
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDarkDropdown(
                  label: "MODE PAIEMENT",
                  value: _modeFilter,
                  items: _paymentModes,
                  onChanged: (val) {
                    if (val != null) {
                      _modeFilter = val;
                      _applyFilters();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Statut & Dates
          Row(
            children: [
              Expanded(
                child: _buildDarkDropdown(
                  label: "STATUT",
                  value: _statusFilter,
                  items: _statusOptions,
                  onChanged: (val) {
                    if (val != null) {
                      _statusFilter = val;
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDatePickerField(
                  label: "DATE DÉBUT",
                  date: _startDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                      _applyFilters();
                    }
                  },
                  onClear: () {
                    setState(() => _startDate = null);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDatePickerField(
                  label: "DATE FIN",
                  date: _endDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                      _applyFilters();
                    }
                  },
                  onClear: () {
                    setState(() => _endDate = null);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 4: Élève & Référence search
          Row(
            children: [
              Expanded(
                child: _buildDarkSearchInput(
                  controller: _studentSearchController,
                  label: "ÉLÈVE",
                  hint: "Rechercher...",
                  icon: Icons.person_search_rounded,
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDarkSearchInput(
                  controller: _refSearchController,
                  label: "RÉFÉRENCE",
                  hint: "REC-XXXX...",
                  icon: Icons.receipt_rounded,
                  onChanged: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDarkDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: const Color(0xFF131A2A),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? _dateFormat.format(date) : "jj/mm/aaaa",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: date != null ? Colors.white : const Color(0xFF64748B),
                    fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Icon(
                  date != null ? Icons.event_available_rounded : Icons.calendar_today_rounded,
                  size: 13,
                  color: date != null ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDarkSearchInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              prefixIcon: Icon(icon, size: 14, color: const Color(0xFF64748B)),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14, color: Color(0xFF64748B)),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  2. REPORT HEADER & ACTIONS (MATCHING WEB SCREENSHOT)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildReportHeaderAndActions(Color cardBg, Color borderCol) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "RAPPORT ACTUEL",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Journal de caisse",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // A4 / A5 Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPaperChip("A4", _selectedPaperSize == PdfPageFormat.a4, () {
                      setState(() => _selectedPaperSize = PdfPageFormat.a4);
                    }),
                    _buildPaperChip("A5", _selectedPaperSize == PdfPageFormat.a5, () {
                      setState(() => _selectedPaperSize = PdfPageFormat.a5);
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons Row: PDF | EXCEL | CSV | IMPRIMER
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  label: "PDF (${_selectedPaperSize == PdfPageFormat.a5 ? "A5" : "A4"})",
                  icon: Icons.picture_as_pdf_rounded,
                  bgColor: const Color(0xFFE11D48).withOpacity(0.15),
                  textColor: const Color(0xFFFB7185),
                  borderColor: const Color(0xFFE11D48).withOpacity(0.4),
                  onTap: _exportPdf,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: "EXCEL",
                  icon: Icons.table_chart_rounded,
                  bgColor: const Color(0xFF059669).withOpacity(0.15),
                  textColor: const Color(0xFF34D399),
                  borderColor: const Color(0xFF059669).withOpacity(0.4),
                  onTap: _exportCsv,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: "CSV",
                  icon: Icons.download_rounded,
                  bgColor: const Color(0xFF6366F1).withOpacity(0.15),
                  textColor: const Color(0xFF818CF8),
                  borderColor: const Color(0xFF6366F1).withOpacity(0.4),
                  onTap: _exportCsv,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: "IMPRIMER",
                  icon: Icons.print_rounded,
                  bgColor: const Color(0xFF1E293B),
                  textColor: Colors.white,
                  borderColor: const Color(0xFF334155),
                  onTap: _printDirect,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  3. KPI CARDS GRID (EXACT MATCHING 4 CARDS)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildKpiCardsGrid() {
    return Row(
      children: [
        // 1. ENCAISSÉ FILTRÉ
        Expanded(
          child: _buildMetricCard(
            title: "ENCAISSÉ FILTRÉ",
            value: _formatCfa(_totalCollected),
            valueColor: const Color(0xFF10B981),
            icon: Icons.attach_money_rounded,
            iconBg: const Color(0xFF10B981).withOpacity(0.12),
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),

        // 2. REMISES FILTRÉES
        Expanded(
          child: _buildMetricCard(
            title: "REMISES FILTRÉES",
            value: _formatCfa(_totalReductions),
            valueColor: const Color(0xFFF59E0B),
            icon: Icons.south_east_rounded,
            iconBg: const Color(0xFFF59E0B).withOpacity(0.12),
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),

        // 3. TRANSACTIONS
        Expanded(
          child: _buildMetricCard(
            title: "TRANSACTIONS",
            value: "${_filteredPayments.length}",
            valueColor: const Color(0xFF38BDF8),
            icon: Icons.layers_rounded,
            iconBg: const Color(0xFF38BDF8).withOpacity(0.12),
            iconColor: const Color(0xFF38BDF8),
          ),
        ),
        const SizedBox(width: 8),

        // 4. TAUX RECOUVREMENT
        Expanded(
          child: _buildMetricCard(
            title: "TAUX RECOUVREMENT",
            value: "${_recoveryRate.toStringAsFixed(1)}%",
            valueColor: Colors.white,
            icon: Icons.timelapse_rounded,
            iconBg: Colors.white.withOpacity(0.08),
            iconColor: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: valueColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  4. TRANSACTIONS TABLE (MATCHING WEB TABLE SCREENSHOT)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTransactionsTableSection(Color cardBg, Color borderCol) {
    if (_filteredPayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFF64748B)),
            SizedBox(height: 12),
            Text(
              "Aucune transaction enregistrée avec ces filtres.",
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "DÉTAIL DES TRANSACTIONS (${_filteredPayments.length})",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE2E8F0),
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  "Faites défiler horizontalement ➔",
                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          // Horizontally Scrollable Exact Web Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFF0F172A)),
              headingTextStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
              dataTextStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              horizontalMargin: 12,
              columnSpacing: 18,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text("N°")),
                DataColumn(label: Text("DATE")),
                DataColumn(label: Text("RÉFÉRENCE")),
                DataColumn(label: Text("ÉLÈVE")),
                DataColumn(label: Text("CLASSE")),
                DataColumn(label: Text("MODE")),
                DataColumn(label: Text("CAISSIER")),
                DataColumn(label: Text("MONTANT", textAlign: TextAlign.right), numeric: true),
                DataColumn(label: Text("ACTION")),
              ],
              rows: _filteredPayments.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final p = entry.value;
                final pDate = p['date_paid'] != null
                    ? _dateFormat.format(DateTime.parse(p['date_paid'].toString()))
                    : '-';
                final pRef = p['reference']?.toString() ?? 'REC-${p['id']}';
                final pStudent = p['student_name']?.toString() ?? p['nom_etudiant']?.toString() ?? 'Élève';
                final pClass = p['classe']?.toString() ?? '-';
                final pMode = p['payment_mode']?.toString() ?? 'Espèces';
                final pCashier = p['recorded_by']?.toString() ?? 'Admin';
                final pAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;

                return DataRow(
                  color: MaterialStateProperty.resolveWith((states) {
                    return idx.isEven ? const Color(0xFF131A2A) : const Color(0xFF0F172A).withOpacity(0.5);
                  }),
                  cells: [
                    DataCell(Text("$idx", style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                    DataCell(Text(pDate, style: const TextStyle(color: Color(0xFFCBD5E1)))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(pRef, style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                          if (p['is_pending_sync'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.cloud_upload_outlined, size: 12, color: Color(0xFFF59E0B)),
                          ],
                        ],
                      ),
                    ),
                    DataCell(Text(pStudent.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                    DataCell(Text(pClass.toUpperCase(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10))),
                    DataCell(Text(pMode, style: const TextStyle(color: Color(0xFFE2E8F0)))),
                    DataCell(Text(pCashier, style: const TextStyle(color: Color(0xFF94A3B8)))),
                    DataCell(
                      Text(
                        _formatCfa(pAmount),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.receipt_rounded, size: 18, color: Color(0xFF38BDF8)),
                        tooltip: "Reçu officiel",
                        onPressed: () => _openTransactionReceipt(p),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          // Table Footer Row (Total Encaissé)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOTAL ENCAISSÉ :",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFCBD5E1),
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _formatCfa(_totalCollected),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openTransactionReceipt(Map<String, dynamic> payment) async {
    try {
      final student = {
        'nom_etudiant': payment['student_name'] ?? payment['nom_etudiant'] ?? 'Élève',
        'num_admission': payment['num_admission'] ?? payment['matricule'] ?? '—',
        'classe': payment['classe'] ?? '—',
        'educational_level': payment['educational_level'] ?? '',
      };

      final totalExpected = (payment['total_expected'] as num?)?.toDouble() ?? (payment['amount'] as num?)?.toDouble() ?? 0.0;
      final balance = (payment['balance'] as num?)?.toDouble() ?? 0.0;

      await ReceiptGenerator.showFormatAndActionDialog(
        context: context,
        student: student,
        payment: payment,
        totalExpected: totalExpected,
        remainingBalance: balance,
        headerConfig: _headerConfig,
      );
    } catch (e) {
      debugPrint("Error opening receipt dialog: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible de générer le reçu : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  5. SYNCHRONISATION FOOTER (MATCHING WEB SCREENSHOT CORNER BADGE)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSyncFooter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
            SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "SYNCHRONISÉ",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "Connexion cloud stable",
                  style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
