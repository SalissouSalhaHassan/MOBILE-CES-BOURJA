import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SmsInquiryHelperDialog extends StatefulWidget {
  final String matricule;
  final String studentName;

  const SmsInquiryHelperDialog({
    super.key,
    required this.matricule,
    required this.studentName,
  });

  static void show(BuildContext context, {required String matricule, required String studentName}) {
    showDialog(
      context: context,
      builder: (_) => SmsInquiryHelperDialog(matricule: matricule, studentName: studentName),
    );
  }

  @override
  State<SmsInquiryHelperDialog> createState() => _SmsInquiryHelperDialogState();
}

class _SmsInquiryHelperDialogState extends State<SmsInquiryHelperDialog> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();

  String _selectedCommand = "NOTE";
  bool _isTesting = false;
  String? _simulatedResponse;

  final Map<String, Map<String, String>> _commands = {
    "NOTE": {
      "title": "Notes & Moyennes",
      "desc": "Recevez la moyenne générale et le rang par SMS",
      "syntax": "NOTE",
      "icon": "📊",
    },
    "SOLDE": {
      "title": "Solde Scolarité",
      "desc": "Consultez le montant payé et l'échéance à régler",
      "syntax": "SOLDE",
      "icon": "💳",
    },
    "ABSENCE": {
      "title": "Assiduité & Absences",
      "desc": "Bilan des heures d'absence et retards du mois",
      "syntax": "ABSENCE",
      "icon": "⏱️",
    },
  };

  String get _generatedSmsBody => "$_selectedCommand ${widget.matricule}";

  Future<void> _sendViaDeviceSms() async {
    final uri = Uri.parse('sms:8080?body=${Uri.encodeComponent(_generatedSmsBody)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application SMS')),
        );
      }
    }
  }

  Future<void> _testSmsGateway() async {
    setState(() {
      _isTesting = true;
      _simulatedResponse = null;
    });

    try {
      final res = await _apiClient.postJson('/api/mobile/sms-gateway', {
        'messageContent': _generatedSmsBody,
        'senderPhone': '+22790123456',
      });

      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _simulatedResponse = res['data']['responseMessage'];
          _isTesting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
        _simulatedResponse = "Erreur: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.sms_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Passerelle SMS / Sans Internet",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Interrogez le serveur Edut sans connexion internet 4G/Wi-Fi via SMS standard :",
                style: TextStyle(fontSize: 12, color: AppColors.slate600),
              ),
              const SizedBox(height: 14),

              // Command choices
              ..._commands.entries.map((entry) {
                final key = entry.key;
                final info = entry.value;
                final isSelected = _selectedCommand == key;

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCommand = key;
                    _simulatedResponse = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Text(info['icon']!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(info['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(info['desc']!, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              // Message preview box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Numéro Court : 8080", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        Text("SMS Gratuit", style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _generatedSmsBody,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),

              if (_simulatedResponse != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.mark_chat_read_rounded, color: Color(0xFF16A34A), size: 14),
                          SizedBox(width: 6),
                          Text("Réponse SMS Reçue :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _simulatedResponse!,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF14532D), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTesting ? null : _testSmsGateway,
          child: _isTesting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Simuler Réponse"),
        ),
        ElevatedButton.icon(
          onPressed: _sendViaDeviceSms,
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
          label: const Text("Ouvrir SMS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
