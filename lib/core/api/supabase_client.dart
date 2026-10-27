import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hxweqrfgqlrzjcjjemme.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_wyxNZnhEVc0r-m1XZZrxNQ_OoV-H5vD',
  );
}

class SupabaseClientManager {
  static final SupabaseClientManager _instance = SupabaseClientManager._internal();
  factory SupabaseClientManager() => _instance;
  SupabaseClientManager._internal();

  late final SupabaseClient client;

  Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    client = Supabase.instance.client;
  }
}


