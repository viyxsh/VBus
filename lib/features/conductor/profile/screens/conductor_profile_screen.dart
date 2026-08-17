import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../core/widgets/profile_rows.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../providers/conductor_profile_providers.dart';
import '../widgets/conductor_bus_controls_sheet.dart';
import '../widgets/conductor_bus_requests_sheet.dart';
import '../widgets/conductor_edit_profile_sheet.dart';
import '../widgets/conductor_manage_passengers_sheet.dart';
import '../widgets/conductor_seat_reservations_sheet.dart';

class ConductorProfileScreen extends ConsumerStatefulWidget {
  const ConductorProfileScreen({super.key});

  @override
  ConsumerState<ConductorProfileScreen> createState() =>
      _ConductorProfileScreenState();
}

class _ConductorProfileScreenState
    extends ConsumerState<ConductorProfileScreen> {
  static const _storage = FlutterSecureStorage();
  static const _notifKey = 'conductor_notifications';

  bool _notifEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotif();
  }

  Future<void> _loadNotif() async {
    final notif = await _storage.read(key: _notifKey);
    if (mounted) setState(() => _notifEnabled = notif == 'true');
  }

  Future<void> _toggleNotif(bool value) async {
    await _storage.write(key: _notifKey, value: value.toString());
    setState(() => _notifEnabled = value);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t(context, 'Log out')),
        content: Text(S.t(context, 'Are you sure you want to log out?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t(context, 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(S.t(context, 'Log out')),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  // ─── Sheets ──────────────────────────────────────────────────────────────────

  void _showEditProfile(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ConductorEditProfileSheet(profile: profile),
    );
  }

  void _showBusControls() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const ConductorBusControlsSheet(),
    );
  }

  void _showManagePassengers(String busId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ConductorManagePassengersSheet(busId: busId),
    );
  }

  void _showBusRequests(Map<String, dynamic> profile) {
    final busId = profile['bus_id'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ConductorBusRequestsSheet(profile: profile, busId: busId),
    );
  }

  void _showSeatReservations(Map<String, dynamic> profile) {
    final busId = profile['bus_id'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          ConductorSeatReservationsSheet(profile: profile, busId: busId),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0E18) : const Color(0xFFF2F3F7);
    ref.watch(themeProvider); // rebuild on theme change
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isHindi = ref.watch(localeProvider).languageCode == 'hi';
    final profileAsync = ref.watch(conductorProfileProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(S.t(context, 'Settings'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: LottieLoading()),
        error: (e, _) => Center(
            child: FilledButton(
                onPressed: () => ref.invalidate(conductorProfileProvider),
                child: Text(S.t(context, 'Retry')))),
        data: (profile) {
          final bus = profile['buses'] as Map;
          final name = profile['display_name'] as String? ??
              profile['username'] as String? ??
              '';
          final busNum = bus['bus_number'] as String? ?? '?';
          final initial =
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Profile card ──────────────────────────────────────────────────
              profileCard([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(initial,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                name.isEmpty
                                    ? S.t(context, 'Conductor')
                                    : name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                                '${S.t(context, 'Conductor')} · ${S.t(context, 'Bus')} $busNum',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: theme
                                        .colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showEditProfile(profile),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset('assets/icons/pencil.svg',
                                      width: 13,
                                      height: 13,
                                      colorFilter: ColorFilter.mode(
                                          theme.colorScheme.primary,
                                          BlendMode.srcIn)),
                                  const SizedBox(width: 4),
                                  Text(S.t(context, 'Edit Profile'),
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ], theme),

              // ── Bus Management ────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'Bus Management'), theme),
              profileCard([
                profileRow('assets/icons/bus.svg',
                    S.t(context, 'Bus Controls'),
                    subtitle: S.t(context, 'Faculty rows, seat layout'),
                    onTap: _showBusControls,
                    theme: theme),
                profileDivider(theme),
                profileRow('assets/icons/passengers.svg',
                    S.t(context, 'Manage Passengers'),
                    subtitle: S.t(context, 'Remove passengers from bus'),
                    onTap: () =>
                        _showManagePassengers(profile['bus_id'] as String),
                    theme: theme),
                profileDivider(theme),
                Consumer(builder: (context, ref, _) {
                  final busId = profile['bus_id'] as String;
                  final requestsAsync = ref.watch(busRequestsProvider(busId));
                  final count = requestsAsync.valueOrNull?.length ?? 0;
                  return profileRow('assets/icons/passengers.svg',
                      S.t(context, 'View Requests'),
                      subtitle:
                          S.t(context, 'Pending bus join requests'),
                      badge: count > 0 ? count.toString() : null,
                      onTap: () => _showBusRequests(profile),
                      theme: theme);
                }),
                profileDivider(theme),
                Consumer(builder: (context, ref, _) {
                  final busId = profile['bus_id'] as String;
                  final res =
                      ref.watch(pendingSeatReservationsProvider(busId));
                  final count = res.valueOrNull?.length ?? 0;
                  return profileRow('assets/icons/passengers.svg',
                      S.t(context, 'Seat Reservations'),
                      subtitle:
                          S.t(context, 'Permanent seat requests from faculty'),
                      badge: count > 0 ? count.toString() : null,
                      onTap: () => _showSeatReservations(profile),
                      theme: theme);
                }),
              ], theme),

              // ── General ───────────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'General'), theme),
              profileCard([
                profileValueRow('assets/icons/brightness.svg',
                    S.t(context, 'Appearance'),
                    value: isDarkMode
                        ? S.t(context, 'Dark')
                        : S.t(context, 'Light'),
                    onTap: () => ref.read(themeProvider.notifier).setMode(
                          isDarkMode ? ThemeMode.light : ThemeMode.dark,
                        ),
                    theme: theme,
                  ),
                profileDivider(theme),
                profileValueRow('assets/icons/languages.svg',
                    S.t(context, 'Language'),
                    value: isHindi
                        ? S.t(context, 'Hindi')
                        : S.t(context, 'English'),
                    onTap: () => ref.read(localeProvider.notifier).setLocale(
                          isHindi ? const Locale('en') : const Locale('hi'),
                        ),
                    theme: theme,
                  ),
                profileDivider(theme),
                profileToggleRow('assets/icons/notification.svg',
                    S.t(context, 'Notifications'),
                    hint: S.t(
                        context, 'Trip start reminders and attendance alerts'),
                    value: _notifEnabled,
                    onChanged: _toggleNotif,
                    theme: theme),
              ], theme),

              // ── Support ───────────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'Support'), theme),
              profileCard([
                profileRow('assets/icons/sign-out-alt.svg',
                    S.t(context, 'Log Out'),
                    color: theme.colorScheme.error,
                    onTap: _signOut,
                    theme: theme),
              ], theme),
            ],
          );
        },
      ),
    );
  }
}
