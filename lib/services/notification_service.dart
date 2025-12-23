import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/intake_log.dart';
import '../services/log_service.dart';
import '../services/local_storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      final timeZoneResult = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneResult.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Error initializing timezone: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    _isInitialized = true;
  }

  @pragma('vm:entry-point')
  static void onDidReceiveNotificationResponse(NotificationResponse response) {
    // We just want to open the app, so we don't need to do anything here.
  }

  // For reminders with actions
  NotificationDetails _reminderNotificationDetails(String urgency) {
    Color color;
    Importance importance;
    Priority priority;

    switch (urgency) {
      case 'High':
        color = Colors.red;
        importance = Importance.max;
        priority = Priority.high;
        break;
      case 'Medium':
        color = Colors.orange;
        importance = Importance.high;
        priority = Priority.high;
        break;
      default:
        color = Colors.blue;
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        break;
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders_channel',
        'Medication Reminders',
        channelDescription: 'Channel for medication reminder notifications',
        importance: importance,
        priority: priority,
        color: color,
        ticker: 'ticker',
      ),
    );
  }

  // For simple alerts without actions
  NotificationDetails _alertNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_alerts_channel', 
        'Medication Alerts',
        channelDescription: 'Channel for important alerts like refills',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
  
  // Method for simple, immediate alerts (like refills)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await notificationsPlugin.show(
      id,
      title,
      body,
      _alertNotificationDetails(),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String medicationName,
    required String scheduledTimeStr,
    required String urgency,
  }) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    final payload = '$id;;;$medicationName;;;$scheduledTimeStr;;;$body';

    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      _reminderNotificationDetails(urgency),
      payload: payload,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }
}
