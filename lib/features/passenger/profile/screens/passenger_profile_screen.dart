import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/passenger_repository.dart';
import '../providers/passenger_profile_providers.dart';

class PassengerProfileScreen extends ConsumerStatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  ConsumerState<PassengerProfileScreen> createState() =>
      _PassengerProfileScreenState();
}

class _PassengerProfileScreenState
    extends ConsumerState<PassengerProfileScreen> {
  static const _storage = FlutterSecureStorage();
  static const _notifKey          = 'seat_booking_reminder';
  static const _pinNotifKey       = 'custom_pin_notifications';
  static const _busArrivalNotifKey = 'bus_arrival_notification';

  bool _notifEnabled         = false;
  bool _pinNotifEnabled      = false;
  bool _busArrivalNotifEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotifSettings();
  }

  Future<void> _loadNotifSettings() async {
    final notif      = await _storage.read(key: _notifKey);
    final pinNotif   = await _storage.read(key: _pinNotifKey);
    final busArrival = await _storage.read(key: _busArrivalNotifKey);
    if (mounted) {
      setState(() {
        _notifEnabled           = notif       == 'true';
        _pinNotifEnabled        = pinNotif    == 'true';
        _busArrivalNotifEnabled = busArrival  == 'true';
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CustomPinsSheet(busId: busId),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  void _showEditProfile(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }

  void _showBookingHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _BookingHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0E18) : const Color(0xFFF2F3F7);
    ref.watch(themeProvider); // rebuild on theme change
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isHindi    = ref.watch(localeProvider).languageCode == 'hi';
    final profileAsync = ref.watch(passengerProfileProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(S.t(context, 'Settings'), style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: LottieLoading()),
        error: (e, _) => Center(
            child: FilledButton(
                onPressed: () => ref.invalidate(passengerProfileProvider),
                child: const Text('Retry'))),
        data: (profile) {
          final name      = profile['name']  as String? ?? '';
          final email     = profile['email'] as String? ?? '';
          final busId     = profile['bus_id'] as String;
          final avatarUrl = ref.read(passengerRepositoryProvider).currentAvatarUrl;
          final initials  = name.trim().isNotEmpty
              ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
              : '?';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Profile card ──────────────────────────────────────────────────
              _card([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(initials, style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary)) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(email, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showEditProfile(profile),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset('assets/icons/pencil.svg',
                                      width: 13, height: 13,
                                      colorFilter: ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn)),
                                  const SizedBox(width: 4),
                                  Text(S.t(context, 'Edit Profile'), style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
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
              _sectionLabel(S.t(context, 'Account'), theme),
              _card([
                _row('assets/icons/history.svg', S.t(context, 'Seat Booking History'),
                    onTap: _showBookingHistory, theme: theme),
                _divider(theme),
                _row('assets/icons/gps.svg', S.t(context, 'Custom Stop Pins'),
                    subtitle: S.t(context, 'Manage your saved pins'),
                    onTap: () => _showCustomPins(busId), theme: theme),
              ], theme),

              // ── Notifications ─────────────────────────────────────────────────
              _sectionLabel(S.t(context, 'Notifications'), theme),
              _card([
                _toggleRow('assets/icons/notification.svg', S.t(context, 'Seat Booking Reminder'),
                    hint: S.t(context, 'Remind me before the 8 PM booking window opens'),
                    value: _notifEnabled, onChanged: _toggleNotif, theme: theme),
                _divider(theme),
                _toggleRow('assets/icons/gps.svg', S.t(context, 'Custom Pin Alerts'),
                    hint: S.t(context, 'Alert me when the bus nears my saved map pins'),
                    value: _pinNotifEnabled, onChanged: _togglePinNotif, theme: theme),
                _divider(theme),
                _toggleRow('assets/icons/gps.svg', 'Bus Arrival Alert',
                    hint: 'Notify me when the bus arrives at my stop',
                    value: _busArrivalNotifEnabled,
                    onChanged: _toggleBusArrivalNotif,
                    theme: theme),
              ], theme),

              // ── General ───────────────────────────────────────────────────────
              _sectionLabel(S.t(context, 'General'), theme),
              _card([
                _valueRow(
                  'assets/icons/brightness.svg',
                  S.t(context, 'Appearance'),
                  value: isDarkMode ? S.t(context, 'Dark') : S.t(context, 'Light'),
                  onTap: () => ref.read(themeProvider.notifier).setMode(
                    isDarkMode ? ThemeMode.light : ThemeMode.dark,
                  ),
                  theme: theme,
                ),
                _divider(theme),
                _valueRow(
                  'assets/icons/languages.svg',
                  S.t(context, 'Language'),
                  value: isHindi ? S.t(context, 'Hindi') : S.t(context, 'English'),
                  onTap: () => ref.read(localeProvider.notifier).setLocale(
                        isHindi ? const Locale('en') : const Locale('hi'),
                      ),
                  theme: theme,
                ),
              ], theme),

              // ── Support ───────────────────────────────────────────────────────
              _sectionLabel(S.t(context, 'Support'), theme),
              _card([
                _row('assets/icons/sign-out-alt.svg', S.t(context, 'Log Out'),
                    color: theme.colorScheme.error,
                    onTap: _signOut, theme: theme),
              ], theme),
            ],
          );
        },
      ),
    );
  }

  // ── Shared widget helpers ─────────────────────────────────────────────────────


  Widget _sectionLabel(String label, ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant)),
  );

  Widget _card(List<Widget> children, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(ThemeData theme) => Divider(
    height: 1, indent: 52,
    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
  );

  Widget _row(String svgPath, String label, {
    String? subtitle, VoidCallback? onTap, Color? color, required ThemeData theme,
  }) {
    final iconColor = color ?? theme.colorScheme.onSurfaceVariant;
    final labelColor = color ?? theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SvgPicture.asset(svgPath, width: 20, height: 20,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: labelColor)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ])),
          if (onTap != null)
            SvgPicture.asset('assets/icons/angle-small-right.svg', width: 18, height: 18,
                colorFilter: ColorFilter.mode(theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
        ]),
      ),
    );
  }

  Widget _toggleRow(String svgPath, String label, {
    String? hint,
    required bool value, required ValueChanged<bool> onChanged, required ThemeData theme,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      SvgPicture.asset(svgPath, width: 20, height: 20,
          colorFilter: ColorFilter.mode(theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ])),
      Switch(value: value, onChanged: onChanged),
    ]),
  );

  Widget _valueRow(String svgPath, String label, {
    required String value, VoidCallback? onTap, required ThemeData theme,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        SvgPicture.asset(svgPath, width: 20, height: 20,
            colorFilter: ColorFilter.mode(theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 4),
        SvgPicture.asset('assets/icons/angle-small-right.svg', width: 18, height: 18,
            colorFilter: ColorFilter.mode(theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
      ]),
    ),
  );
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;

  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _selectedStopId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController(text: widget.profile['name']  as String? ?? '');
    _phoneCtrl       = TextEditingController(text: widget.profile['phone'] as String? ?? '');
    _selectedStopId  = widget.profile['stop_id'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(passengerRepositoryProvider).updateProfile(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            stopId: _selectedStopId,
          );
      ref.invalidate(passengerProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[PROFILE] save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busId = widget.profile['bus_id'] as String;
    final stopsAsync = ref.watch(passengerStopsProvider(busId));

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Edit Profile',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          stopsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (stops) => DropdownButtonFormField<String>(
              value: _selectedStopId,
              decoration: InputDecoration(
                labelText: 'My Boarding Stop',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              isExpanded: true,
              items: stops.map((s) => DropdownMenuItem<String>(
                value: s['id'] as String,
                child: Text(s['name'] as String,
                    overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selectedStopId = v),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Booking History Sheet ────────────────────────────────────────────────────

class _BookingHistorySheet extends ConsumerWidget {
  const _BookingHistorySheet();

  String _seatLabel(int seatNum, int leftSeats, int studentSeats) {
    if (seatNum <= leftSeats) return 'L$seatNum';
    final backCount  = studentSeats >= 6 ? 6 : studentSeats;
    final rightCount = studentSeats - backCount;
    final rightIdx   = seatNum - leftSeats;
    if (rightIdx <= rightCount) return 'R$rightIdx';
    return 'B${rightIdx - rightCount}';
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(seatBookingHistoryProvider);
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String fmt(DateTime d) => '${wd[d.weekday-1]}, ${d.day} ${mo[d.month-1]}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Seat Booking History',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                  child: Text('Failed to load history',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 48,
                            color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No bookings in the last 7 days',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final b = rows[i];
                    final seatNum = b['seat_number'] as int;
                    final date = DateTime.parse(b['booking_date'] as String);
                    final bus = b['buses'] as Map;
                    final leftSeats = (bus['left_seats'] as num).toInt();
                    final studentSeats = (bus['student_seats'] as num).toInt();
                    final label = _seatLabel(seatNum, leftSeats, studentSeats);
                    final isToday = _isToday(date);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primaryContainer,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        isToday ? 'Today' : fmt(date),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Seat $label',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Pins Sheet ────────────────────────────────────────────────────────

class _CustomPinsSheet extends ConsumerWidget {
  final String busId;
  const _CustomPinsSheet({required this.busId});

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Pin'),
        content: Text('Remove "$label"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(passengerRepositoryProvider).deleteCustomPin(id);
    ref.invalidate(customPinsProvider(busId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinsAsync = ref.watch(customPinsProvider(busId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Custom Stop Pins',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: pinsAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                  child: Text('Failed to load pins',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
              data: (pins) {
                if (pins.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off_outlined,
                            size: 48,
                            color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No custom pins yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Text('Long-press on the map to add a pin',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outlineVariant)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: pins.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final pin = pins[i];
                    final label = pin['label'] as String;
                    final mins  = pin['notify_minutes_before'] as int;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE65100)
                            .withValues(alpha: 0.1),
                        child: const Icon(Icons.location_on_rounded,
                            color: Color(0xFFE65100), size: 20),
                      ),
                      title: Text(label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Notify $mins min before arrival',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error, size: 20),
                        onPressed: () =>
                            _delete(context, ref, pin['id'] as String, label),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
