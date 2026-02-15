import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/bus_repository.dart';
import '../providers/conductor_profile_providers.dart';

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
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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

  // ─── Sheets ──────────────────────────────────────────────────────────────────

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

  void _showBusControls(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BusControlsSheet(profile: profile),
    );
  }

  void _showManagePassengers(String busId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ManagePassengersSheet(busId: busId),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0D0E18) : const Color(0xFFF2F3F7);
    ref.watch(themeProvider); // rebuild on theme change
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isHindi    = ref.watch(localeProvider).languageCode == 'hi';
    final profileAsync = ref.watch(conductorProfileProvider);

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
                onPressed: () => ref.invalidate(conductorProfileProvider),
                child: const Text('Retry'))),
        data: (profile) {
          final bus     = profile['buses'] as Map;
          final name    = profile['display_name'] as String? ?? profile['username'] as String? ?? '';
          final busNum  = bus['bus_number'] as String? ?? '?';
          final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

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
                        child: Text(initial, style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? S.t(context, 'Conductor') : name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${S.t(context, 'Conductor')} · ${S.t(context, 'Bus')} $busNum',
                                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showEditProfile(profile),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset('assets/icons/pencil.svg', width: 13, height: 13,
                                      colorFilter: ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn)),
                                  const SizedBox(width: 4),
                                  Text(S.t(context, 'Edit Profile'), style: TextStyle(fontSize: 13,
                                      color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
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
              _sectionLabel(S.t(context, 'Bus Management'), theme),
              _card([
                _row('assets/icons/bus.svg', S.t(context, 'Bus Controls'),
                    subtitle: S.t(context, 'Faculty rows, seat layout'),
                    onTap: () => _showBusControls(profile), theme: theme),
                _divider(theme),
                _row('assets/icons/passengers.svg', S.t(context, 'Manage Passengers'),
                    subtitle: S.t(context, 'Add or remove passengers from bus'),
                    onTap: () => _showManagePassengers(profile['bus_id'] as String),
                    theme: theme),
              ], theme),

              // ── General ───────────────────────────────────────────────────────
              _sectionLabel(S.t(context, 'General'), theme),
              _card([
                _valueRow('assets/icons/brightness.svg', S.t(context, 'Appearance'),
                  value: isDarkMode ? S.t(context, 'Dark') : S.t(context, 'Light'),
                  onTap: () => ref.read(themeProvider.notifier).setMode(
                    isDarkMode ? ThemeMode.light : ThemeMode.dark,
                  ),
                  theme: theme,
                ),
                _divider(theme),
                _valueRow('assets/icons/languages.svg', S.t(context, 'Language'),
                  value: isHindi ? S.t(context, 'Hindi') : S.t(context, 'English'),
                  onTap: () => ref.read(localeProvider.notifier).setLocale(
                        isHindi ? const Locale('en') : const Locale('hi'),
                      ),
                  theme: theme,
                ),
                _divider(theme),
                _toggleRow('assets/icons/notification.svg', S.t(context, 'Notifications'),
                    hint: S.t(context, 'Trip start reminders and attendance alerts'),
                    value: _notifEnabled, onChanged: _toggleNotif, theme: theme),
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
    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant)),
  );

  Widget _card(List<Widget> children, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10, offset: const Offset(0, 2))],
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
    final iconColor  = color ?? theme.colorScheme.onSurfaceVariant;
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.profile['display_name'] as String? ?? '');
    _phoneCtrl = TextEditingController(
        text: widget.profile['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(busRepositoryProvider).updateConductorProfile(
            displayName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      ref.invalidate(conductorProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(context, 'Edit Profile'),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _inputDec('Display Name', Icons.person_outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: _inputDec('Phone Number', Icons.phone_outlined),
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

// ─── Bus Controls Sheet ───────────────────────────────────────────────────────

class _BusControlsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const _BusControlsSheet({required this.profile});

  @override
  ConsumerState<_BusControlsSheet> createState() => _BusControlsSheetState();
}

class _BusControlsSheetState extends ConsumerState<_BusControlsSheet> {
  late int _rowsLeft;
  late int _rowsRight;
  late int _totalLeftRows;
  late int _totalRightRows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final bus = widget.profile['buses'] as Map;
    final leftSeats = (bus['left_seats'] as num).toInt();
    final studentSeats = (bus['student_seats'] as num).toInt();
    final backCount = studentSeats >= 6 ? 6 : studentSeats;
    final rightCount = studentSeats - backCount;

    _totalLeftRows = (leftSeats / 2).ceil();
    _totalRightRows = (rightCount / 3).ceil();
    _rowsLeft = (bus['faculty_reserved_rows_left'] as num).toInt();
    _rowsRight = (bus['faculty_reserved_rows_right'] as num).toInt();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(busRepositoryProvider).updateFacultyRows(
            busId: widget.profile['bus_id'] as String,
            reservedRowsLeft: _rowsLeft,
            reservedRowsRight: _rowsRight,
          );
      ref.invalidate(conductorProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(context, 'Bus Controls'),
          const SizedBox(height: 8),
          Text(
            'Set how many rows from the top of each side are reserved for faculty (yellow seats).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _rowStepper(theme, 'Left side reserved rows',
              'Faculty rows on left column', _rowsLeft, _totalLeftRows,
              (v) => setState(() => _rowsLeft = v)),
          const SizedBox(height: 16),
          _rowStepper(theme, 'Right side reserved rows',
              'Faculty rows on right column', _rowsRight, _totalRightRows,
              (v) => setState(() => _rowsRight = v)),
          const SizedBox(height: 28),
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
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _rowStepper(ThemeData theme, String label, String sub,
      int value, int max, ValueChanged<int> onChange) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(sub,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChange(value - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChange(value + 1) : null,
        ),
      ],
    );
  }
}

// ─── Manage Passengers Sheet ──────────────────────────────────────────────────

class _ManagePassengersSheet extends ConsumerStatefulWidget {
  final String busId;
  const _ManagePassengersSheet({required this.busId});

  @override
  ConsumerState<_ManagePassengersSheet> createState() =>
      _ManagePassengersSheetState();
}

class _ManagePassengersSheetState
    extends ConsumerState<_ManagePassengersSheet> {
  String _search = '';

  Future<void> _removePassenger(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Passenger'),
        content: Text('Remove $name from this bus?'),
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

    try {
      // Removing means marking the passenger rejected.
      await ref.read(busRepositoryProvider).rejectPassenger(id);
      ref.invalidate(busPassengersProvider(widget.busId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passengersAsync = ref.watch(busPassengersProvider(widget.busId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHeader(context, 'Manage Passengers'),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: _inputDec('Search by name or ID',
                      Icons.search, borderRadius: 12),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: passengersAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                  child: Text('Failed to load',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
              data: (passengers) {
                final filtered = _search.isEmpty
                    ? passengers
                    : passengers
                        .where((p) =>
                            (p['name'] as String)
                                .toLowerCase()
                                .contains(_search.toLowerCase()) ||
                            (p['institute_id'] as String)
                                .toLowerCase()
                                .contains(_search.toLowerCase()))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                      child: Text('No passengers',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)));
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final name = p['name'] as String;
                    final regNum = p['institute_id'] as String;
                    final type = p['user_type'] as String;
                    final status = p['approval_status'] as String;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primaryContainer,
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '$regNum · ${type == 'faculty' ? 'Faculty' : 'Student'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status != 'approved')
                            _statusBadge(status, theme),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.person_remove_outlined,
                                color: theme.colorScheme.error,
                                size: 20),
                            onPressed: () =>
                                _removePassenger(p['id'] as String, name),
                          ),
                        ],
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

  Widget _statusBadge(String status, ThemeData theme) {
    final color = status == 'pending'
        ? Colors.amber.shade700
        : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _sheetHeader(BuildContext context, String title) {
  return Row(
    children: [
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const Spacer(),
      IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context)),
    ],
  );
}

InputDecoration _inputDec(String label, IconData icon,
    {double borderRadius = 12}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
  );
}
