import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

/// Shown after a trip ends: summary pills and a New Trip button.
class TripEndedView extends StatelessWidget {
  final Map<String, int> stats;
  final VoidCallback onNewTrip;

  const TripEndedView({
    super.key,
    required this.stats,
    required this.onNewTrip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 52,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.t(context, 'Trip Complete'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SummaryPill(
                  '${stats['present']}',
                  S.t(context, 'Present'),
                  Colors.green.shade700,
                  Colors.green.shade50,
                ),
                const SizedBox(width: 8),
                _SummaryPill(
                  '${stats['missing']}',
                  S.t(context, 'Missed'),
                  Colors.purple.shade400,
                  Colors.purple.shade50,
                ),
                const SizedBox(width: 8),
                _SummaryPill(
                  '${stats['absent']}',
                  S.t(context, 'Absent'),
                  Colors.red.shade600,
                  Colors.red.shade50,
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onNewTrip,
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(S.t(context, 'New Trip')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String count;
  final String label;
  final Color textColor;
  final Color bgColor;

  const _SummaryPill(this.count, this.label, this.textColor, this.bgColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
