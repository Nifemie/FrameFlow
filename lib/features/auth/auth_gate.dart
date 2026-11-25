import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../shell/main_layout_screen.dart';
import 'auth_screen.dart';
import 'upgrade_required_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // 1. Initial Session Loading
    if (authState.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0F14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/app_logo.jpg',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.movie_creation_outlined,
                    color: AppColors.accentOrange,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentOrange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Not Logged In -> Show Auth Screen
    if (!authState.isAuthenticated) {
      return const AuthScreen();
    }

    // 3. Logged In but Not Paid -> Show Upgrade / Pricing Screen
    if (!authState.isPaid) {
      return const UpgradeRequiredScreen();
    }

    // 4. Logged In & Paid -> Full FrameFlow Studio
    return const MainLayoutScreen();
  }
}
