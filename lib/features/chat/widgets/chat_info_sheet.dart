import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/lottie_widgets.dart';
import '../../../data/repositories/chat_repository.dart';
import '../providers/chat_providers.dart';

class ChatInfoSheet extends ConsumerWidget {
  final String roomId;
  final String title;
  final String? phone;

  const ChatInfoSheet({
    super.key,
    required this.roomId,
    required this.title,
    this.phone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isConductor = ref.read(chatRepositoryProvider).isConductor;
    final detailsAsync = ref.watch(chatPartnerInfoProvider(roomId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Avatar + name
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            S.t(context, isConductor ? 'Passenger' : 'Conductor'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          detailsAsync.when(
            loading: () => const LottieLoading(size: 60),
            error: (_, __) => Text(S.t(context, 'Could not load details'),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            data: (details) {
              if (details == null) {
                return Text(S.t(context, 'Could not load details'),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow(
                      theme,
                      Icons.phone_outlined,
                      S.t(context, 'Phone'),
                      (details['phone'] as String?)?.isNotEmpty == true
                          ? details['phone'] as String
                          : S.t(context, 'Not provided')),
                  if (!isConductor) ...[
                    _infoRow(theme, Icons.badge_outlined, S.t(context, 'ID'),
                        details['institute_id'] as String? ?? '—'),
                    _infoRow(
                        theme,
                        Icons.school_outlined,
                        S.t(context, 'Type'),
                        (details['user_type'] as String?) == 'faculty'
                            ? S.t(context, 'Faculty')
                            : S.t(context, 'Student')),
                    _infoRow(
                        theme,
                        Icons.place_outlined,
                        S.t(context, 'Boarding Stop'),
                        (details['bus_stops'] as Map?)?['name'] as String? ??
                            '—'),
                  ],
                  if (isConductor)
                    _infoRow(theme, Icons.email_outlined, S.t(context, 'Email'),
                        details['email'] as String? ?? '—'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text('$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
