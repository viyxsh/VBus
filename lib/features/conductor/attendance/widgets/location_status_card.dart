import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

/// "Current Location" card at the top of the active-trip attendance view.
class LocationStatusCard extends StatelessWidget {
  final bool gpsLost;
  final bool offRoute;
  final String? stopName;
  final bool isLastStop;

  const LocationStatusCard({
    super.key,
    required this.gpsLost,
    required this.offRoute,
    required this.stopName,
    required this.isLastStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locColor = gpsLost
        ? Colors.amber.shade700
        : offRoute
        ? Colors.red.shade600
        : theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: locColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              gpsLost
                  ? Icons.gps_off_rounded
                  : offRoute
                  ? Icons.map_outlined
                  : Icons.location_on_rounded,
              size: 18,
              color: locColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.t(context, 'Current Location:'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  offRoute ? 'Off Route' : stopName ?? 'Starting',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: offRoute
                        ? Colors.red.shade700
                        : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isLastStop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                S.t(context, 'Final Stop'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
