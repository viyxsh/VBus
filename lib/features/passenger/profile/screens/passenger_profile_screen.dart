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
import '../../../../data/repositories/passenger_repository.dart';
import '../../seat_booking/widgets/booking_history_sheet.dart';
import '../../../auth/providers/auth_provider.dart';
import '../providers/passenger_profile_providers.dart';
import '../widgets/passenger_custom_pins_sheet.dart';
import '../widgets/passenger_edit_profile_sheet.dart';

class PassengerProfileScreen extends ConsumerStatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  ConsumerState<PassengerProfileScreen> createState() =>
      _PassengerProfileScreenState();
}

class _PassengerProfileScreenState
    extends ConsumerState<PassengerProfileScreen> {
  static const _storage = FlutterSecureStorage();
  static const _notifKey = 'seat_booking_reminder';
  static const _pinNotifKey = 'custom_pin_notifications';
  static const _busArrivalNotifKey = 'bus_arrival_notification';

  bool _notifEnabled = false;
  bool _pinNotifEnabled = false;
  bool _busArrivalNotifEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotifSettings();
  }

  Future<void> _loadNotifSettings() async {
    final notif = await _storage.read(key: _notifKey);
    final pinNotif = await _storage.read(key: _pinNotifKey);
    final busArrival = await _storage.read(key: _busArrivalNotifKey);
    if (mounted) {
      setState(() {
        _notifEnabled = notif == 'true';
        _pinNotifEnabled = pinNotif == 'true';
        _busArrivalNotifEnabled = busArrival == 'true';
      });
    }
  }

  Future<void> _toggleNotif(bool value) async {
    await _storage.write(key: _notifKey, value: value.toString());
    setState(() => _notifEnabled = value);
  }

  Future<void> _togglePinNotif(bool value) async {
    await _storage.write(key: _pinNotifKey, value: value.toString());
    setState(() => _pinNotifEnabled = value);
  }

  Future<void> _toggleBusArrivalNotif(bool value) async {
    await _storage.write(key: _busArrivalNotifKey, value: value.toString());
    setState(() => _busArrivalNotifEnabled = value);
  }

  void _showCustomPins(String busId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PassengerCustomPinsSheet(busId: busId),
    );
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
            child: Text(S.t(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(S.t(context, 'Log out')),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  Future<void> _leaveBus(Map<String, dynamic> profile) async {
    final bus = profile['buses']?['bus_number'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t(context, 'Leave Bus')),
        content: Text(
          S.t(
            context,
            'Are you sure you want to leave Bus $bus? You can request a different bus later.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.t(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(S.t(context, 'Leave Bus')),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(passengerRepositoryProvider).leaveBus();
        ref.invalidate(passengerProfileProvider);
        ref.invalidate(authStateProvider);
      } catch (e) {
        debugPrint('[LEAVE_BUS] error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                S.t(context, 'Failed to leave bus. Please try again.'),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showEditProfile(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PassengerEditProfileSheet(profile: profile),
    );
  }

  void _showBookingHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BookingHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0E18) : const Color(0xFFF2F3F7);
    ref.watch(themeProvider); // rebuild on theme change
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isHindi = ref.watch(localeProvider).languageCode == 'hi';
    final profileAsync = ref.watch(passengerProfileProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          S.t(context, 'Settings'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: LottieLoading()),
        error: (e, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(passengerProfileProvider),
            child: Text(S.t(context, 'Retry')),
          ),
        ),
        data: (profile) {
          final name = profile['name'] as String? ?? '';
          final email = profile['email'] as String? ?? '';
          final busId = profile['bus_id'] as String?;
          final avatarUrl = ref
              .read(passengerRepositoryProvider)
              .currentAvatarUrl;
          final initials = name.trim().isNotEmpty
              ? name
                    .trim()
                    .split(' ')
                    .map((w) => w[0])
                    .take(2)
                    .join()
                    .toUpperCase()
              : '?';

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
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showEditProfile(profile),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/pencil.svg',
                                    width: 13,
                                    height: 13,
                                    colorFilter: ColorFilter.mode(
                                      theme.colorScheme.primary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    S.t(context, 'Edit Profile'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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

              // ── Account ───────────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'Account'), theme),
              profileCard([
                profileRow(
                  'assets/icons/history.svg',
                  S.t(context, 'Seat Booking History'),
                  onTap: _showBookingHistory,
                  theme: theme,
                ),
                profileDivider(theme),
                if (busId != null)
                  profileRow(
                    'assets/icons/gps.svg',
                    S.t(context, 'Custom Stop Pins'),
                    subtitle: S.t(context, 'Manage your saved pins'),
                    onTap: () => _showCustomPins(busId),
                    theme: theme,
                  ),
              ], theme),

              // ── Notifications ─────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'Notifications'), theme),
              profileCard([
                profileToggleRow(
                  'assets/icons/notification.svg',
                  S.t(context, 'Seat Booking Reminder'),
                  hint: S.t(
                    context,
                    'Remind me before the 8 PM booking window opens',
                  ),
                  value: _notifEnabled,
                  onChanged: _toggleNotif,
                  theme: theme,
                ),
                profileDivider(theme),
                profileToggleRow(
                  'assets/icons/gps.svg',
                  S.t(context, 'Custom Pin Alerts'),
                  hint: S.t(
                    context,
                    'Alert me when the bus nears my saved map pins',
                  ),
                  value: _pinNotifEnabled,
                  onChanged: _togglePinNotif,
                  theme: theme,
                ),
                profileDivider(theme),
                profileToggleRow(
                  'assets/icons/gps.svg',
                  S.t(context, 'Bus Arrival Alert'),
                  hint: S.t(
                    context,
                    'Notify me when the bus arrives at my stop',
                  ),
                  value: _busArrivalNotifEnabled,
                  onChanged: _toggleBusArrivalNotif,
                  theme: theme,
                ),
              ], theme),

              // ── General ───────────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'General'), theme),
              profileCard([
                profileValueRow(
                  'assets/icons/brightness.svg',
                  S.t(context, 'Appearance'),
                  value: isDarkMode
                      ? S.t(context, 'Dark')
                      : S.t(context, 'Light'),
                  onTap: () => ref
                      .read(themeProvider.notifier)
                      .setMode(isDarkMode ? ThemeMode.light : ThemeMode.dark),
                  theme: theme,
                ),
                profileDivider(theme),
                profileValueRow(
                  'assets/icons/languages.svg',
                  S.t(context, 'Language'),
                  value: isHindi
                      ? S.t(context, 'Hindi')
                      : S.t(context, 'English'),
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(
                        isHindi ? const Locale('en') : const Locale('hi'),
                      ),
                  theme: theme,
                ),
              ], theme),

              // ── Support ───────────────────────────────────────────────────────
              profileSectionLabel(S.t(context, 'Support'), theme),
              profileCard([
                if (busId != null) ...[
                  profileRow(
                    'assets/icons/bus.svg',
                    S.t(context, 'Leave Bus'),
                    subtitle: S.t(context, 'Remove yourself from this bus'),
                    onTap: () => _leaveBus(profile),
                    theme: theme,
                  ),
                  profileDivider(theme),
                ],
                profileRow(
                  'assets/icons/sign-out-alt.svg',
                  S.t(context, 'Log Out'),
                  color: theme.colorScheme.error,
                  onTap: _signOut,
                  theme: theme,
                ),
              ], theme),
            ],
          );
        },
      ),
    );
  }
}
