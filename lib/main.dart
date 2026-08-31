import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'weather_background_service.dart';
import 'weather_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Local notifications + Workmanager are intentionally disabled on Web.
  // The web implementation requires a separately compiled background.dart.js
  // worker, which this project does not use.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await WeatherNotificationService.instance.initialize();
      await WeatherBackgroundService.instance.initialize();
      await WeatherBackgroundService.instance.registerPeriodicTask();
    } catch (e) {
      debugPrint('Background/notification initialization skipped: $e');
    }
  }

  runApp(const WeatherZheerApp());
}

class WeatherZheerApp extends StatelessWidget {
  const WeatherZheerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Zheer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Arial',
      ),
      home: const HomeScreen(),
    );
  }
}
