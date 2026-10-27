import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/type_converters.dart';
import '../data/hr_repository.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen>
    with SingleTickerProviderStateMixin {
  final HrRepository _repository = locator<HrRepository>();
  final TextEditingController _employeeSearchController =
      TextEditingController();
  final TextEditingController _payrollMonthController =
      TextEditingController();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isComputingPayroll = false;
  bool _canManageHr = false;
  bool _isSessionFrozen = false;
  final DateTime _attendanceDate = DateTime.now();

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _salaryRecords = [];
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic> _payrollRules = {};
  Map<String, dynamic> _stats = {};

  static const List<String> _frenchMonths = [
    '',
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre'
  ];

  static const List<String> _frenchDays = [
    '',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  static String _formatFrenchMonth(DateTime dt) {
    final m = (dt.month >= 1 && dt.month <= 12) ? _frenchMonths[dt.month] : '';
    return '$m ${dt.year}'.trim();
  }

  static String _formatFrenchFullDate(DateTime dt) {
    final dayName = (dt.weekday >= 1 && dt.weekday <= 7) ? _frenchDays[dt.weekday] : '';
    final m = (dt.month >= 1 && dt.month <= 12) ? _frenchMonths[dt.month] : '';
    return '$dayName ${dt.day} $m ${dt.year}'.trim();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _payrollMonthController.text = _formatFrenchMonth(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _employeeSearchController.dispose();
    _payrollMonthController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await locator<PermissionService>().getCurrentProfile();
      final isFrozen = _repository.isSessionFrozen();
      if (!mounted) return;
      setState(() => _isLoading = true);

      final dashboard = await _repository.getHrDashboardData();
      final rules = await _repository.getPayrollRules();

      if (!mounted) return;
      setState(() {
        _isSessionFrozen = isFrozen;
        _employees = List<Map<String, dynamic>>.from(dashboard['employees'] ?? []);
        _salaryRecords =
            List<Map<String, dynamic>>.from(dashboard['salaryRecords'] ?? []);
        _attendance = List<Map<String, dynamic>>.from(dashboard['attendance'] ?? []);
        _stats = Map<String, dynamic>.from(dashboard['stats'] ?? {});
        _payrollRules = Map<String, dynamic>.from(rules);
        _canManageHr = profile.permissions.contains(AppPermissions.hrManage) ||
            profile.role.toLowerCase().contains('admin') ||
            profile.role.toLowerCase().contains('direct');
        _isLoading = false;
      });
      _applyEmployeeSearch();
    } catch (e) {
      debugPrint('Error loading HR data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyEmployeeSearch() {
    final query = _employeeSearchController.text.trim().toLowerCase();
    final filtered = _employees.where((employee) {
      final name = (employee['nom'] ?? '').toString().toLowerCase();
      final empId = (employee['emp_id'] ?? '').toString().toLowerCase();
      final poste = (employee['poste'] ?? '').toString().toLowerCase();
      final department = (employee['departement'] ?? '').toString().toLowerCase();
      return query.isEmpty ||
          name.contains(query) ||
          empId.contains(query) ||
          poste.contains(query) ||
          department.contains(query);
    }).toList();

    setState(() => _filteredEmployees = filtered);
  }

  Future<void> _openEmployeeForm([Map<String, dynamic>? employee]) async {
    if (_isSessionFrozen) {
      _showMessage("Année scolaire clôturée ou verrouillée : Modification des employés impossible.");
      return;
    }
    final empIdController =
        TextEditingController(text: employee?['emp_id']?.toString() ?? '');
    final nameController =
        TextEditingController(text: employee?['nom']?.toString() ?? '');
    final posteController =
        TextEditingController(text: employee?['poste']?.toString() ?? '');
    final departmentController =
        TextEditingController(text: employee?['departement']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: employee?['mobile']?.toString() ?? '');
    final emailController =
        TextEditingController(text: employee?['email']?.toString() ?? '');
    final salaryController = TextEditingController(
      text: ((employee?['salaire_base'] as num?)?.toDouble() ?? 0).toString(),
    );
    var status = (employee?['statut'] ?? 'Actif').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee == null ? 'Nouvel Employé' : 'Modifier l\'Employé',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 16),
                      _textField('Matricule Agent (ex: EMP-2025-001)', empIdController),
                      const SizedBox(height: 10),
                      _textField('Nom et Prénoms', nameController),
                      const SizedBox(height: 10),
                      _textField('Poste / Fonction', posteController),
                      const SizedBox(height: 10),
                      _textField('Département / Service', departmentController),
                      const SizedBox(height: 10),
                      _textField('Téléphone Mobile', phoneController),
                      const SizedBox(height: 10),
                      _textField('Adresse Email', emailController),
                      const SizedBox(height: 10),
                      _textField(
                        'Salaire de base (FCFA)',
                        salaryController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const ['Actif', 'Inactif', 'En congé']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => status = value ?? 'Actif');
                        },
                        decoration: _decoration('Statut Professionnel'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  final result = await _repository.saveEmployee(
                                    employeeId: employee?['id'] as int?,
                                    payload: {
                                      'emp_id': empIdController.text.trim(),
                                      'nom': nameController.text.trim(),
                                      'poste': posteController.text.trim(),
                                      'departement':
                                          departmentController.text.trim(),
                                      'mobile': phoneController.text.trim(),
                                      'email': emailController.text.trim(),
                                      'salaire_base': double.tryParse(
                                            salaryController.text.trim(),
                                          ) ??
                                          0,
                                      'statut': status,
                                    },
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  _showMessage(
                                    result['success'] == true
                                        ? '✅ Employé enregistré avec succès.'
                                        : (result['error']?.toString() ??
                                            'Erreur lors de l\'enregistrement.'),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isSaving ? 'Enregistrement en cours...' : 'Enregistrer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEmployee(int employeeId) async {
    if (_isSessionFrozen) {
      _showMessage("Année scolaire clôturée ou verrouillée : Suppression impossible.");
      return;
    }
    final result = await _repository.deleteEmployee(employeeId);
    if (!mounted) return;
    _showMessage(
      result['success'] == true
          ? 'Employé supprimé.'
          : (result['error']?.toString() ?? 'Erreur suppression'),
    );
    if (result['success'] == true) {
      await _load();
    }
  }

  Future<void> _openAttendanceSheet() async {
    if (_isSessionFrozen) {
      _showMessage("Année scolaire clôturée ou verrouillée : Pointage des présences impossible.");
      return;
    }
    final attendanceRows = await _repository.getEmployeeAttendance(
      DateFormat('yyyy-MM-dd').format(_attendanceDate),
    );
    if (!mounted) return;

    final records = {
      for (final row in attendanceRows) row['employee_id'] as int: row,
    };
    final draft = _employees
        .map(
          (employee) => {
            'employee_id': employee['id'],
            'name': employee['nom'],
            'status':
                _normalizeAttendanceStatus(
                  (records[employee['id']]?['status'] ?? 'Présent').toString(),
                ),
          },
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pointage du Jour', style: AppTextStyles.heading2),
                    const SizedBox(height: 4),
                    Text(
                      _formatFrenchFullDate(_attendanceDate),
                      style: AppTextStyles.body.copyWith(color: AppColors.slate600),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: draft.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = draft[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEBF0F5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (row['name'] ?? 'Employé').toString(),
                                    style: AppTextStyles.bodyBold,
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: row['status'] as String,
                                  items: const [
                                    'Présent',
                                    'Absent',
                                    'En Retard',
                                    'En Congé',
                                  ]
                                      .map(
                                        (status) => DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(status),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      row['status'] = _normalizeAttendanceStatus(
                                        value ?? 'Présent',
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                final result =
                                    await _repository.saveEmployeeAttendance(
                                  dateStr: DateFormat('yyyy-MM-dd')
                                      .format(_attendanceDate),
                                  records: draft
                                      .map(
                                        (row) => {
                                          'employee_id': row['employee_id'],
                                          'status': row['status'],
                                        },
                                      )
                                      .toList(),
                                );
                                if (!mounted) return;
                                setState(() => _isSaving = false);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                _showMessage(
                                  result['success'] == true
                                      ? '✅ Pointage enregistré avec succès.'
                                      : (result['error']?.toString() ??
                                          'Erreur pointage'),
                                );
                                if (result['success'] == true) {
                                  await _load();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isSaving ? 'Enregistrement en cours...' : 'Valider le pointage',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPayrollForm([Map<String, dynamic>? initialRecord]) async {
    if (_isSessionFrozen) {
      _showMessage("Année scolaire clôturée ou verrouillée : Fiches de paie verrouillées.");
      return;
    }
    Map<String, dynamic>? record = initialRecord == null
        ? null
        : Map<String, dynamic>.from(initialRecord);
    int? selectedEmployeeId =
        record?['employee_id'] as int? ??
            (_employees.isNotEmpty ? _employees.first['id'] as int : null);
    final monthController = TextEditingController(
      text: record?['month_year']?.toString() ?? _payrollMonthController.text,
    );
    final allowanceController = TextEditingController(
      text: TypeConverters.safeDouble(record?['total_allowance']).toString(),
    );
    final deductionController = TextEditingController(
      text: TypeConverters.safeDouble(record?['total_deduction']).toString(),
    );
    var status = _normalizeSalaryStatus(
      (record?['status'] ?? 'Unpaid').toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final employee = _employees.firstWhere(
              (row) => row['id'] == selectedEmployeeId,
              orElse: () => <String, dynamic>{},
            );
            final baseSalary =
                TypeConverters.safeDouble(employee['salaire_base']);
            final attendanceSummary = _salaryAttendanceSummaryFromRecord(record);
            final latePenalty =
                TypeConverters.safeDouble(_payrollRules['late_penalty']);
            final halfPenalty =
                TypeConverters.safeDouble(_payrollRules['half_day_penalty']);
            final absentDays = TypeConverters.safeInt(attendanceSummary['absent']);
            final lateDays = TypeConverters.safeInt(attendanceSummary['late']);
            final leaveDays = TypeConverters.safeInt(attendanceSummary['leave']);
            final computedDeduction = absentDays * latePenalty * 10 +
                lateDays * latePenalty +
                leaveDays * halfPenalty;
            final extraAllowance =
                double.tryParse(allowanceController.text.trim()) ?? 0;
            final extraDeduction =
                double.tryParse(deductionController.text.trim()) ?? 0;
            final netSalary =
                (baseSalary + extraAllowance) - (computedDeduction + extraDeduction);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fiche de Paie', style: AppTextStyles.heading2),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedEmployeeId,
                        items: _employees
                            .map(
                              (employee) => DropdownMenuItem<int>(
                                value: employee['id'] as int,
                                child: Text(
                                  '${employee['nom']} - ${employee['poste'] ?? '-'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => selectedEmployeeId = value);
                        },
                        decoration: _decoration('Employé'),
                      ),
                      const SizedBox(height: 10),
                      _textField('Mois (ex: Août 2026)', monthController),
                      const SizedBox(height: 10),
                      _textField(
                        'Primes & Indemnités (FCFA)',
                        allowanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        'Retenues & Cotisations (FCFA)',
                        deductionController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const ['Unpaid', 'Paid']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item == 'Paid' ? 'Payé' : 'En attente'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => status = value ?? 'Unpaid');
                        },
                        decoration: _decoration('Statut de Paiement'),
                      ),
                      const SizedBox(height: 16),
                      _summaryCard([
                        'Salaire de base: ${_money(baseSalary)}',
                        'Absences: $absentDays jour(s)',
                        'Retards: $lateDays fois',
                        'Congés: $leaveDays jour(s)',
                        'Retenue calculée: ${_money(computedDeduction)}',
                        'Net estimé: ${_money(netSalary)}',
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isComputingPayroll
                              ? null
                              : () async {
                                  if (selectedEmployeeId == null) {
                                    _showMessage('Veuillez sélectionner un employé.');
                                    return;
                                  }
                                  setState(() => _isComputingPayroll = true);
                                  final summary = await _repository
                                      .getEmployeeAttendanceSummary(
                                    employeeId: selectedEmployeeId!,
                                    monthYear: monthController.text.trim(),
                                  );
                                  if (!mounted) return;
                                  setState(() => _isComputingPayroll = false);
                                  setModalState(() {
                                    record = {
                                      ...?record,
                                      'absent_days': summary['absents'] ?? 0,
                                      'late_days': summary['retards'] ?? 0,
                                      'leave_taken': summary['conges'] ?? 0,
                                    };
                                  });
                                },
                          icon: const Icon(Icons.calculate_outlined),
                          label: Text(
                            _isComputingPayroll
                                ? 'Calcul en cours...'
                                : 'Charger le résumé du mois',
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  if (selectedEmployeeId == null) {
                                    _showMessage('Veuillez sélectionner un employé.');
                                    return;
                                  }
                                  setState(() => _isSaving = true);
                                  final result = await _repository.saveSalaryRecord(
                                    recordId: record?['id'] as int?,
                                    payload: {
                                      'employee_id': selectedEmployeeId,
                                      'month_year': monthController.text.trim(),
                                      'absent_days': absentDays,
                                      'leave_taken': leaveDays,
                                      'late_days': lateDays,
                                      'half_days': 0,
                                      'basic_salary': baseSalary,
                                      'calculated_basic': baseSalary,
                                      'total_allowance': extraAllowance,
                                      'total_deduction':
                                          computedDeduction + extraDeduction,
                                      'net_salary': netSalary,
                                      'status': _normalizeSalaryStatus(status),
                                      if (_normalizeSalaryStatus(status) == 'Paid')
                                        'payment_date':
                                            DateTime.now().toIso8601String(),
                                    },
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  _showMessage(
                                    result['success'] == true
                                        ? '✅ Fiche de paie enregistrée avec succès.'
                                        : (result['error']?.toString() ??
                                            'Erreur paie'),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isSaving ? 'Enregistrement en cours...' : 'Enregistrer la fiche',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, int> _salaryAttendanceSummaryFromRecord(
    Map<String, dynamic>? record,
  ) {
    return {
      'absent': TypeConverters.safeInt(record?['absent_days']),
      'late': TypeConverters.safeInt(record?['late_days']),
      'leave': TypeConverters.safeInt(record?['leave_taken']),
    };
  }

  Future<void> _savePayrollRules() async {
    if (_isSessionFrozen) {
      _showMessage("Année scolaire clôturée ou verrouillée : Modification des règles de paie impossible.");
      return;
    }
    final leaveController = TextEditingController(
      text: TypeConverters.safeInt(_payrollRules['leave_allow_per_month'], 1).toString(),
    );
    final lateController = TextEditingController(
      text: TypeConverters.safeDouble(_payrollRules['late_penalty'], 0.5).toString(),
    );
    final halfController = TextEditingController(
      text: TypeConverters.safeDouble(_payrollRules['half_day_penalty'], 0.5).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Règles de Paie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(
                  'Congés autorisés / mois',
                  leaveController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _textField(
                  'Pénalité retard (jours)',
                  lateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 10),
                _textField(
                  'Pénalité demi-journée',
                  halfController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await _repository.savePayrollRules({
                  'leave_allow_per_month':
                      int.tryParse(leaveController.text.trim()) ?? 1,
                  'late_penalty':
                      double.tryParse(lateController.text.trim()) ?? 0.5,
                  'half_day_penalty':
                      double.tryParse(halfController.text.trim()) ?? 0.5,
                });
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                _showMessage(
                  result['success'] == true
                      ? '✅ Règles enregistrées avec succès.'
                      : (result['error']?.toString() ?? 'Erreur règles'),
                );
                if (result['success'] == true) {
                  await _load();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _normalizeAttendanceStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('present') || normalized.contains('présent')) {
      return 'Présent';
    }
    if (normalized.contains('absent')) {
      return 'Absent';
    }
    if (normalized.contains('retard') || normalized.contains('late')) {
      return 'En Retard';
    }
    if (normalized.contains('conge') || normalized.contains('congé')) {
      return 'En Congé';
    }
    if (normalized.contains('non pointe') || normalized.contains('non pointé')) {
      return 'Non Pointé';
    }
    return value.trim().isEmpty ? 'Absent' : value.trim();
  }

  String _normalizeSalaryStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'paid' || normalized == 'paye' || normalized == 'payé') {
      return 'Paid';
    }
    return 'Unpaid';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Ressources Humaines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/teacher-reports'),
            icon: const Icon(Icons.timeline_rounded),
            tooltip: 'Rapports présence enseignant',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.slate500,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: const [
            Tab(text: 'Vue'),
            Tab(text: 'Employés'),
            Tab(text: 'Paie'),
            Tab(text: 'Rapports'),
          ],
        ),
      ),
      floatingActionButton: (_canManageHr && !_isSessionFrozen)
          ? FloatingActionButton.extended(
              onPressed: () {
                switch (_tabController.index) {
                  case 1:
                    _openEmployeeForm();
                    break;
                  case 2:
                    _openPayrollForm();
                    break;
                  default:
                    _openAttendanceSheet();
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icon(
                _tabController.index == 2
                    ? Icons.payments_outlined
                    : _tabController.index == 1
                        ? Icons.person_add_alt_1_rounded
                        : Icons.playlist_add_check_circle_outlined,
              ),
              label: Text(
                _tabController.index == 2
                    ? 'Fiche de Paie'
                    : _tabController.index == 1
                        ? 'Employé'
                        : 'Pointage',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildEmployeesTab(),
                _buildPayrollTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildFreezeWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, color: Color(0xFFB45309), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Année scolaire clôturée ou verrouillée : Mode consultation seule. La gestion des employés, les pointages et les salaires sont gelés.",
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isSessionFrozen) _buildFreezeWarningBanner(),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _statCard(
                'Actifs',
                '${_stats['activeEmployees'] ?? 0}',
                Icons.groups_rounded,
                const Color(0xFF3B82F6),
              ),
              _statCard(
                'Présents',
                '${_stats['presentToday'] ?? 0}',
                Icons.fact_check_rounded,
                const Color(0xFF10B981),
              ),
              _statCard(
                'Payée',
                _money(_stats['paidAmount']),
                Icons.paid_rounded,
                const Color(0xFF059669),
              ),
              _statCard(
                'À payer',
                _money(_stats['unpaidAmount']),
                Icons.money_off_csred_rounded,
                const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Opérations rapides',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _actionChip(
                  'Pointage du jour',
                  Icons.how_to_reg_rounded,
                  _openAttendanceSheet,
                ),
                _actionChip(
                  'Règles de paie',
                  Icons.rule_folder_outlined,
                  _savePayrollRules,
                ),
                _actionChip(
                  'Rapports enseignant',
                  Icons.school_outlined,
                  () => context.push('/attendance/teacher-reports'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Présence du jour',
            child: _employees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Aucun employé enregistré.',
                        style: TextStyle(color: AppColors.slate500, fontSize: 13),
                      ),
                    ),
                  )
                : Column(
                    children: _employees.take(6).map((employee) {
                      final matches = _attendance
                          .where((row) => row['employee_id'] == employee['id'])
                          .toList();
                      final status = matches.isEmpty
                          ? 'Non Pointé'
                          : _normalizeAttendanceStatus(
                              (matches.first['status'] ?? 'Non Pointé').toString(),
                            );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEEF2FF),
                          child: Icon(
                            Icons.person_outline,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          (employee['nom'] ?? 'Employé').toString(),
                          style: AppTextStyles.bodyBold,
                        ),
                        subtitle: Text((employee['poste'] ?? '-').toString()),
                        trailing: _statusPill(status),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return Column(
      children: [
        if (_isSessionFrozen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildFreezeWarningBanner(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _employeeSearchController,
            onChanged: (_) => _applyEmployeeSearch(),
            decoration: _decoration('Rechercher un employé...').copyWith(
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _filteredEmployees.isEmpty
              ? _emptyState('Aucun employé trouvé.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _filteredEmployees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final employee = _filteredEmployees[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEBF0F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFEEF2FF),
                                child: Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (employee['nom'] ?? 'Employé').toString(),
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    Text(
                                      '${employee['emp_id'] ?? '-'} - ${employee['poste'] ?? '-'}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              _statusPill(
                                (employee['statut'] ?? 'Actif').toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _infoChip(employee['departement'] ?? '-'),
                              _infoChip(employee['mobile'] ?? '-'),
                              _infoChip(employee['email'] ?? '-'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Salaire de base : ${_money(employee['salaire_base'])}',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_canManageHr)
                            if (_isSessionFrozen)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_rounded, size: 14, color: Color(0xFF94A3B8)),
                                    SizedBox(width: 4),
                                    Text('Modifications verrouillées (Session clôturée)',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _openEmployeeForm(employee),
                                    child: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      _payrollMonthController.text =
                                          _formatFrenchMonth(DateTime.now());
                                      await _openPayrollForm({
                                        'employee_id': employee['id'],
                                        'month_year':
                                            _payrollMonthController.text,
                                      });
                                    },
                                    child: const Text('Paie', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _deleteEmployee(employee['id'] as int),
                                    child: const Text(
                                      'Supprimer',
                                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPayrollTab() {
    final filtered = _salaryRecords
        .where(
          (row) =>
              _payrollMonthController.text.trim().isEmpty ||
              (row['month_year'] ?? '').toString().toLowerCase() ==
                  _payrollMonthController.text.trim().toLowerCase(),
        )
        .toList();

    return Column(
      children: [
        if (_isSessionFrozen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildFreezeWarningBanner(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              TextField(
                controller: _payrollMonthController,
                onChanged: (_) => setState(() {}),
                decoration: _decoration('Filtrer par mois (ex: Août 2026)'),
              ),
              const SizedBox(height: 10),
              if (_canManageHr && !_isSessionFrozen)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _savePayrollRules,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Règles de paie'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState('Aucune fiche de paie enregistrée.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    final employee = record['employees'] as Map<String, dynamic>?;
                    final paid = _normalizeSalaryStatus(
                          (record['status'] ?? '').toString(),
                        ) ==
                        'Paid';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEBF0F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (employee?['nom'] ?? 'Employé').toString(),
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    Text(
                                      (record['month_year'] ?? '-').toString(),
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              _statusPill(paid ? 'Payé' : 'En attente'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Net: ${_money(record['net_salary'])}',
                            style: AppTextStyles.heading3.copyWith(color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Retenue: ${_money(record['total_deduction'])} | Prime: ${_money(record['total_allowance'])}',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 10),
                          if (_canManageHr)
                            if (_isSessionFrozen)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_rounded, size: 14, color: Color(0xFF94A3B8)),
                                    SizedBox(width: 4),
                                    Text('Fiche de paie verrouillée (Session clôturée)',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _openPayrollForm(record),
                                    child: const Text('Modifier'),
                                  ),
                                  if (!paid)
                                    TextButton(
                                      onPressed: () async {
                                        final result = await _repository
                                            .markSalaryAsPaid(
                                              record['id'] as int,
                                            );
                                        if (!mounted) return;
                                        _showMessage(
                                          result['success'] == true
                                              ? '✅ Salaire marqué comme payé.'
                                              : (result['error']?.toString() ??
                                                  'Erreur paiement'),
                                        );
                                        if (result['success'] == true) {
                                          await _load();
                                        }
                                      },
                                      child: const Text('Marquer payé', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final totalEmployees = _employees.length;
    final active = _employees
        .where(
          (employee) => (employee['statut'] ?? '')
              .toString()
              .toLowerCase()
              .contains('actif'),
        )
        .length;
    final inactive = totalEmployees - active;
    final paidCount = _salaryRecords
        .where(
          (row) =>
              _normalizeSalaryStatus((row['status'] ?? '').toString()) ==
              'Paid',
        )
        .length;
    final unpaidCount = _salaryRecords.length - paidCount;
    final departments = <String, int>{};

    for (final employee in _employees) {
      final dept = (employee['departement'] ?? 'Non défini').toString();
      departments[dept] = (departments[dept] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionCard(
          title: 'Répartition du personnel',
          child: Column(
            children: [
              _reportLine('Total employés', '$totalEmployees'),
              _reportLine('Actifs', '$active'),
              _reportLine('Inactifs', '$inactive'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'État de la paie',
          child: Column(
            children: [
              _reportLine('Fiches payées', '$paidCount'),
              _reportLine('Fiches impayées', '$unpaidCount'),
              _reportLine('Montant versé', _money(_stats['paidAmount'])),
              _reportLine('Montant restant', _money(_stats['unpaidAmount'])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Rapports de présence',
          child: Column(
            children: [
              _reportLine('Pointages du jour', '${_attendance.length}'),
              _reportLine(
                'Présents aujourd\'hui',
                '${_stats['presentToday'] ?? 0}',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/attendance/teacher-reports'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ouvrir le rapport enseignant'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Répartition par département',
          child: Column(
            children: departments.entries
                .map((entry) => _reportLine(entry.key, '${entry.value}'))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _summaryCard(List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: AppTextStyles.body),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, [Color? iconColor]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.slate500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.heading3.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text) {
    final lower = text.toLowerCase();
    final positive = lower.contains('actif') ||
        lower.contains('paid') ||
        lower.contains('payé') ||
        lower.contains('present') ||
        lower.contains('présent');
    final waiting = lower.contains('unpaid') || lower.contains('retard') || lower.contains('attente');
    final color = positive
        ? const Color(0xFF059669)
        : waiting
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    final bg = positive
        ? const Color(0xFFECFDF5)
        : waiting
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFFEF2F2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }

  Widget _reportLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }

  Widget _infoChip(dynamic value) {
    final text = value?.toString().trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Text(
        text == null || text.isEmpty ? '-' : text,
        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 48,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.heading3),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: _decoration(label),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final numVal = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
    final isInt = numVal % 1 == 0;
    final str = isInt ? numVal.toInt().toString() : numVal.toStringAsFixed(1);
    final parts = str.split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
  }

  String _money(dynamic value) {
    return '${_formatAmount(value)} FCFA';
  }
}
