import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── Shared profile/settings card helpers ─────────────────────────────────────
//
// Used by both the passenger and conductor profile screens so their
// settings-style cards render identically.

Widget profileSectionLabel(String label, ThemeData theme) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
  child: Text(
    label,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
);

Widget profileCard(List<Widget> children, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1E2C) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

Widget profileDivider(ThemeData theme) => Divider(
  height: 1,
  indent: 52,
  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
);

Widget profileRow(
  String svgPath,
  String label, {
  String? subtitle,
  VoidCallback? onTap,
  Color? color,
  String? badge,
  required ThemeData theme,
}) {
  final iconColor = color ?? theme.colorScheme.onSurfaceVariant;
  final labelColor = color ?? theme.colorScheme.onSurface;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SvgPicture.asset(
            svgPath,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (onTap != null)
            SvgPicture.asset(
              'assets/icons/angle-small-right.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
        ],
      ),
    ),
  );
}

Widget profileToggleRow(
  String svgPath,
  String label, {
  String? hint,
  required bool value,
  required ValueChanged<bool> onChanged,
  required ThemeData theme,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  child: Row(
    children: [
      SvgPicture.asset(
        svgPath,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          theme.colorScheme.onSurfaceVariant,
          BlendMode.srcIn,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  ),
);

Widget profileValueRow(
  String svgPath,
  String label, {
  required String value,
  VoidCallback? onTap,
  required ThemeData theme,
}) => InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(14),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        SvgPicture.asset(
          svgPath,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.onSurfaceVariant,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        SvgPicture.asset(
          'assets/icons/angle-small-right.svg',
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.onSurfaceVariant,
            BlendMode.srcIn,
          ),
        ),
      ],
    ),
  ),
);

// ─── Bottom sheet helpers ─────────────────────────────────────────────────────

Widget sheetHeader(BuildContext context, String title) {
  return Row(
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}

InputDecoration sheetInputDecoration(
  String label,
  IconData icon, {
  double borderRadius = 12,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}
