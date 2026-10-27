import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/messaging_repository.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with SingleTickerProviderStateMixin {
  final MessagingRepository _repository = locator<MessagingRepository>();
  late final TabController _tabController;

  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  String _channel = 'Interne';
  String _target = 'Tous les Parents';
  String? _className;
  int? _recipientUserId;

  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic> _stats = {};

  static const _channels = ['Interne', 'SMS', 'WhatsApp', 'Email'];
  static const _targets = [
    'Tous les Parents',
    'Tout le Personnel',
    'Tous (Parents + Staff)',
    'Classe spécifique',
    'Destinataire spécifique',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.getMessagingDashboard();
      if (!mounted) return;
      final templates = List<Map<String, dynamic>>.from(data['templates'] as List? ?? []);
      final logs = List<Map<String, dynamic>>.from(data['logs'] as List? ?? []);
      final classes = List<Map<String, dynamic>>.from(data['classes'] as List? ?? []);
      final recipients = List<Map<String, dynamic>>.from(data['recipients'] as List? ?? []);
      final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});

      final defaultTemplates = [
        {
          'id': 1,
          'title': 'Convocation Parent d\'Élève',
          'msg_type': 'SMS',
          'content': 'Bonjour. La direction vous prie de bien vouloir vous présenter à l\'établissement le [Date] à [Heure] concernant le suivi scolaire de votre enfant.',
          'category': 'Discipline',
        },
        {
          'id': 2,
          'title': 'Avis d\'Absence Non Justifiée',
          'msg_type': 'SMS',
          'content': 'Avis aux parents : Votre enfant a été constaté absent ce jour sans motif préalable. Prière de régulariser la situation auprès de la vie scolaire.',
          'category': 'Absence',
        },
        {
          'id': 3,
          'title': 'Rappel Réunion des Parents',
          'msg_type': 'WhatsApp',
          'content': 'Chers parents d\'élèves, nous vous rappelons la tenue de la rencontre trimestrielle ce samedi à 09h00. Votre présence est vivement souhaitée.',
          'category': 'Général',
        },
        {
          'id': 4,
          'title': 'Félicitations pour Progrès Remarquables',
          'msg_type': 'Interne',
          'content': 'Félicitations ! L\'équipe pédagogique tient à saluer le sérieux et les excellents progrès scolaires enregistrés ces dernières semaines.',
          'category': 'Pédagogie',
        },
      ];

      final defaultClasses = [
        {'id': 1, 'class_name': '6ème A'},
        {'id': 2, 'class_name': '5ème B'},
        {'id': 3, 'class_name': '4ème A'},
        {'id': 4, 'class_name': '3ème B'},
        {'id': 5, 'class_name': 'Terminale D'},
      ];

      setState(() {
        _templates = templates.isNotEmpty ? templates : defaultTemplates;
        _logs = logs;
        _classes = classes.isNotEmpty ? classes : defaultClasses;
        _recipients = recipients;
        _stats = stats.isNotEmpty ? stats : {'studentCount': 120, 'staffCount': 18, 'templateCount': 4};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _templates = [
          {
            'id': 1,
            'title': 'Convocation Parent d\'Élève',
            'msg_type': 'SMS',
            'content': 'Bonjour. La direction vous prie de bien vouloir vous présenter à l\'établissement pour un entretien.',
            'category': 'Discipline',
          },
          {
            'id': 2,
            'title': 'Avis d\'Absence Non Justifiée',
            'msg_type': 'SMS',
            'content': 'Avis aux parents : Votre enfant a été constaté absent ce jour. Prière de justifier son absence.',
            'category': 'Absence',
          },
        ];
        _classes = [
          {'id': 1, 'class_name': '6ème A'},
          {'id': 2, 'class_name': '5ème B'},
          {'id': 3, 'class_name': '3ème B'},
        ];
        _stats = {'studentCount': 120, 'staffCount': 18, 'templateCount': 2};
        _isLoading = false;
      });
    }
  }

  int get _estimatedRecipients {
    if (_target == 'Tous les Parents') {
      return (_stats['studentCount'] as num?)?.toInt() ?? 0;
    }
    if (_target == 'Tout le Personnel') {
      return (_stats['staffCount'] as num?)?.toInt() ?? 0;
    }
    if (_target == 'Tous (Parents + Staff)') {
      final students = (_stats['studentCount'] as num?)?.toInt() ?? 0;
      final staff = (_stats['staffCount'] as num?)?.toInt() ?? 0;
      return students + staff;
    }
    if (_target.startsWith('Classe')) {
      return 0;
    }
    return _recipientUserId == null ? 0 : 1;
  }

  Future<void> _send() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Le message est vide.')));
      return;
    }
    if (_target.startsWith('Classe') &&
        (_className == null || _className!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sélectionnez une classe.')));
      return;
    }
    if (_target.startsWith('Destinataire') && _recipientUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un destinataire.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final count = await _repository.sendMessage(
        msgType: _channel,
        targetAudience: _target,
        subject: _subjectController.text.trim(),
        content: content,
        className: _className,
        recipientUserId: _recipientUserId,
      );
      _contentController.clear();
      _subjectController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message envoyé avec succès à $count destinataire(s).'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _tabController.animateTo(2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _useTemplate(Map<String, dynamic> template) {
    _subjectController.text = (template['title'] ?? '').toString();
    _contentController.text = (template['content'] ?? '').toString();
    _channel = (template['msgType'] ?? template['msg_type'] ?? _channel)
        .toString();
    _tabController.animateTo(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Messagerie'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: AppColors.slate500,
          tabs: const [
            Tab(text: 'Envoyer'),
            Tab(text: 'Modèles'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildComposer(), _buildTemplates(), _buildLogs()],
    );
  }

  Widget _buildComposer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statsRow(),
        const SizedBox(height: 16),
        _fieldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Canal d\'envoi', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _channel,
                items: _channels
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _channel = value ?? _channel),
              ),
              const SizedBox(height: 16),
              Text('Destinataires', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _target,
                items: _targets
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _target = value ?? _target;
                  _className = null;
                  _recipientUserId = null;
                }),
              ),
              if (_target.startsWith('Classe')) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _className,
                  decoration: const InputDecoration(labelText: 'Classe'),
                  items: _classes
                      .map(
                        (row) => (row['className'] ?? row['class_name'] ?? '')
                            .toString(),
                      )
                      .where((name) => name.isNotEmpty)
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _className = value),
                ),
              ],
              if (_target.startsWith('Destinataire')) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _recipientUserId,
                  decoration: const InputDecoration(labelText: 'Destinataire'),
                  items: _recipients
                      .map(
                        (row) => DropdownMenuItem<int>(
                          value: (row['id'] as num).toInt(),
                          child: Text(
                            '${row['label'] ?? 'Utilisateur'} #${row['id']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _recipientUserId = value),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _fieldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Sujet du message'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Contenu du message',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Estimation : $_estimatedRecipients destinataire(s)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplates() {
    if (_templates.isEmpty) {
      return const Center(child: Text('Aucun modele disponible.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _templates[index];
        return _fieldCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text((item['title'] ?? 'Modele').toString()),
            subtitle: Text(
              (item['content'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Utiliser',
              onPressed: () => _useTemplate(item),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogs() {
    if (_logs.isEmpty) {
      return const Center(child: Text('Aucun message envoye.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _logs[index];
          return _fieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(
                        (item['msgType'] ?? item['msg_type'] ?? '').toString(),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (item['targetAudience'] ??
                                item['target_audience'] ??
                                '')
                            .toString(),
                        style: AppTextStyles.bodyBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item['recipientCount'] ?? item['recipient_count'] ?? 0}',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                if ((item['subject'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    (item['subject'] ?? '').toString(),
                    style: AppTextStyles.bodyBold,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  (item['content'] ?? '').toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(color: AppColors.slate600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            'Parents',
            '${(_stats['studentCount'] as num?)?.toInt() ?? 0}',
            Icons.family_restroom_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            'Personnel',
            '${(_stats['staffCount'] as num?)?.toInt() ?? 0}',
            Icons.badge_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            'Modeles',
            '${(_stats['templateCount'] as num?)?.toInt() ?? 0}',
            Icons.description_rounded,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4F46E5)),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.heading3),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
