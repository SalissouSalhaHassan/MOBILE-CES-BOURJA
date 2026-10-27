// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Debug login and profile query', () async {
    const url = 'https://gkarotahjtyvmhjqejts.supabase.co';
    const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdrYXJvdGFoanR5dm1oanFlanRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MDQyMTYsImV4cCI6MjA5MDE4MDIxNn0.wtLB6lMFV3nWx-KUMVNoLszSjGfA7-Kttmzvw_xZy9Q';

    print("Initializing SupabaseClient directly...");
    final client = SupabaseClient(url, anonKey);
    
    print("Signing in as salissousalha@gmail.com...");
    try {
      final response = await client.auth.signInWithPassword(
        email: 'salissousalha@gmail.com',
        password: '123456',
      );

      print("✅ Auth login success. User ID: ${response.user?.id}");
      
      // Try to fetch profile
      print("\n1. Fetching user profile...");
      try {
        final userData = await client
            .from('users')
            .select('id, admin, super_admin, school_id, role_id, roles(role_name)')
            .eq('supabase_id', response.user!.id)
            .maybeSingle();
        
        print("Profile raw result: $userData");
      } catch (e) {
        print("❌ Error fetching user profile with join: $e");
      }

      print("\n2. Fetching employee record...");
      try {
        final employeeData = await client
            .from('employees')
            .select('id, school_id, email, nom')
            .eq('email', 'salissousalha@gmail.com')
            .maybeSingle();
        print("Employee raw result: $employeeData");
      } catch (e) {
        print("❌ Error fetching employee: $e");
      }

      print("\n3. Fetching assignments...");
      try {
        final classSubjectsData = await client
            .from('class_subjects')
            .select('class_id, subject_id, school_classes(class_name), school_subjects(subject_name)')
            .eq('employee_id', 5);
        print("Assignments raw result: $classSubjectsData");
      } catch (e) {
        print("❌ Error fetching assignments: $e");
      }

      print("\n4. Fetching active sessions...");
      try {
        final sessionsData = await client
            .from('school_sessions')
            .select('id, session_name, is_active, status')
            .eq('school_id', 1);
        print("Sessions raw result: $sessionsData");
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }

      print("\n5. Fetching active academic periods...");
      try {
        final periodsData = await client
            .from('academic_periods')
            .select('id, name, period_type, is_active, session_id')
            .eq('school_id', 1)
            .eq('session_id', 3);
        print("Periods raw result: $periodsData");
      } catch (e) {
        print("❌ Error fetching periods: $e");
      }

      print("\n6. Fetching students in 6ème (school_id: 1)...");
      try {
        final studentsData = await client
            .from('students')
            .select('id, num_admission, nom_etudiant, photo_path')
            .eq('classe', '6ème')
            .eq('statut', 'Actif')
            .eq('school_id', 1);
        print("Students raw result: $studentsData");
      } catch (e) {
        print("❌ Error fetching students: $e");
      }

      print("\n7. Fetching student results for 6ème Arabe (class: 31, subject: 99)...");
      try {
        final resultsData = await client
            .from('student_results')
            .select('id, student_id, class_work_score, exam_score, total_score')
            .eq('class_id', 31)
            .eq('subject_id', 99)
            .eq('session_id', 3);
        print("Results raw result: $resultsData");
      } catch (e) {
        print("❌ Error fetching student_results: $e");
      }

    } catch (e) {
      print("❌ Auth sign in failed: $e");
    }
  });
}
