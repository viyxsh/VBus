import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/enums/approval_status.dart';
import '../../core/enums/user_role.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/pending_approval_screen.dart';
import '../../features/auth/screens/passenger_registration_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/conductor/home/screens/conductor_home_screen.dart';
import '../../features/passenger/home/screens/passenger_home_screen.dart';

part 'router.g.dart';

// ─── Transition helpers ───────────────────────────────────────────────────────

// Fade — used for auth flow screens
CustomTransitionPage<void> _fadePage(
    GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      ),
    );

// Fade + scale up — used for the main home screens after login
CustomTransitionPage<void> _fadeScalePage(
    GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
            parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

// Slide from right + fade — used for detail / push screens (chat)
CustomTransitionPage<void> _slidePage(
    GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
            parent: animation, curve: Curves.easeOutCubic);
        final secondary = CurvedAnimation(
            parent: secondaryAnimation, curve: Curves.easeInCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.25, 0),
            ).animate(secondary),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

// ─── Router ───────────────────────────────────────────────────────────────────

@riverpod
GoRouter router(Ref ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) =>
            _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/role-select',
        pageBuilder: (_, state) =>
            _fadePage(state, const RoleSelectionScreen()),
      ),
      GoRoute(
        path: '/auth/passenger-register',
        pageBuilder: (_, state) =>
            _fadePage(state, const PassengerRegistrationScreen()),
      ),
      GoRoute(
        path: '/auth/pending-approval',
        pageBuilder: (_, state) =>
            _fadePage(state, const PendingApprovalScreen()),
      ),

      // Conductor
      GoRoute(
        path: '/conductor/home',
        pageBuilder: (_, state) =>
            _fadeScalePage(state, const ConductorHomeScreen()),
      ),

      // Passenger
      GoRoute(
        path: '/passenger/home',
        pageBuilder: (_, state) =>
            _fadeScalePage(state, const PassengerHomeScreen()),
      ),

      // Chat — slide in from the right like a detail screen
      GoRoute(
        path: '/chat/:roomId',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final String title;
          final bool isBroadcast;
          final String? phone;
          if (extra is Map<String, dynamic>) {
            title       = extra['title']       as String? ?? 'Chat';
            isBroadcast = extra['isBroadcast'] as bool?   ?? true;
            phone       = extra['phone']       as String?;
          } else {
            title       = extra as String?     ?? 'Chat';
            isBroadcast = true;
            phone       = null;
          }
          return _slidePage(
            state,
            ChatScreen(
              roomId: state.pathParameters['roomId']!,
              title: title,
              isBroadcast: isBroadcast,
              phone: phone,
            ),
          );
        },
      ),

      // Admin
      GoRoute(
        path: '/admin',
        pageBuilder: (_, state) =>
            _fadePage(state, const AdminDashboardScreen()),
      ),
    ],
  );
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final path = state.uri.path;

    return authAsync.when(
      loading: () => null,
      error: (_, __) => '/role-select',
      data: (AuthUser? user) => _getRedirect(user, path),
    );
  }

  String? _getRedirect(AuthUser? user, String path) {
    // Never interrupt the splash screen — it navigates itself after the animation
    if (path == '/splash') return null;

    if (user == null) {
      return path == '/role-select' ? null : '/role-select';
    }

    switch (user.role) {
      case UserRole.conductor:
        if (path.startsWith('/conductor') || path.startsWith('/chat')) return null;
        return '/conductor/home';

      case UserRole.admin:
        if (path.startsWith('/admin')) return null;
        return '/admin';

      case UserRole.passenger:
        if (user.approvalStatus == null) {
          return path == '/auth/passenger-register'
              ? null
              : '/auth/passenger-register';
        }
        if (user.approvalStatus == ApprovalStatus.pending ||
            user.approvalStatus == ApprovalStatus.rejected) {
          return path == '/auth/pending-approval'
              ? null
              : '/auth/pending-approval';
        }
        if (path.startsWith('/passenger') || path.startsWith('/chat')) return null;
        return '/passenger/home';
    }
  }
}
