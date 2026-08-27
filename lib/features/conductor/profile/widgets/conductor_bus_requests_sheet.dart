import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../core/widgets/profile_rows.dart';
import '../../../../data/repositories/bus_request_repository.dart';
import '../providers/conductor_profile_providers.dart';

class ConductorBusRequestsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final String busId;
  const ConductorBusRequestsSheet({
    super.key,
    required this.profile,
    required this.busId,
  });

  @override
  ConsumerState<ConductorBusRequestsSheet> createState() =>
      _ConductorBusRequestsSheetState();
}

class _ConductorBusRequestsSheetState
    extends ConsumerState<ConductorBusRequestsSheet> {
  RealtimeChannel? _busRequestsChannel;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _busRequestsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _busRequestsChannel = ref
        .read(busRequestRepositoryProvider)
        .subscribeToBusRequests(widget.busId, (_) {
          ref.invalidate(busRequestsProvider(widget.busId));
          ref.invalidate(busPassengersProvider(widget.busId));
        });
  }

  Future<void> _approve(String requestId, String studentName) async {
    try {
      await ref.read(busRequestRepositoryProvider).approveRequest(requestId);
      ref.invalidate(busRequestsProvider(widget.busId));
      ref.invalidate(busPassengersProvider(widget.busId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName has been approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[BUS_REQ] approve error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to approve request'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _reject(String requestId, String studentName) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Bus is full',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.t(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref
          .read(busRequestRepositoryProvider)
          .rejectRequest(
            requestId: requestId,
            reason: reason.isNotEmpty ? reason : null,
          );
      ref.invalidate(busRequestsProvider(widget.busId));
      ref.invalidate(busPassengersProvider(widget.busId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName has been rejected'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[BUS_REQ] reject error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to reject request'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bus = widget.profile['buses'] as Map;
    final busNum = bus['bus_number'] as String? ?? '?';
    final studentSeats = (bus['student_seats'] as num?)?.toInt() ?? 0;
    final requestsAsync = ref.watch(busRequestsProvider(widget.busId));
    final passengersAsync = ref.watch(busPassengersProvider(widget.busId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sheetHeader(context, S.t(context, 'Bus Requests')),
                const SizedBox(height: 12),
                // Capacity card
                passengersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (passengers) {
                    final approvedCount = passengers
                        .where((p) => p['approval_status'] == 'approved')
                        .length;
                    final available = studentSeats - approvedCount;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_seat,
                            color: theme.colorScheme.tertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${S.t(context, 'Bus')} $busNum · $approvedCount / $studentSeats seats filled',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '$available available',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: available > 0
                                  ? Colors.green
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No pending requests',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: requests.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final r = requests[i];
                    final passenger = r['passengers'] as Map;
                    final name = passenger['name'] as String? ?? 'Unknown';
                    final instituteId =
                        passenger['institute_id'] as String? ?? '';
                    final type = passenger['user_type'] as String? ?? 'student';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$instituteId · ${type == 'faculty' ? S.t(context, 'Faculty') : S.t(context, 'Student')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 20,
                            ),
                            tooltip: S.t(context, 'Approve'),
                            onPressed: () => _approve(r['id'] as String, name),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.cancel_outlined,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            tooltip: S.t(context, 'Reject'),
                            onPressed: () => _reject(r['id'] as String, name),
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
}
