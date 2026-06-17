import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'bus_proximity';
  static const _channelName = 'Bus Proximity Alerts';

  static Future<void> init() async {
    if (kIsWeb) return; // local notifications aren't supported on web
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // Request POST_NOTIFICATIONS permission on Android 13+
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return; // local notifications aren't supported on web
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription:
          'Alerts when the bus is approaching your custom pin',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
          android: androidDetails, iOS: iosDetails),
    );
  }
}
