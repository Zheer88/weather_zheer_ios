import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

const String weatherBackgroundTask = 'weatherBackgroundTask';

const String _periodicTaskName = 'weather-zheer-periodic-task';

@pragma('vm:entry-point')
void weatherBackgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == weatherBackgroundTask) {
        debugPrint('Weather background task is running.');
      }

      return true;
    } catch (e) {
      debugPrint('Weather background task error: $e');
      return false;
    }
  });
}

class WeatherBackgroundService {
  WeatherBackgroundService._();

  static final WeatherBackgroundService instance = WeatherBackgroundService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Workmanager().initialize(
      weatherBackgroundCallback,
    );

    _initialized = true;
  }

  Future<void> registerPeriodicTask() async {
    await initialize();

    await Workmanager().registerPeriodicTask(
      _periodicTaskName,
      weatherBackgroundTask,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> cancelTask() async {
    await initialize();

    await Workmanager().cancelByUniqueName(
      _periodicTaskName,
    );
  }
}
