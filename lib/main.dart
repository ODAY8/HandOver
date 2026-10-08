import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/handover_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/profile_repository.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';

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
  final profileService = SupabaseProfileService();
  final profileRepository = SupabaseProfileRepository(service: profileService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository: authRepository)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(profileRepository: profileRepository)),
        ChangeNotifierProvider(create: (_) => HandoverProvider()),
      ],
      child: const HandoverApp(),
    ),
  );
}
