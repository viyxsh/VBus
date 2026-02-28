import 'package:flutter/material.dart';

/// Shown instead of the live Google Map on the web demo build (which has no
/// Maps JavaScript workflow configured). The route stops and live ETA remain
/// fully functional in the bottom sheet below this placeholder.
class WebMapPlaceholder extends StatelessWidget {
  const WebMapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Padding(
        // Leave room for the bottom sheet so the text isn't hidden behind it.
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'Live map preview',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'The interactive map runs in the mobile app. In this web demo, '
              'the route stops and live ETA are shown in the panel below.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
