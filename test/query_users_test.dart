// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Query all users and roles', () async {
    const url = 'https://gkarotahjtyvmhjqejts.supabase.co';
    const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdrYXJvdGFoanR5dm1oanFlanRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MDQyMTYsImV4cCI6MjA5MDE4MDIxNn0.wtLB6lMFV3nWx-KUMVNoLszSjGfA7-Kttmzvw_xZy9Q';

    print("Initializing SupabaseClient...");
    final client = SupabaseClient(url, anonKey);
    
    try {
      print("Querying users table...");
      final users = await client.from('users').select('id, utilisateur, admin, super_admin, role_id, roles(role_name)');
      print("USERS IN DB:");
      for (var user in users) {
        print(user);
      }

      print("\nQuerying roles table...");
      final roles = await client.from('roles').select('id, role_name');
      print("ROLES IN DB:");
      for (var role in roles) {
        print(role);
      }
    } catch (e) {
      print("Error: $e");
    }
  });
}
