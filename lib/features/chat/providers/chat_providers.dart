import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/chat_message.dart';
import '../../../data/models/inbox_room.dart';
import '../../../data/repositories/chat_repository.dart';

part 'chat_providers.g.dart';

/// Live messages for a chat room (initial page + realtime inserts).
@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String roomId) =>
    ref.watch(chatRepositoryProvider).watchMessages(roomId);

/// The signed-in user's display name, used as the message sender name.
@riverpod
Future<String> currentUserDisplayName(Ref ref) =>
    ref.watch(chatRepositoryProvider).currentUserDisplayName();

/// Details about the other party in a direct chat, for the info sheet.
@riverpod
Future<Map<String, dynamic>?> chatPartnerInfo(Ref ref, String roomId) =>
    ref.watch(chatRepositoryProvider).chatPartnerInfo(roomId);

/// The passenger's inbox (broadcast + own direct room + conductor details).
@riverpod
Future<PassengerInbox> passengerInbox(Ref ref) =>
    ref.watch(chatRepositoryProvider).passengerInbox();

/// The conductor's inbox (broadcast + a direct room per passenger).
@riverpod
Future<ConductorInbox> conductorInbox(Ref ref) =>
    ref.watch(chatRepositoryProvider).conductorInbox();
