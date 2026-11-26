import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('MediaKit native player initialization: $e');
  }
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 2000;
  runApp(
    const ProviderScope(
      child: FrameFlowApp(),
    ),
  );
}

class FrameFlowApp extends ConsumerWidget {
  const FrameFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studioTheme = ref.watch(themeProvider);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromStudioColors(studioTheme),
      home: const AuthGate(),
    );
  }
}
