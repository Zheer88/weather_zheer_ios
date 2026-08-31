import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class WeatherNotificationService {
  WeatherNotificationService._();

  static final WeatherNotificationService instance =
      WeatherNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'weather_alerts';
  static const String _channelName = 'ئاگادارییەکانی کەشوهەوا';

  static const int rainNotificationId = 1001;
  static const int hotNotificationId = 1002;
  static const int coldNotificationId = 1003;

  bool _initialized = false;

  // ------------------------------------------------------------
  // INITIALIZE
  // ------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();

      try {
        tz.setLocalLocation(
          tz.getLocation(timezoneInfo.identifier),
        );
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'ئاگادارییە گرنگەکانی کەشوهەوا',
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  // ------------------------------------------------------------
  // PERMISSIONS
  // ------------------------------------------------------------

  Future<bool> requestPermissions() async {
    await initialize();

    bool? androidGranted;

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      androidGranted = await android.requestNotificationsPermission();
    }

    bool? iosGranted;

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      iosGranted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return androidGranted ?? iosGranted ?? true;
  }

  // ------------------------------------------------------------
  // RAIN
  // ------------------------------------------------------------

  Future<void> showRainAlert({
    String? locationName,
  }) async {
    final location = _cleanLocation(locationName);

    await _show(
      id: rainNotificationId,
      title: '🌧️ ئاگاداریی باران',
      body: location.isEmpty
          ? 'لە ئێستادا باران دەبارێت.'
          : 'لە ئێستادا لە $location باران دەبارێت.',
    );
  }

  Future<void> scheduleRainAlert({
    required DateTime dateTime,
    String? locationName,
  }) async {
    if (dateTime.isBefore(DateTime.now())) {
      return;
    }

    final location = _cleanLocation(locationName);

    await _schedule(
      id: rainNotificationId,
      dateTime: dateTime,
      title: '🌧️ ئاگاداریی باران',
      body: location.isEmpty
          ? 'لە ئێستادا باران دەبارێت.'
          : 'لە ئێستادا لە $location باران دەبارێت.',
    );
  }

  // ------------------------------------------------------------
  // HOT - 39°C
  // ------------------------------------------------------------

  Future<void> showHotAlert({
    required double temperature,
    String? locationName,
  }) async {
    final temp = temperature.round();
    final location = _cleanLocation(locationName);

    await _show(
      id: hotNotificationId,
      title: '☀️ ئاگاداریی گەرما',
      body: location.isEmpty
          ? 'پلەی گەرمی گەیشتە $temp°C. ئاگاداری لە گەرمای زۆر بە.'
          : 'پلەی گەرمی لە $location گەیشتە $temp°C. ئاگاداری لە گەرمای زۆر بە.',
    );
  }

  Future<void> scheduleHotAlert({
    required DateTime dateTime,
    required double temperature,
    String? locationName,
  }) async {
    if (dateTime.isBefore(DateTime.now())) {
      return;
    }

    final temp = temperature.round();
    final location = _cleanLocation(locationName);

    await _schedule(
      id: hotNotificationId,
      dateTime: dateTime,
      title: '☀️ ئاگاداریی گەرما',
      body: location.isEmpty
          ? 'پلەی گەرمی دەگاتە نزیکەی $temp°C. ئاگاداری لە گەرمای زۆر بە.'
          : 'پلەی گەرمی لە $location دەگاتە نزیکەی $temp°C. ئاگاداری لە گەرمای زۆر بە.',
    );
  }

  // ------------------------------------------------------------
  // COLD - 15°C
  // ------------------------------------------------------------

  Future<void> showColdAlert({
    required double temperature,
    String? locationName,
  }) async {
    final temp = temperature.round();
    final location = _cleanLocation(locationName);

    await _show(
      id: coldNotificationId,
      title: '❄️ ئاگاداریی ساردی',
      body: location.isEmpty
          ? 'پلەی گەرمی گەیشتە $temp°C. خۆت لە ساردی بپارێزە.'
          : 'پلەی گەرمی لە $location گەیشتە $temp°C. خۆت لە ساردی بپارێزە.',
    );
  }

  Future<void> scheduleColdAlert({
    required DateTime dateTime,
    required double temperature,
    String? locationName,
  }) async {
    if (dateTime.isBefore(DateTime.now())) {
      return;
    }

    final temp = temperature.round();
    final location = _cleanLocation(locationName);

    await _schedule(
      id: coldNotificationId,
      dateTime: dateTime,
      title: '❄️ ئاگاداریی ساردی',
      body: location.isEmpty
          ? 'پلەی گەرمی دەگاتە نزیکەی $temp°C. خۆت لە ساردی بپارێزە.'
          : 'پلەی گەرمی لە $location دەگاتە نزیکەی $temp°C. خۆت لە ساردی بپارێزە.',
    );
  }

  // ------------------------------------------------------------
  // SHOW IMMEDIATELY
  // ------------------------------------------------------------

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'ئاگادارییە گرنگەکانی کەشوهەوا',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  // ------------------------------------------------------------
  // SCHEDULE
  // ------------------------------------------------------------

  Future<void> _schedule({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'ئاگادارییە گرنگەکانی کەشوهەوا',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(
        dateTime,
        tz.local,
      ),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // ------------------------------------------------------------
  // CANCEL
  // ------------------------------------------------------------

  Future<void> cancelAll() async {
    await initialize();
    await _notifications.cancelAll();
  }

  Future<void> cancelRain() async {
    await initialize();
    await _notifications.cancel(
      id: rainNotificationId,
    );
  }

  Future<void> cancelHot() async {
    await initialize();
    await _notifications.cancel(
      id: hotNotificationId,
    );
  }

  Future<void> cancelCold() async {
    await initialize();
    await _notifications.cancel(
      id: coldNotificationId,
    );
  }
  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  String _cleanLocation(String? locationName) {
    final value = locationName?.trim() ?? '';

    if (value.isEmpty) {
      return '';
    }

    return value;
  }

  void _onNotificationResponse(
    NotificationResponse response,
  ) {
    // دواتر دەتوانین navigation زیاد بکەین.
  }
}
