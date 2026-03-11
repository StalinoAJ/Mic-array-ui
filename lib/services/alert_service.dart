import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../state/app_state.dart';

class AlertService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  int _notifId = 0;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Request Android 13+ notification permission
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  void onSoundEvent(SoundEvent event, bool notificationsEnabled) {
    _triggerHaptic(event);
    if (notificationsEnabled) {
      _sendNotification(event);
    }
  }

  void _triggerHaptic(SoundEvent event) async {
    if (!await Vibration.hasVibrator()) return;

    if (event.label.toLowerCase().contains('siren') ||
        event.label.toLowerCase().contains('emergency')) {
      // SOS pattern
      Vibration.vibrate(
        pattern: [0, 200, 100, 200, 100, 600, 100, 200, 100, 200],
      );
    } else if (event.isHighPriority) {
      Vibration.vibrate(
        pattern: [0, 400, 200, 400],
        intensities: [0, 255, 0, 200],
      );
    } else {
      Vibration.vibrate(duration: 150, amplitude: 128);
    }
  }

  Future<void> _sendNotification(SoundEvent event) async {
    final direction = event.direction;
    final dirText = direction != null
        ? ' • ${direction.cardinalIcon} ${direction.cardinalLabel}'
        : '';

    final importance = event.isHighPriority
        ? Importance.high
        : Importance.defaultImportance;
    final priority = event.isHighPriority
        ? Priority.high
        : Priority.defaultPriority;

    final androidDetails = AndroidNotificationDetails(
      event.isHighPriority ? 'deaf_assist_alerts' : 'deaf_assist_events',
      event.isHighPriority ? 'High-Priority Alerts' : 'Sound Events',
      channelDescription: 'Detected environmental sounds',
      importance: importance,
      priority: priority,
      ticker: event.label,
      showWhen: true,
      enableVibration: false, // we handle vibration separately
      styleInformation: BigTextStyleInformation(
        '${event.emoji}  ${event.label}$dirText\nConfidence: ${event.confidencePercent}',
      ),
    );

    await _notifications.show(
      _notifId++,
      '${event.emoji} ${event.label}',
      '${event.confidencePercent} confidence$dirText',
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async => _notifications.cancelAll();
}
