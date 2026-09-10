import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../models/attendance_roster.dart';

/// Tappable stat chips above the attendance list; tapping filters the list
/// by state.
class AttendanceStatsChips extends StatelessWidget {
  final int total;
  final Map<String, int> stats;
  final AttendanceState? selected;
  final ValueChanged<AttendanceState?> onSelected;

  const AttendanceStatsChips({
    super.key,
    required this.total,
    required this.stats,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
      child: Row(
        children: [
          _chip(context, theme, S.t(context, 'Total'), total, null, null),
          _chip(
            context,
            theme,
            S.t(context, 'Present'),
            stats['present']!,
            Colors.green.shade700,
            AttendanceState.present,
          ),
          _chip(
            context,
            theme,
            S.t(context, 'Missed'),
            stats['missing']!,
            Colors.purple.shade400,
            AttendanceState.missing,
          ),
          _chip(
            context,
            theme,
            S.t(context, 'Absent'),
            stats['absent']!,
            theme.colorScheme.error,
            AttendanceState.absent,
          ),
          _chip(
            context,
            theme,
            S.t(context, 'Waiting'),
            stats['waiting']!,
            Colors.amber.shade700,
            AttendanceState.waiting,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    ThemeData theme,
    String label,
    int count,
    Color? color,
    AttendanceState? filterValue,
  ) {
    final isSelected = selected == filterValue;
    final isDark = theme.brightness == Brightness.dark;
    final chipColor = color ?? theme.colorScheme.primary;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor
                : (isDark
                      ? theme.colorScheme.surfaceContainerHigh
                      : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(color: theme.colorScheme.outlineVariant, width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: chipColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.15 : 0.06,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(isSelected ? null : filterValue),
              splashColor: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : chipColor.withValues(alpha: 0.1),
              highlightColor: isSelected
                  ? Colors.white.withValues(alpha: 0.1)
                  : chipColor.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
