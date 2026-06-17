import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/lottie_widgets.dart';
import '../../profile/providers/passenger_profile_providers.dart';

/// Shows the passenger's seat-booking history over the last 7 days. Reused by
/// both the seat-booking screen and the profile screen.
class BookingHistorySheet extends ConsumerWidget {
  const BookingHistorySheet({super.key});

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
