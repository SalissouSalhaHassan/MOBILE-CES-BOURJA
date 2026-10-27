import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'teacher_cockpit_widget.dart';

class TeacherCockpitScreen extends StatelessWidget {
  const TeacherCockpitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QG de l\'Enseignant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Cockpit & Outils de Classe en Direct', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: TeacherCockpitWidget(),
      ),
    );
  }
}
