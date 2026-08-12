import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/booking_window.dart';
import '../models/seat_info.dart';

/// Owns its own Timer so only the status bar text rebuilds every second,
/// not the entire seat layout.
class BookingStatusBar extends StatefulWidget {
  final BookingState bookingState;
  final Duration timeUntilNextEvent;
  final bool showLegend;
  final Widget Function() buildLegend;

  const BookingStatusBar({
    super.key,
    required this.bookingState,
    required this.timeUntilNextEvent,
    required this.showLegend,
    required this.buildLegend,
  });

  @override
  State<BookingStatusBar> createState() => _BookingStatusBarState();
}

class _BookingStatusBarState extends State<BookingStatusBar> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeUntilNextEvent;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining.inSeconds > 0
            ? _remaining - const Duration(seconds: 1)
            : _recompute();
      });
    });
  }

  Duration _recompute() => BookingWindow.timeUntilNextEvent(DateTime.now());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _remaining;
    final durStr = '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
    final isLocked = widget.bookingState == BookingState.locked;

    final message = isLocked
        ? 'Seat selection starts in $durStr'
        : 'Open — closes in $durStr';
    final color = isLocked
        ? theme.colorScheme.onSurfaceVariant
        : Colors.green.shade700;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Text(message,
              style: theme.textTheme.bodySmall?.copyWith(color: color)),
          if (widget.showLegend) ...[
            const SizedBox(height: 10),
            widget.buildLegend(),
          ],
        ],
      ),
    );
  }
}
