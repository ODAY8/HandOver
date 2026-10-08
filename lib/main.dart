import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/handover_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/auth_repository.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization note: $e');
  }

  final authService = SupabaseAuthService();
  final authRepository = SupabaseAuthRepository(authService: authService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository: authRepository)),
        ChangeNotifierProvider(create: (_) => HandoverProvider()),
      ],
      child: const HandoverApp(),
    ),
  );
}
