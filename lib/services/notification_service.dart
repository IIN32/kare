import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // INITIALIZE
  Future<void> initNotification() async {
    if (_isInitialized) return;

    // Initialize timezone
    try {
      tz_data.initializeTimeZones();
      // Fetch the timezone. Using var to handle potential type mismatches across versions.
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint("Device Timezone from System: $timeZoneName");
      
      // Ensure we have a string
      tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
      debugPrint("Local Location set to: ${tz.local.name}");
    } catch (e) {
      debugPrint("FAILED to set local location. Defaulting to UTC. Error: $e");
    }

    // Prepare android init settings
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Init settings
    const initSettings = InitializationSettings(android: initSettingsAndroid);

    // Final init
    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Notification Clicked: ${details.payload}");
      },
    );

    // Request permission for Android 13+ (Notifications)
    final bool? granted = await notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    debugPrint("Notification Permission Granted: $granted");
    
    // Request permission for Android 12+ (Exact Alarms)
    final bool? exactAlarmGranted = await notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    debugPrint("Exact Alarm Permission Granted: $exactAlarmGranted");

    _isInitialized = true;
  }

  // Notifications details
  NotificationDetails notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders_channel', 
        'Medication Reminders',
        channelDescription: 'Channel for medication reminder notifications',
        importance: Importance.max,
        priority: Priority.max, 
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        enableLights: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    debugPrint("Attempting to show instant notification...");
    try {
      await notificationsPlugin.show(
        id, 
        title, 
        body, 
        notificationDetails()
      );
      debugPrint("Instant notification command sent.");
    } catch (e) {
      debugPrint("Error showing notification: $e");
    }
  }

  // Schedule Notifications at a specified time
  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    debugPrint("Current Time (tz.local): $now");

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    debugPrint("Target Date: $scheduledDate");

    if (scheduledDate.isBefore(now)) {
      debugPrint("Target time passed. Scheduling for tomorrow.");
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint("Final Scheduled Date: $scheduledDate");

    try {
      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, // Added this required parameter
      );
      debugPrint("Notification successfully scheduled (AlarmClock Mode) for $scheduledDate");
    } catch (e) {
      debugPrint("Error scheduling notification: $e");
    }
  }

  // Cancel Notifications
  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }
}
