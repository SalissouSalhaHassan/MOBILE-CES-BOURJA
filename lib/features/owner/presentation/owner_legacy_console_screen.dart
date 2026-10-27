import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OwnerLegacyConsoleScreen extends StatelessWidget {
  const OwnerLegacyConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: const Color(0xFFF7F8FC),
        title: const Text('Console Admin'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            title: 'Console Admin (Legacy)',
            body:
                'Cette page sert de passerelle mobile vers les modules historiques du tableau de bord administrateur.',
          ),
          const SizedBox(height: 16),
          _linkTile(
            context,
            icon: Icons.dashboard_customize_rounded,
            title: 'Dashboard principal',
            subtitle: 'Retour au tableau de bord general',
            onTap: () => context.push('/dashboard'),
          ),
          _linkTile(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Finance',
            subtitle: 'Gestion financiere courante',
            onTap: () => context.push('/finance/dashboard'),
          ),
          _linkTile(
            context,
            icon: Icons.badge_outlined,
            title: 'Ressources Humaines',
            subtitle: 'Employes, paie et rapports',
            onTap: () => context.push('/hr'),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required String body}) {
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
          const SizedBox(height: 10),
          Text(body, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEEF2FF),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: AppTextStyles.bodyBold),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
