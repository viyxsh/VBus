import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/user_repository.dart';

/// Listens for new bus join requests for a conductor's bus and shows
/// a local notification when a new request arrives.
class BusRequestNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'bus_requests';
  static const _channelName = 'Bus Requests';

  static RealtimeChannel? _channel;

  static Future<void> start() async {
    if (kIsWeb) return;
    await stop();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final busId = await UserRepository().currentUserBusId();
    if (busId == null) return;

    _channel = client
        .channel('bus_req_notif_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bus_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bus_id',
            value: busId,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            if (record['request_type'] != 'join') return;
            if (record['status'] != 'pending') return;

            final storage = FlutterSecureStorage();
            final notifEnabled =
                await storage.read(key: 'conductor_notifications');
            if (notifEnabled == 'false') return;

            await _show(
              id: record['id'].hashCode,
              title: 'New Bus Request',
              body: 'A student wants to join your bus.',
            );
          },
        )
        .subscribe();
  }

  static Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: 'Bus join request alerts',
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
