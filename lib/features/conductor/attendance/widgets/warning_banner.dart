import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

/// Shared amber warning banner used for GPS-lost and off-route states.
class WarningBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showNextStop;
  final bool processing;
  final VoidCallback onNextStop;

  const WarningBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.showNextStop,
    required this.processing,
    required this.onNextStop,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade800.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showNextStop) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: processing ? null : onNextStop,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(S.t(context, 'Next Stop →')),
            ),
          ],
        ],
      ),
    );
  }
}
