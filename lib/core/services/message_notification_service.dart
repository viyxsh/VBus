import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/user_repository.dart';

/// Listens for new messages in all of the user's chat rooms and shows
/// a local notification when a message arrives in a room that isn't
/// currently open.
class MessageNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'new_messages';
  static const _channelName = 'New Messages';

  // Rooms the user is a member of
  static final Set<String> _roomIds = {};
  // The room currently open on screen (suppress notifications for it)
  static String? currentRoomId;

  static RealtimeChannel? _channel;

  static Future<void> start() async {
    if (kIsWeb) return; // local notifications aren't supported on web
    await stop();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final users = UserRepository();
    final chat = ChatRepository(users);

    // Resolve which bus this user belongs to
    final busId = await users.currentUserBusId();
    if (busId == null) return;

    // Load all room IDs for this bus
    _roomIds
      ..clear()
      ..addAll(await chat.roomIdsForBus(busId));

    // Subscribe to message inserts and filter in-callback
    _channel = client
        .channel('msg_notif_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final record = payload.newRecord;
            final roomId   = record['chat_room_id'] as String?;
            final senderId = record['sender_id']    as String?;
            final content  = record['content']      as String?;
            final name     = record['sender_name']  as String? ?? 'New message';

            // Skip if not in our rooms, sent by self, or room is currently open
            if (roomId == null) return;
            if (!_roomIds.contains(roomId)) return;
            if (senderId == userId) return;
            if (roomId == currentRoomId) return;

            await _show(
              id: roomId.hashCode,
              title: name,
              body: content ?? '📎 Attachment',
            );
          },
        )
        .subscribe();
  }

  static Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
    _roomIds.clear();
    currentRoomId = null;
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: 'Chat message alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
