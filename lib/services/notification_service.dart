import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels local reminder notifications across supported platforms.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String channelId = 'notlyfe_reminders_channel';
  static const String channelName = 'Task & Todo Reminders';
  static const String channelDescription =
      'Alerts for scheduled Notlyfe tasks and deadlines.';
  static const String _prefEnabledKey = 'notlyfe_notifications_enabled';

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isLinux);

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
    if (!enabled && _isInitialized) {
      try {
        await _notifications.cancelAll();
      } catch (_) {}
    }
  }

  Future<void> initialize() async {
    if (_isInitialized || !isSupportedPlatform) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open Notlyfe');
      const darwinSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notifications.initialize(initSettings);

      if (Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        final androidPlatform = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlatform != null) {
          await androidPlatform.createNotificationChannel(androidChannel);
          await androidPlatform.requestNotificationsPermission();
          await androidPlatform.requestExactAlarmsPermission();
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init notice: $e');
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        channelShowBadge: false,
      ),
      linux: LinuxNotificationDetails(),
    );
  }

  Future<void> scheduleTodoReminder(Todo todo) async {
    if (!isSupportedPlatform || !await isEnabled()) return;
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    final notificationId = todo.id.hashCode;

    if (todo.status || !todo.alert || todo.reminder_at == null) {
      if (todo.id != null) await cancelReminder(todo.id);
      return;
    }

    final reminderTime = todo.reminder_at!;
    if (reminderTime.isBefore(DateTime.now())) return;

    // Linux plugin does not support zonedSchedule; only mobile platforms schedule alarms.
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final taskText = E2eeService.instance.decrypt(todo.content);

    try {
      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
      await _notifications.zonedSchedule(
        notificationId,
        'Task Reminder',
        taskText.isNotEmpty ? taskText : 'You have a scheduled deadline.',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
        await _notifications.zonedSchedule(
          notificationId,
          'Task Reminder',
          taskText.isNotEmpty ? taskText : 'You have a scheduled deadline.',
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Error scheduling reminder: $e');
      }
    }
  }

  Future<void> cancelReminder(int? todoId) async {
    if (todoId == null || !_isInitialized) return;
    try {
      await _notifications.cancel(todoId.hashCode);
    } catch (e) {
      debugPrint('Error cancelling reminder: $e');
    }
  }

  Future<bool> showTestNotification() async {
    if (!isSupportedPlatform) return false;
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return false;

    try {
      await _notifications.show(
        999999,
        'Notlyfe Notification Test',
        'Local reminders are active on this device.',
        _notificationDetails(),
      );
      return true;
    } catch (e) {
      debugPrint('Error showing test notification: $e');
      return false;
    }
  }

  Future<void> syncAllReminders(List<Todo> todos) async {
    if (!isSupportedPlatform || !await isEnabled()) return;
    for (final todo in todos) {
      if (todo.alert && todo.reminder_at != null && !todo.status) {
        await scheduleTodoReminder(todo);
      }
    }
  }
}
