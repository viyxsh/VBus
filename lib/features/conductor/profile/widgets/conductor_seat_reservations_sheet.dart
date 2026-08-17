import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../core/widgets/profile_rows.dart';
import '../../../../data/models/seat_reservation.dart';
import '../../../../data/repositories/seat_reservation_repository.dart';
import '../providers/conductor_profile_providers.dart';

class ConductorSeatReservationsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final String busId;
  const ConductorSeatReservationsSheet(
      {super.key, required this.profile, required this.busId});

  @override
  ConsumerState<ConductorSeatReservationsSheet> createState() =>
      _ConductorSeatReservationsSheetState();
}

class _ConductorSeatReservationsSheetState
    extends ConsumerState<ConductorSeatReservationsSheet> {
  Future<void> _approve(SeatReservation r) async {
    final conductorId = widget.profile['id'] as String;
    try {
      await ref
          .read(seatReservationRepositoryProvider)
          .approveReservation(r.id, conductorId);
      ref.invalidate(pendingSeatReservationsProvider(widget.busId));
      if (mounted) {
        final approveName = r.passengerName ?? 'Faculty';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$approveName's seat reservation approved"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('[SEAT_RESERVE] approve error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to approve reservation'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _reject(SeatReservation r) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Reservation'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Seat already taken',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t(context, 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(S.t(context, 'Reject')),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(seatReservationRepositoryProvider).rejectReservation(
            reservationId: r.id,
            conductorId: widget.profile['id'] as String,
            reason: reason.isNotEmpty ? reason : null,
          );
      ref.invalidate(pendingSeatReservationsProvider(widget.busId));
      if (mounted) {
        final rejectName = r.passengerName ?? 'Faculty';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$rejectName's reservation rejected"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } catch (e) {
      debugPrint('[SEAT_RESERVE] reject error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bus = widget.profile['buses'] as Map;
    final busNum = bus['bus_number'] as String? ?? '?';
    final reservationsAsync =
        ref.watch(pendingSeatReservationsProvider(widget.busId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: sheetHeader(
                context, '${S.t(context, 'Seat Reservations')} — ${S.t(context, 'Bus')} $busNum'),
          ),
          const Divider(),
          Expanded(
            child: reservationsAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                  child: Text('Failed to load',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
              data: (reservations) {
                if (reservations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48,
                            color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No pending reservations',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: reservations.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final r = reservations[i];
                    final name = r.passengerName ?? 'Unknown';
                    final id = r.passengerInstituteId ?? '';
                    final type = r.passengerUserType ?? 'faculty';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'F',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '$id · ${type == 'faculty' ? S.t(context, 'Faculty') : S.t(context, 'Student')} · Seat ${r.seatNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 20),
                            tooltip: S.t(context, 'Approve'),
                            onPressed: () => _approve(r),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel_outlined,
                                color: theme.colorScheme.error, size: 20),
                            tooltip: S.t(context, 'Reject'),
                            onPressed: () => _reject(r),
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
