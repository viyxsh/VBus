import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/message_notification_service.dart';
import '../../../core/widgets/lottie_widgets.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/chat_repository.dart';
import '../providers/chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String title;
  final bool isBroadcast;
  final String? phone;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.title,
    this.isBroadcast = true,
    this.phone,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Tell the notification service this room is open — suppress its notifications
    MessageNotificationService.currentRoomId = widget.roomId;
  }

  @override
  void dispose() {
    // Room no longer visible — re-enable notifications for it
    if (MessageNotificationService.currentRoomId == widget.roomId) {
      MessageNotificationService.currentRoomId = null;
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);
    try {
      final senderName =
          ref.read(currentUserDisplayNameProvider).valueOrNull ?? 'Unknown';
      await ref.read(chatRepositoryProvider).sendMessage(
            roomId: widget.roomId,
            senderName: senderName,
            content: text,
          );
    } catch (e) {
      _controller.text = text;
      debugPrint('[CHAT] send error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChatInfoSheet(
        roomId: widget.roomId,
        title: widget.title,
        phone: widget.phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          if (!widget.isBroadcast) ...[
            if (widget.phone != null && widget.phone!.isNotEmpty)
              IconButton(
                icon: Builder(builder: (ctx) => SvgPicture.asset(
                  'assets/icons/phone-call.svg', width: 22, height: 22,
                  colorFilter: ColorFilter.mode(Theme.of(ctx).colorScheme.onSurface, BlendMode.srcIn))),
                tooltip: 'Call',
                onPressed: () async {
                  final clean = widget.phone!
                      .replaceAll(RegExp(r'[^\d+]'), '');
                  final launched = await launchUrl(
                      Uri(scheme: 'tel', path: clean));
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Calling is not supported on this device')),
                    );
                  }
                },
              ),
            IconButton(
              icon: SvgPicture.asset('assets/icons/info.svg', width: 22, height: 22),
              tooltip: 'Info',
              onPressed: () => _showInfo(context),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => _buildErrorState(theme),
              data: (messages) => messages.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _buildBubble(messages[i], theme),
                    ),
            ),
          ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Could not load messages',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                ref.invalidate(chatMessagesProvider(widget.roomId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'No messages yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Say hello!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, ThemeData theme) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        msg.senderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    msg.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMe
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.sentAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : SvgPicture.asset('assets/icons/send.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${local.day}/${local.month}';
  }
}

// ─── Chat Info Sheet ──────────────────────────────────────────────────────────

class _ChatInfoSheet extends ConsumerWidget {
  final String roomId;
  final String title;
  final String? phone;

  const _ChatInfoSheet({
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
            isConductor ? 'Passenger' : 'Conductor',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          detailsAsync.when(
            loading: () => const LottieLoading(size: 60),
            error: (_, __) => Text('Could not load details',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            data: (details) {
              if (details == null) {
                return Text('Could not load details',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow(theme, Icons.phone_outlined, 'Phone',
                      (details['phone'] as String?)?.isNotEmpty == true
                          ? details['phone'] as String
                          : 'Not provided'),
                  if (!isConductor) ...[
                    _infoRow(theme, Icons.badge_outlined, 'ID',
                        details['institute_id'] as String? ?? '—'),
                    _infoRow(theme, Icons.school_outlined, 'Type',
                        (details['user_type'] as String?) == 'faculty'
                            ? 'Faculty'
                            : 'Student'),
                    _infoRow(theme, Icons.place_outlined, 'Boarding Stop',
                        (details['bus_stops'] as Map?)?['name'] as String? ??
                            '—'),
                  ],
                  if (isConductor)
                    _infoRow(theme, Icons.email_outlined, 'Email',
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
