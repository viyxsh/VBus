import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/l10n/strings.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  late final AnimationController _controller;

  // 2.0 = play the full animation twice as fast
  static const double _speed = 2.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/role-select');
  }

  Widget _buildAnimation(ThemeData theme) {
    return Lottie.asset(
      'assets/animations/bus_animation_js.json',
      controller: _controller,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        // Divide duration by speed so the full animation completes faster
        _controller.duration = composition.duration * (1.0 / _speed);
        _controller.forward().whenComplete(_navigate);
      },
      errorBuilder: (_, __, ___) {
        Future.delayed(const Duration(milliseconds: 1500), _navigate);
        return Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/bus.svg',
                width: 52,
                height: 52,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Session verification failed (e.g. network error while fetching the
  /// profile). Offer a retry instead of silently bouncing to role selection.
  Widget _buildError(BuildContext context, ThemeData theme, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            S.t(context, 'Could not verify your session'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.t(context, 'Check your connection and try again.'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              _navigated = false;
              _controller.reset();
              ref.invalidate(authStateProvider);
            },
            icon: const Icon(Icons.refresh),
            label: Text(S.t(context, 'Retry')),
          ),
        ],
      ),
    );
  }

  Widget _splashBody(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 220, height: 220, child: _buildAnimation(theme)),
        const SizedBox(height: 16),
        Text(
          'VBUS',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.t(context, 'VIT Bhopal University Transport'),
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0E18) : Colors.white,
      body: Center(
        child: authAsync.when(
          loading: () => _splashBody(theme),
          error: (e, _) => _buildError(context, theme, e),
          data: (_) => _splashBody(theme),
        ),
      ),
    );
  }
}
