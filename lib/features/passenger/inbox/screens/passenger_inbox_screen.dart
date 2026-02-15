import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/models/inbox_room.dart';
import '../../../../data/repositories/chat_repository.dart';
import '../../../chat/providers/chat_providers.dart';

class PassengerInboxScreen extends ConsumerStatefulWidget {
  const PassengerInboxScreen({super.key});

  @override
  ConsumerState<PassengerInboxScreen> createState() =>
      _PassengerInboxScreenState();
}

class _PassengerInboxScreenState extends ConsumerState<PassengerInboxScreen> {
  bool _creating = false;

  Future<void> _refresh() async {
    ref.invalidate(passengerInboxProvider);
    await ref.read(passengerInboxProvider.future);
  }

  Future<void> _startDM(PassengerInbox inbox) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final roomId = await ref
          .read(chatRepositoryProvider)
          .createDirectRoomForCurrentPassenger(inbox.busId);
      await _refresh();
      if (mounted) {
        context.push('/chat/$roomId', extra: {
          'title': inbox.conductorName,
          'isBroadcast': false,
          'phone': inbox.conductorPhone,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to start chat: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inboxAsync = ref.watch(passengerInboxProvider);

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      body: Column(
        children: [
          // ── Gradient header ───────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3D3D8F), Color(0xFF6C63D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    child: Text(
                      S.t(context, 'Inbox'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),

          // ── Content card — overlaps header ────────────────────────────────
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.30 : 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: inboxAsync.when(
                  loading: () => const Center(child: LottieLoading()),
                  error: (e, _) => _buildError(theme),
                  data: (inbox) => RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 14, bottom: 20),
                      children: [
                        if (inbox.broadcast != null)
                          _buildTile(inbox.broadcast!, theme)
                        else
                          _buildUnavailableTile('Bus ${inbox.busNumber}',
                              'assets/icons/passengers.svg', theme),
                        if (inbox.direct != null)
                          _buildTile(inbox.direct!, theme)
                        else
                          _buildStartDMTile(inbox, theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(InboxRoom room, ThemeData theme) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: SvgPicture.asset(
          room.isBroadcast
              ? 'assets/icons/passengers.svg'
              : 'assets/icons/circle-user.svg',
          width: 22, height: 22,
          colorFilter: ColorFilter.mode(
              theme.colorScheme.primary, BlendMode.srcIn),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(room.title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          _badge(room.isBroadcast ? S.t(context, 'Broadcast') : S.t(context, 'Private'), theme),
        ],
      ),
      subtitle: room.lastMessage != null
          ? Text(
              room.lastIsMe
                  ? '${S.t(context, 'You')}: ${room.lastMessage}'
                  : room.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Text(S.t(context, 'No messages yet'),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outlineVariant,
                  fontStyle: FontStyle.italic)),
      trailing: room.lastMessageAt != null
          ? Text(_formatTime(room.lastMessageAt!),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          : null,
      onTap: () => context.push('/chat/${room.id}', extra: {
        'title': room.title,
        'isBroadcast': room.isBroadcast,
        'phone': room.phone,
      }),
    );
  }

  Widget _buildStartDMTile(PassengerInbox inbox, ThemeData theme) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: SvgPicture.asset('assets/icons/circle-user.svg',
            width: 22, height: 22,
            colorFilter: ColorFilter.mode(
                theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(inbox.conductorName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          _badge(S.t(context, 'Private'), theme),
        ],
      ),
      subtitle: Text(S.t(context, 'Tap to start private chat'),
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic)),
      trailing: _creating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.add_comment_outlined,
              color: theme.colorScheme.primary),
      onTap: _creating ? null : () => _startDM(inbox),
    );
  }

  Widget _buildUnavailableTile(
      String title, String svgPath, ThemeData theme) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: SvgPicture.asset(svgPath, width: 22, height: 22,
            colorFilter: ColorFilter.mode(
                theme.colorScheme.onSurfaceVariant, BlendMode.srcIn)),
      ),
      title: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(S.t(context, 'Not set up yet'),
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outlineVariant,
              fontStyle: FontStyle.italic)),
    );
  }

  Widget _badge(String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(S.t(context, 'Failed to load inbox'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => ref.invalidate(passengerInboxProvider),
              child: Text(S.t(context, 'Retry'))),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}';
  }
}
