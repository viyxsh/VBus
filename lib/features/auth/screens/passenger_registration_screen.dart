import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/lottie_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/email_utils.dart';
import '../../../data/repositories/registration_repository.dart';

class PassengerRegistrationScreen extends ConsumerStatefulWidget {
  const PassengerRegistrationScreen({super.key});

  @override
  ConsumerState<PassengerRegistrationScreen> createState() =>
      _PassengerRegistrationScreenState();
}

class _PassengerRegistrationScreenState
    extends ConsumerState<PassengerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instituteIdController = TextEditingController();
  final _phoneController = TextEditingController();

  // Dropdown data
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _stops = [];

  // Selections
  Map<String, dynamic>? _selectedCity;
  Map<String, dynamic>? _selectedBus;
  Map<String, dynamic>? _selectedStop;

  // Receipt
  File? _receiptFile;
  bool _devBypass = false;

  // Loading
  bool _loadingCities = true;
  bool _loadingBuses = false;
  bool _loadingStops = false;
  bool _submitting = false;

  // From auth
  late final String _email;
  late final String _userType;

  @override
  void initState() {
    super.initState();
    _email = ref.read(registrationRepositoryProvider).currentUserEmail;
    _userType = EmailUtils.isStudentEmail(_email) ? 'student' : 'faculty';
    _loadCities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instituteIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ─── Data Loading ──────────────────────────────────────────────────────────

  Future<void> _loadCities() async {
    try {
      final data = await ref.read(registrationRepositoryProvider).cities();
      if (mounted) {
        setState(() {
          _cities = data;
          _loadingCities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadBuses(String cityId) async {
    setState(() {
      _loadingBuses = true;
      _buses = [];
      _stops = [];
      _selectedBus = null;
      _selectedStop = null;
    });
    try {
      final data =
          await ref.read(registrationRepositoryProvider).busesForCity(cityId);
      if (mounted) {
        setState(() {
          _buses = data;
          _loadingBuses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBuses = false);
    }
  }

  Future<void> _loadStops(String routeId) async {
    setState(() {
      _loadingStops = true;
      _stops = [];
      _selectedStop = null;
    });
    try {
      final data =
          await ref.read(registrationRepositoryProvider).stopsForRoute(routeId);
      if (mounted) {
        setState(() {
          _stops = data;
          _loadingStops = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStops = false);
    }
  }

  // ─── Receipt ───────────────────────────────────────────────────────────────

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (picked != null && mounted) {
      setState(() => _receiptFile = File(picked.path));
    }
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null ||
        _selectedBus == null ||
        _selectedStop == null) {
      _showError('Please complete all bus assignment fields.');
      return;
    }
    if (_receiptFile == null && !_devBypass) {
      _showError('Please upload your fee receipt.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final registration = ref.read(registrationRepositoryProvider);
      String? receiptPath;

      if (_receiptFile != null) {
        final bytes = await _receiptFile!.readAsBytes();
        receiptPath = await registration.uploadReceipt(bytes);
      }

      // Registering also refreshes the session so authStateProvider re-fetches
      // the passenger profile and the router redirects automatically.
      await registration.registerPassenger(
        name: _nameController.text.trim(),
        instituteId: _instituteIdController.text.trim().toUpperCase(),
        email: _email,
        phone: _phoneController.text.trim(),
        userType: _userType,
        cityId: _selectedCity!['id'] as String,
        busId: _selectedBus!['id'] as String,
        stopId: _selectedStop!['id'] as String,
        receiptPath: receiptPath,
        approved: kDebugMode && _devBypass,
      );
    } on PostgrestException catch (e) {
      // 23505 = unique violation; most likely institute_id taken by another user
      if (e.code == '23505' && e.message.contains('institute_id')) {
        _showError('This Institute ID is already taken by another account.');
      } else {
        _showError('Registration failed: ${e.message}');
      }
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: _loadingCities
          ? const Center(child: LottieLoading())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _UserInfoBanner(
                            email: _email,
                            userType: _userType,
                          ),
                          const SizedBox(height: 28),
                          _sectionHeader(theme, 'Personal Details'),
                          const SizedBox(height: 16),
                          _buildNameField(),
                          const SizedBox(height: 16),
                          _buildInstituteIdField(),
                          const SizedBox(height: 16),
                          _buildPhoneField(),
                          const SizedBox(height: 28),
                          _sectionHeader(theme, 'Bus Assignment'),
                          const SizedBox(height: 16),
                          _buildCityDropdown(theme),
                          const SizedBox(height: 16),
                          _buildBusDropdown(theme),
                          const SizedBox(height: 16),
                          _buildStopDropdown(theme),
                          const SizedBox(height: 28),
                          _sectionHeader(theme, 'Fee Receipt'),
                          const SizedBox(height: 16),
                          _buildReceiptPicker(theme),
                          if (kDebugMode) ...[
                            const SizedBox(height: 24),
                            _buildDevBypass(theme),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildSubmitBar(theme),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─── Form Fields ───────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Full Name',
        icon: Icons.person_outline,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
    );
  }

  Widget _buildInstituteIdField() {
    return TextFormField(
      controller: _instituteIdController,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: _userType == 'student' ? 'Registration Number' : 'Employee ID',
        hint: _userType == 'student' ? 'e.g. 23BCE11351' : 'e.g. EMP001',
        icon: Icons.badge_outlined,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Institute ID is required' : null,
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      decoration: _inputDecoration(
        label: 'Phone Number',
        hint: '10-digit mobile number',
        icon: Icons.phone_outlined,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Phone number is required';
        if (v.trim().length < 10) return 'Enter a valid phone number';
        return null;
      },
    );
  }

  Widget _buildCityDropdown(ThemeData theme) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedCity,
      decoration: _inputDecoration(label: 'City', icon: Icons.location_city_outlined),
      hint: const Text('Select city'),
      items: _cities
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c['name'] as String),
              ))
          .toList(),
      onChanged: (city) {
        setState(() => _selectedCity = city);
        if (city != null) _loadBuses(city['id'] as String);
      },
      validator: (_) => _selectedCity == null ? 'Select a city' : null,
    );
  }

  Widget _buildBusDropdown(ThemeData theme) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedBus,
      decoration: _inputDecoration(
        label: 'Bus Number',
        icon: Icons.directions_bus_outlined,
      ),
      hint: Text(
        _selectedCity == null
            ? 'Select city first'
            : _loadingBuses
                ? 'Loading buses...'
                : 'Select bus',
      ),
      items: _buses
          .map((b) => DropdownMenuItem(
                value: b,
                child: Text('Bus ${b['bus_number']}'),
              ))
          .toList(),
      onChanged: _selectedCity == null
          ? null
          : (bus) {
              setState(() => _selectedBus = bus);
              if (bus != null) _loadStops(bus['route_id'] as String);
            },
      validator: (_) => _selectedBus == null ? 'Select a bus' : null,
    );
  }

  Widget _buildStopDropdown(ThemeData theme) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedStop,
      decoration: _inputDecoration(
        label: 'Boarding Stop',
        icon: Icons.place_outlined,
      ),
      hint: Text(
        _selectedBus == null
            ? 'Select bus first'
            : _loadingStops
                ? 'Loading stops...'
                : 'Select your stop',
      ),
      items: _stops
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s['name'] as String),
              ))
          .toList(),
      onChanged: _selectedBus == null
          ? null
          : (stop) => setState(() => _selectedStop = stop),
      validator: (_) => _selectedStop == null ? 'Select a stop' : null,
    );
  }

  Widget _buildReceiptPicker(ThemeData theme) {
    return GestureDetector(
      onTap: _devBypass ? null : _pickReceipt,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 140,
        decoration: BoxDecoration(
          color: _devBypass
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _receiptFile != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: _receiptFile != null ? 2 : 1,
          ),
        ),
        child: _receiptFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_receiptFile!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _receiptFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 32,
                    color: _devBypass
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _devBypass ? 'Skipped (dev mode)' : 'Tap to upload receipt',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _devBypass
                          ? theme.colorScheme.outlineVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!_devBypass)
                    Text(
                      'JPG or PNG',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDevBypass(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report_outlined, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dev mode: skip receipt & auto-approve',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _devBypass,
            activeColor: Colors.orange,
            onChanged: (v) => setState(() {
              _devBypass = v;
              if (v) _receiptFile = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        16 + MediaQuery.of(context).padding.bottom,
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
            : const Text(
                'Submit Registration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── User Info Banner ─────────────────────────────────────────────────────────

class _UserInfoBanner extends StatelessWidget {
  final String email;
  final String userType;

  const _UserInfoBanner({required this.email, required this.userType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = userType == 'student';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primaryContainer,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isStudent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isStudent ? 'Student' : 'Faculty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
