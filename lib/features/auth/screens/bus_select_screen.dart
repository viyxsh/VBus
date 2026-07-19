import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/widgets/lottie_widgets.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/bus_request_repository.dart';
import '../../../data/repositories/registration_repository.dart';
import '../../../main.dart';

class BusSelectScreen extends ConsumerStatefulWidget {
  const BusSelectScreen({super.key});

  @override
  ConsumerState<BusSelectScreen> createState() => _BusSelectScreenState();
}

class _BusSelectScreenState extends ConsumerState<BusSelectScreen> {
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _stops = [];

  Map<String, dynamic>? _selectedCity;
  Map<String, dynamic>? _selectedBus;
  Map<String, dynamic>? _selectedStop;

  bool _loadingCities = true;
  bool _loadingBuses = false;
  bool _loadingStops = false;
  bool _submitting = false;
  bool _initialLoading = true;
  bool _requestSent = false;
  String? _pendingBusNumber;
  bool _editing = false;
  RealtimeChannel? _approvalChannel;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  @override
  void dispose() {
    _approvalChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkExistingRequest() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final pending =
          await ref.read(busRequestRepositoryProvider).myPendingRequest(userId);
      if (mounted) {
        setState(() {
          _requestSent = pending != null;
          _pendingBusNumber =
              pending?['buses']?['bus_number'] as String?;
          _initialLoading = false;
        });
      }
      if (pending != null) {
        _subscribeToApproval();
      } else {
        _loadCities();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _initialLoading = false);
        _loadCities();
      }
    }
  }

  Future<void> _loadCities() async {
    try {
      final data = await ref.read(registrationRepositoryProvider).cities();
      if (mounted) setState(() { _cities = data; _loadingCities = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadBuses(String cityId) async {
    setState(() { _loadingBuses = true; _buses = []; _stops = []; _selectedBus = null; _selectedStop = null; });
    try {
      final data = await ref.read(registrationRepositoryProvider).busesForCity(cityId);
      if (mounted) setState(() { _buses = data; _loadingBuses = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBuses = false);
    }
  }

  Future<void> _loadStops(String routeId) async {
    setState(() { _loadingStops = true; _stops = []; _selectedStop = null; });
    try {
      final data = await ref.read(registrationRepositoryProvider).stopsForRoute(routeId);
      if (mounted) setState(() { _stops = data; _loadingStops = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStops = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedBus == null || _selectedStop == null) {
      _showError('Please select a bus and stop.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final busId = _selectedBus!['id'] as String;
      final stopId = _selectedStop!['id'] as String;

      final existing =
          await ref.read(busRequestRepositoryProvider).myPendingRequest(userId);

      if (existing != null && existing['bus_id'] == busId) {
        await supabase
            .from(SupabaseConstants.passengers)
            .update({'stop_id': stopId})
            .eq('id', userId);
        if (mounted) {
          setState(() {
            _requestSent = true;
            _editing = false;
            _pendingBusNumber = _selectedBus!['bus_number'] as String?;
          });
          _showMessage('Your boarding stop has been updated.');
        }
        return;
      }

      // Cancel old requests first (safe – only touches bus_requests)
      await ref.read(busRequestRepositoryProvider).cancelPendingRequests(userId);

      // Create the new join request – if this fails, passengers table is untouched
      await ref.read(busRequestRepositoryProvider).createJoinRequest(
        passengerId: userId,
        busId: busId,
      );

      // Only update passengers after the request is confirmed
      await supabase
          .from(SupabaseConstants.passengers)
          .update({
            'stop_id': stopId,
            'approval_status': 'pending',
            'rejection_reason': null,
          })
          .eq('id', userId);

      await supabase.auth.refreshSession();
      _subscribeToApproval();

      if (mounted) {
        setState(() {
          _requestSent = true;
          _editing = false;
          _pendingBusNumber = _selectedBus!['bus_number'] as String?;
        });
      }
    } catch (e) {
      debugPrint('[BUS_SELECT] submit error: $e');
      _showError('Failed to submit request. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.primary,
    ));
  }

  void _startEditing() {
    _approvalChannel?.unsubscribe();
    setState(() {
      _editing = true;
      _selectedCity = null;
      _selectedBus = null;
      _selectedStop = null;
    });
    _loadCities();
  }

  void _subscribeToApproval() {
    final userId = supabase.auth.currentUser!.id;
    _approvalChannel?.unsubscribe();
    _approvalChannel = supabase
        .channel('bus_select_approval_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.passengers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            final newStatus = payload.newRecord['approval_status'] as String?;
            if (newStatus == 'approved' && mounted) {
              await supabase.auth.refreshSession();
              if (mounted) context.go('/passenger/home');
            }
          },
        )
        .subscribe();
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_initialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Your Bus'), centerTitle: false),
        body: const Center(child: LottieLoading()),
      );
    }

    if (_requestSent && !_editing) {
      return _buildRequestSentView(theme);
    }

    return _buildFormView(theme);
  }

  Widget _buildRequestSentView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Request Sent'),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Request Sent!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _pendingBusNumber != null
                    ? 'Your request to join Bus $_pendingBusNumber has been sent. You\'ll be notified once it\'s approved.'
                    : 'Your request has been submitted. You\'ll be notified once it\'s approved.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Waiting for approval',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              OutlinedButton.icon(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Request'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can change your bus or stop selection.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Bus'),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: _loadingCities
          ? const Center(child: LottieLoading())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Choose the bus you want to join',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDropdown(
                          label: 'City',
                          icon: Icons.location_city_outlined,
                          value: _selectedCity,
                          items: _cities,
                          displayName: (c) => c['name'] as String,
                          hint: 'Select city',
                          onChanged: (city) {
                            setState(() => _selectedCity = city);
                            if (city != null) _loadBuses(city['id'] as String);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Bus Number',
                          icon: Icons.directions_bus_outlined,
                          value: _selectedBus,
                          items: _buses,
                          displayName: (b) => 'Bus ${b['bus_number']}',
                          hint: _selectedCity == null
                              ? 'Select city first'
                              : _loadingBuses
                                  ? 'Loading buses...'
                                  : 'Select bus',
                          loading: _loadingBuses,
                          enabled: _selectedCity != null,
                          onChanged: (bus) {
                            setState(() => _selectedBus = bus);
                            if (bus != null) _loadStops(bus['route_id'] as String);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Boarding Stop',
                          icon: Icons.place_outlined,
                          value: _selectedStop,
                          items: _stops,
                          displayName: (s) => s['name'] as String,
                          hint: _selectedBus == null
                              ? 'Select bus first'
                              : _loadingStops
                                  ? 'Loading stops...'
                                  : 'Select your stop',
                          loading: _loadingStops,
                          enabled: _selectedBus != null,
                          onChanged: (stop) => setState(() => _selectedStop = stop),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSubmitBar(theme),
              ],
            ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required Map<String, dynamic>? value,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) displayName,
    required String hint,
    bool loading = false,
    bool enabled = true,
    ValueChanged<Map<String, dynamic>?>? onChanged,
  }) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: Text(loading ? 'Loading...' : hint),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(displayName(item)),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (_) => value == null ? 'Select $label' : null,
    );
  }

  Widget _buildSubmitBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: FilledButton(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('Send Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
