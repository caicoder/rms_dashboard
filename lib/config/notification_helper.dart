import 'package:universal_platform/universal_platform.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;
  bool _isFlutterLocalInitialized = false;

  Future<void> initialize() async {
    try {
      if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS || UniversalPlatform.isMacOS) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
            
        const DarwinInitializationSettings initializationSettingsDarwin =
            DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

        await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
        _isFlutterLocalInitialized = true;

        if (UniversalPlatform.isAndroid) {
          final androidPlugin = _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          if (androidPlugin != null) {
            await androidPlugin.requestNotificationsPermission();
          }
        }
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> showNotification(String title, String body) async {
    try {
      if (UniversalPlatform.isWindows) {
        LocalNotification notification = LocalNotification(
          title: title,
          body: body,
        );
        notification.show();
      } else if (_isFlutterLocalInitialized &&
          (UniversalPlatform.isAndroid || UniversalPlatform.isIOS || UniversalPlatform.isMacOS)) {
        const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
          'rms_alarm_channel',
          '设备报警通知',
          channelDescription: '骅羲机器人监控系统报警事件通知',
          importance: Importance.max,
          priority: Priority.high,
        );

        const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
          iOS: darwinNotificationDetails,
          macOS: darwinNotificationDetails,
        );

        await _flutterLocalNotificationsPlugin.show(
          _notificationId++,
          title,
          body,
          notificationDetails,
        );
      }
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
}
