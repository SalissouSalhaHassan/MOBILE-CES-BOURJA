import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/owner_repository.dart';

class OwnerAuditScreen extends StatefulWidget {
  const OwnerAuditScreen({super.key});

  @override
  State<OwnerAuditScreen> createState() => _OwnerAuditScreenState();
}

class _OwnerAuditScreenState extends State<OwnerAuditScreen> {
  final OwnerRepository _repository = locator<OwnerRepository>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _repository.getAuditLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('Audit Global'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: _logs.isEmpty
                    ? [_empty()]
                    : _logs.map(_logCard).toList(),
              ),
            ),
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final action = (log['action'] ?? '-').toString();
    final table = (log['table_name'] ?? '-').toString();
    final time = (log['timestamp'] ?? '').toString().split('.').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(action, style: AppTextStyles.bodyBold)),
              _pill(action),
            ],
          ),
          const SizedBox(height: 8),
          Text('Table: $table', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text('Record: ${log['record_id'] ?? '-'}', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text('Date: $time', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    final lower = text.toLowerCase();
    final color = lower.contains('delete')
        ? const Color(0xFFDC2626)
        : lower.contains('update')
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);
    final bg = lower.contains('delete')
        ? const Color(0xFFFEF2F2)
        : lower.contains('update')
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFECFDF5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Center(
        child: Text('Aucun log global disponible.', style: AppTextStyles.body),
      ),
    );
  }
}
