import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/widgets/lottie_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/bus_request_repository.dart';
import '../../../data/repositories/registration_repository.dart';
import '../../../main.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState
    extends ConsumerState<PendingApprovalScreen> {
  String _status = 'pending';
  String? _rejectionReason;
  bool _loadingProfile = true;

  Map<String, dynamic>? _busRequest;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data =
          await ref.read(registrationRepositoryProvider).approvalInfo();

      final userId = supabase.auth.currentUser!.id;
      final request =
          await ref.read(busRequestRepositoryProvider).latestRequest(userId);

      if (mounted) {
        setState(() {
          _status = data['approval_status'] as String? ?? 'pending';
          _rejectionReason = data['rejection_reason'] as String?;
          _busRequest = request;
          _loadingProfile = false;
        });
      }

      _subscribeToChanges();
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
      _subscribeToChanges();
    }
  }

  void _subscribeToChanges() {
    _channel = ref.read(registrationRepositoryProvider).subscribeApproval(
      (newRecord) {
        final newStatus = newRecord['approval_status'] as String? ?? 'pending';
        final reason = newRecord['rejection_reason'] as String?;

        if (!mounted) return;
        setState(() {
          _status = newStatus;
          _rejectionReason = reason;
        });

        if (newStatus == 'approved') {
          supabase.auth.refreshSession();
          context.go('/passenger/home');
        }
      },
    );
  }

  void _requestAnotherBus() {
    context.go('/auth/bus-select');
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Registration Status'),
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
      body: _loadingProfile
          ? const Center(child: LottieLoading())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _status == 'rejected'
                    ? _buildRejectedView(theme)
                    : _buildPendingView(theme),
              ),
            ),
    );
  }

  Widget _buildPendingView(ThemeData theme) {
    final busNumber = _busRequest?['buses']?['bus_number'] as String?;
    final hasActiveRequest = _busRequest?['status'] == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasActiveRequest
                  ? Icons.hourglass_top_rounded
                  : Icons.error_outline,
              size: 44,
              color: hasActiveRequest
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          hasActiveRequest ? 'Request Pending' : 'No Active Request',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          hasActiveRequest
              ? (busNumber != null
                  ? 'Your request to join Bus $busNumber has been sent. You\'ll be notified once it\'s approved.'
                  : 'Your request has been submitted and is being reviewed.')
              : 'Your account shows a pending status but no active bus request was found. Please submit a new request.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        _buildStatusCard(theme, busNumber),
        const SizedBox(height: 32),
        if (hasActiveRequest) ...[
          _buildWhatHappensNext(theme),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _requestAnotherBus,
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
        ] else ...[
          FilledButton.icon(
            onPressed: _requestAnotherBus,
            icon: const Icon(Icons.directions_bus_outlined, size: 18),
            label: const Text('Request a Bus'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme, String? busNumber) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primaryContainer,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pending_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: Pending',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatHappensNext(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What happens next?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildStep(theme, '1', 'The conductor of your selected bus reviews your request'),
        const SizedBox(height: 10),
        _buildStep(theme, '2', 'You\'ll be notified once the conductor approves'),
        const SizedBox(height: 10),
        _buildStep(theme, '3', 'If rejected, you can request a different bus'),
      ],
    );
  }

  Widget _buildStep(ThemeData theme, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedView(ThemeData theme) {
    final busNumber = _busRequest?['buses']?['bus_number'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cancel_outlined,
              size: 44,
              color: theme.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Request Rejected',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          busNumber != null
              ? 'Your request to join Bus $busNumber has been rejected by the conductor.'
              : 'Your bus request was not approved.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        if (_rejectionReason != null && _rejectionReason!.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildRejectionReasonCard(theme),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _requestAnotherBus,
          icon: const Icon(Icons.directions_bus_outlined, size: 18),
          label: const Text('Request a Different Bus'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You can choose a different bus and send a new request to its conductor.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRejectionReasonCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.errorContainer,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejection Reason',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rejectionReason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
