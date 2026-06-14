import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../main.dart';
import '../models/chat_message.dart';
import '../models/inbox_room.dart';
import 'user_repository.dart';

part 'chat_repository.g.dart';

@riverpod
ChatRepository chatRepository(Ref ref) =>
    ChatRepository(ref.watch(userRepositoryProvider));

/// All data access for chat rooms and messages.
class ChatRepository {
  ChatRepository(this._users);

  final UserRepository _users;

  /// Most recent [limit] messages for a room, newest first.
  Future<List<ChatMessage>> recentMessages(
    String roomId, {
    int limit = 100,
  }) async {
    final data = await supabase
        .from(SupabaseConstants.messages)
        .select('id, sender_id, sender_name, content, sent_at')
        .eq('chat_room_id', roomId)
        .order('sent_at', ascending: false)
        .limit(limit); // prevent OOM on long-running chats
    return (data as List)
        .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Live stream of a room's messages, newest first. Emits the initial page
  /// immediately, then re-emits the full list whenever a new message arrives.
  Stream<List<ChatMessage>> watchMessages(
    String roomId, {
    int limit = 100,
  }) {
    final controller = StreamController<List<ChatMessage>>();
    final messages = <ChatMessage>[];
    RealtimeChannel? channel;

    Future<void> init() async {
      messages.addAll(await recentMessages(roomId, limit: limit));
      if (controller.isClosed) return;
      controller.add(List.unmodifiable(messages));

      channel = supabase
          .channel('chat_$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: SupabaseConstants.messages,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_room_id',
              value: roomId,
            ),
            callback: (payload) {
              if (controller.isClosed) return;
              messages.insert(0, ChatMessage.fromMap(payload.newRecord));
              controller.add(List.unmodifiable(messages));
            },
          )
          .subscribe();
    }

    controller.onListen = () => init();
    controller.onCancel = () async {
      await channel?.unsubscribe();
      await controller.close();
    };
    return controller.stream;
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderName,
    required String content,
  }) async {
    await supabase.from(SupabaseConstants.messages).insert({
      'chat_room_id': roomId,
      'sender_id': supabase.auth.currentUser!.id,
      'sender_name': senderName,
      'content': content,
      'type': 'text',
    });
  }

  Future<String> currentUserDisplayName() => _users.currentUserDisplayName();

  /// All chat room IDs belonging to a bus (broadcast + every direct room).
  Future<List<String>> roomIdsForBus(String busId) async {
    final rooms = await supabase
        .from(SupabaseConstants.chatRooms)
        .select('id')
        .eq('bus_id', busId);
    return (rooms as List).map((r) => r['id'] as String).toList();
  }

  /// Details about the other party in a room, for the chat info sheet.
  /// For a conductor this is the passenger; for a passenger it is the
  /// conductor on the bus. Returns null when nothing could be resolved.
  Future<Map<String, dynamic>?> chatPartnerInfo(String roomId) async {
    if (_users.isConductor) {
      final room = await supabase
          .from(SupabaseConstants.chatRooms)
          .select('passenger_id')
          .eq('id', roomId)
          .single();
      final passengerId = room['passenger_id'] as String;
      final data = await supabase
          .from(SupabaseConstants.passengers)
          .select(
              'name, email, phone, user_type, institute_id, bus_stops(name)')
          .eq('id', passengerId)
          .single();
      return Map<String, dynamic>.from(data);
    }

    final room = await supabase
        .from(SupabaseConstants.chatRooms)
        .select('bus_id')
        .eq('id', roomId)
        .single();
    final busId = room['bus_id'] as String;
    final data = await supabase
        .from(SupabaseConstants.staffCredentials)
        .select('display_name, username, phone, role')
        .eq('bus_id', busId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  bool get isConductor => _users.isConductor;

  // ─── Inbox ─────────────────────────────────────────────────────────────────

  /// Fetches the most recent message per room for the given room IDs in a
  /// single query, returning a map keyed by room ID.
  Future<Map<String, Map<String, dynamic>>> _lastMessageByRoom(
      List<String> roomIds) async {
    final result = <String, Map<String, dynamic>>{};
    if (roomIds.isEmpty) return result;
    final msgs = await supabase
        .from(SupabaseConstants.messages)
        .select('chat_room_id, content, sent_at, sender_id')
        .inFilter('chat_room_id', roomIds)
        .order('sent_at', ascending: false)
        .limit(roomIds.length * 3);
    for (final m in msgs as List) {
      final rid = m['chat_room_id'] as String;
      result.putIfAbsent(rid, () => m as Map<String, dynamic>);
    }
    return result;
  }

  /// Loads the passenger inbox (broadcast + the passenger's own direct room).
  Future<PassengerInbox> passengerInbox() async {
    final userId = supabase.auth.currentUser!.id;

    final profile = await supabase
        .from(SupabaseConstants.passengers)
        .select('bus_id, buses(bus_number)')
        .eq('id', userId)
        .single();

    final busId = profile['bus_id'] as String;
    final busNumber =
        (profile['buses'] as Map?)?['bus_number']?.toString() ?? '?';

    final results = await Future.wait([
      supabase
          .from(SupabaseConstants.chatRooms)
          .select('id')
          .eq('bus_id', busId)
          .eq('room_type', 'broadcast')
          .maybeSingle(),
      supabase
          .from(SupabaseConstants.chatRooms)
          .select('id')
          .eq('bus_id', busId)
          .eq('room_type', 'direct')
          .eq('passenger_id', userId)
          .maybeSingle(),
      supabase
          .from(SupabaseConstants.staffCredentials)
          .select('display_name, username, phone')
          .eq('bus_id', busId)
          .maybeSingle(),
    ]);

    final broadcastData = results[0];
    final dmData = results[1];
    final conductorData = results[2];

    final conductorName = conductorData?['display_name'] as String? ??
        conductorData?['username'] as String? ??
        'Conductor';
    final conductorPhone = conductorData?['phone'] as String?;

    final roomIds = [
      if (broadcastData != null) broadcastData['id'] as String,
      if (dmData != null) dmData['id'] as String,
    ];
    final lastByRoom = await _lastMessageByRoom(roomIds);

    InboxRoom toRoom(String id, String title, bool isBroadcast,
        {String? phone}) {
      final last = lastByRoom[id];
      return InboxRoom(
        id: id,
        title: title,
        isBroadcast: isBroadcast,
        phone: phone,
        lastMessage: last?['content'] as String?,
        lastMessageAt: last != null
            ? DateTime.parse(last['sent_at'] as String)
            : null,
        lastIsMe: last?['sender_id'] == userId,
      );
    }

    return PassengerInbox(
      busId: busId,
      busNumber: busNumber,
      conductorName: conductorName,
      conductorPhone: conductorPhone,
      broadcast: broadcastData != null
          ? toRoom(broadcastData['id'] as String, 'Bus $busNumber', true)
          : null,
      direct: dmData != null
          ? toRoom(dmData['id'] as String, conductorName, false,
              phone: conductorPhone)
          : null,
    );
  }

  /// Creates (if needed) the current passenger's direct room with their
  /// conductor and returns its ID.
  Future<String> createDirectRoomForCurrentPassenger(String busId) async {
    final userId = supabase.auth.currentUser!.id;
    final room = await supabase
        .from(SupabaseConstants.chatRooms)
        .insert({
          'bus_id': busId,
          'room_type': 'direct',
          'passenger_id': userId,
        })
        .select('id')
        .single();
    return room['id'] as String;
  }

  /// Loads the conductor inbox: broadcast room plus a direct room per
  /// passenger, each with its unread count resolved.
  Future<ConductorInbox> conductorInbox() async {
    final userId = supabase.auth.currentUser!.id;

    final cred = await supabase
        .from(SupabaseConstants.staffCredentials)
        .select('bus_id, buses(bus_number)')
        .eq('auth_user_id', userId)
        .single();

    final busId = cred['bus_id'] as String;
    final busNumber = (cred['buses'] as Map?)?['bus_number']?.toString() ?? '?';

    final broadcastData = await supabase
        .from(SupabaseConstants.chatRooms)
        .select('id')
        .eq('bus_id', busId)
        .eq('room_type', 'broadcast')
        .maybeSingle();

    final dmData = await supabase
        .from(SupabaseConstants.chatRooms)
        .select('id, passenger_id, passengers(name, phone, user_type)')
        .eq('bus_id', busId)
        .eq('room_type', 'direct');

    final allRoomIds = [
      if (broadcastData != null) broadcastData['id'] as String,
      ...dmData.map((r) => r['id'] as String),
    ];
    final lastByRoom = await _lastMessageByRoom(allRoomIds);

    // Per-room read timestamps (synced across devices). Tolerate a missing
    // table / RLS block by falling back to no read state.
    final readMap = <String, String>{};
    if (allRoomIds.isNotEmpty) {
      try {
        final readsData = await supabase
            .from('chat_room_reads')
            .select('chat_room_id, last_read_at')
            .eq('user_id', userId)
            .inFilter('chat_room_id', allRoomIds);
        for (final r in readsData as List) {
          readMap[r['chat_room_id'] as String] = r['last_read_at'] as String;
        }
      } catch (e) {
        // Continue with empty readMap.
      }
    }

    Future<int> unreadCount(String roomId) async {
      final since = readMap[roomId] ?? '1970-01-01T00:00:00.000Z';
      final res = await supabase
          .from(SupabaseConstants.messages)
          .select('id')
          .eq('chat_room_id', roomId)
          .neq('sender_id', userId)
          .gt('sent_at', since);
      return (res as List).length;
    }

    InboxRoom buildBase(String id, String title, bool isBroadcast,
        {String? phone, String? userType, required int unread}) {
      final last = lastByRoom[id];
      return InboxRoom(
        id: id,
        title: title,
        isBroadcast: isBroadcast,
        phone: phone,
        userType: userType,
        lastMessage: last?['content'] as String?,
        lastMessageAt: last != null
            ? DateTime.parse(last['sent_at'] as String)
            : null,
        lastIsMe: last?['sender_id'] == userId,
        unreadCount: unread,
      );
    }

    InboxRoom? broadcast;
    if (broadcastData != null) {
      final id = broadcastData['id'] as String;
      broadcast =
          buildBase(id, 'Bus $busNumber', true, unread: await unreadCount(id));
    }

    final directs = await Future.wait(dmData.map((r) async {
      final p = r['passengers'] as Map?;
      final id = r['id'] as String;
      return buildBase(
        id,
        p?['name'] as String? ?? 'Passenger',
        false,
        phone: p?['phone'] as String?,
        userType: p?['user_type'] as String?,
        unread: await unreadCount(id),
      );
    }));

    directs.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
        .compareTo(a.lastMessageAt ?? DateTime(0)));

    return ConductorInbox(busId: busId, broadcast: broadcast, directs: directs);
  }

  Future<void> markRoomRead(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    try {
      await supabase.from('chat_room_reads').upsert({
        'user_id': userId,
        'chat_room_id': roomId,
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Read tracking is best-effort; ignore failures.
    }
  }

  /// Returns the existing direct room ID for a passenger, creating one if
  /// absent.
  Future<String> openOrCreateDirectRoom({
    required String busId,
    required String passengerId,
  }) async {
    final existing = await supabase
        .from(SupabaseConstants.chatRooms)
        .select('id')
        .eq('bus_id', busId)
        .eq('room_type', 'direct')
        .eq('passenger_id', passengerId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final room = await supabase
        .from(SupabaseConstants.chatRooms)
        .insert({
          'bus_id': busId,
          'room_type': 'direct',
          'passenger_id': passengerId,
        })
        .select('id')
        .single();
    return room['id'] as String;
  }
}
