import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class UpgradeRequiredScreen extends ConsumerStatefulWidget {
  const UpgradeRequiredScreen({super.key});

  @override
  ConsumerState<UpgradeRequiredScreen> createState() => _UpgradeRequiredScreenState();
}

class _UpgradeRequiredScreenState extends ConsumerState<UpgradeRequiredScreen> {
  bool _isChecking = false;

  Future<void> _refreshStatus() async {
    setState(() => _isChecking = true);
    await ref.read(authProvider.notifier).refreshProfile();
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Brand Icon & Alert
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentOrange, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.accentOrange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Software Update & Upgrade Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your free beta access period has concluded for account: ${user?.email ?? ""}.\nTo continue using FrameFlow Studio and export videos, please choose a plan or update your license.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Pricing Chart (3 Columns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tier 1: Free Starter
                    Expanded(
                      child: _buildPricingCard(
                        title: 'Starter',
                        price: '\$0',
                        period: 'forever',
                        badge: 'LIMITED',
                        badgeColor: Colors.grey,
                        features: const [
                          '720p Export Resolution',
                          'Standard Watermark',
                          'Up to 2 Timeline Tracks',
                          'Basic Animations',
                        ],
                        buttonText: 'Downgrade to Starter',
                        isHighlighted: false,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Tier 2: Pro Creator (Highlighted)
                    Expanded(
                      child: _buildPricingCard(
                        title: 'Pro Creator',
                        price: '\$19',
                        period: '/ month',
                        badge: 'MOST POPULAR',
                        badgeColor: AppColors.accentOrange,
                        features: const [
                          '1080p & 4K UHD 60 FPS Export',
                          'No Watermarks',
                          'Unlimited Timeline Tracks',
                          'Advanced Audio Trimming & Split',
                          'All Pan, Zoom & Fade Presets',
                          'Hardware GPU Acceleration',
                          'Priority Support',
                        ],
                        buttonText: 'Upgrade to Pro',
                        isHighlighted: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Tier 3: Lifetime Studio
                    Expanded(
                      child: _buildPricingCard(
                        title: 'Lifetime Studio',
                        price: '\$299',
                        period: 'one-time',
                        badge: 'BEST VALUE',
                        badgeColor: const Color(0xFF7C3AED),
                        features: const [
                          'Everything in Pro Creator',
                          'Pay once, keep forever',
                          'All future major version updates',
                          'Commercial Studio License',
                          'Early Access to new features',
                        ],
                        buttonText: 'Get Lifetime License',
                        isHighlighted: false,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action Bar (Refresh Check & Sign Out)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: _isChecking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: const Text('Check Status Again', style: TextStyle(fontSize: 12)),
                      onPressed: _isChecking ? null : _refreshStatus,
                    ),
                    const SizedBox(width: 14),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                      ),
                      icon: const Icon(Icons.logout, size: 14),
                      label: const Text('Sign Out', style: TextStyle(fontSize: 12)),
                      onPressed: () => ref.read(authProvider.notifier).signOut(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required String badge,
    required Color badgeColor,
    required List<String> features,
    required String buttonText,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.surfaceLight
            : AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? AppColors.accentOrange : AppColors.surfaceBorder,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.accentOrange.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor, width: 0.8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: isHighlighted ? AppColors.accentOrange : Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isHighlighted ? AppColors.accentOrange : AppColors.surfaceBorder,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: onTap,
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
