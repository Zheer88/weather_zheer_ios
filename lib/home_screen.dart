import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'location_weather_service.dart';
import 'models/weather_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<WeatherModel> _weatherData;

  bool _isAiPressed = false;
  bool _isRainPressed = false;
  bool _isLocationLoading = false;

  final MapController _mapController = MapController();

  double _latitude = 35.5558;
  double _longitude = 45.4351;

  String _cityName = 'سلێمانی';

  static const Color _background = Color(0xFFE0E5EC);
  static const Color _darkText = Color(0xFF182333);
  static const Color _secondaryText = Color(0xFF718096);
  static const Color _purple = Color(0xFF6C5CE7);

  @override
  void initState() {
    super.initState();

    _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLiveLocation();
    });
  }

  // ---------------------------------------------------------------------------
  // WEATHER / LOCATION
  // ---------------------------------------------------------------------------

  Future<WeatherModel> _loadWeatherForCoordinates(
    double latitude,
    double longitude,
  ) async {
    final json = await LocationWeatherService.getWeather(latitude, longitude);

    return WeatherModel.fromJson(json);
  }

  Future<void> _initLiveLocation() async {
    await _getCurrentLocationAndWeather(showError: false);
  }

  Future<void> _updatePositionData(Position position) async {
    if (!mounted) return;

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _isLocationLoading = true;
    });

    try {
      final detectedCity = await LocationWeatherService.getCityName(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _cityName = detectedCity;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cityName = 'لۆکەیشنی ئێستات';
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
      _isLocationLoading = false;
    });
  }

  Future<void> _getCurrentLocationAndWeather({bool showError = true}) async {
    if (_isLocationLoading) return;

    if (mounted) {
      setState(() {
        _isLocationLoading = true;
      });
    }

    try {
      final Position position =
          await LocationWeatherService.getCurrentLocation();

      await _updatePositionData(position);

      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'شوێنەکەت دۆزرایەوە: $_cityName',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLocationLoading = false;
      });

      if (showError) {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');

        if (errorMsg.contains('Origin') ||
            errorMsg.contains('secure') ||
            errorMsg.contains('permission')) {
          errorMsg =
              'بۆ GPS لە Flutter Web ـدا ئەپەکە دەبێت لە HTTPS یان localhost بێت.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LOCATION DIALOG
  // ---------------------------------------------------------------------------

  void _showLocationPickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'گۆڕینی لۆکەیشن / هەڵبژاردنی شار',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLocationLoading
                          ? null
                          : () async {
                              Navigator.pop(dialogContext);
                              await _getCurrentLocationAndWeather();
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isLocationLoading
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded, size: 20),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              _isLocationLoading
                                  ? 'لە دۆزینەوەی شوێن...'
                                  : 'دیاریکردنی لۆکەیشن بە GPS و کەشوهەوا',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'یان شارێکی خێرا هەڵبژێرە:',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _buildCityChip('سلێمانی', 35.5558, 45.4351),
                      _buildCityChip('هەولێر', 36.1901, 44.0091),
                      _buildCityChip('دهۆک', 36.8679, 42.9885),
                      _buildCityChip('هەڵەبجە', 35.1772, 45.9877),
                      _buildCityChip('کەرکووک', 35.4681, 44.3922),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'داخستن',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: _purple, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCityChip(String name, double lat, double lon) {
    return ActionChip(
      backgroundColor: _background,
      elevation: 2,
      label: Text(
        name,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _darkText,
        ),
      ),
      onPressed: () {
        Navigator.pop(context);

        setState(() {
          _latitude = lat;
          _longitude = lon;
          _cityName = name;

          _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SUN TIMES
  // ---------------------------------------------------------------------------

  Map<String, String> _getSunTimes(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);

      final int dayOfYear =
          date.difference(DateTime(date.year, 1, 1)).inDays + 1;

      final double lat = _latitude;
      final double lon = _longitude;

      final double declination =
          23.44 * sin(pi / 180 * (360 * (284 + dayOfYear) / 365));

      final double latRad = lat * pi / 180;
      final double decRad = declination * pi / 180;

      final double b = 2 * pi * (dayOfYear - 81) / 365;

      final double eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b);

      const double timeZoneOffset = 3.0;

      const double zenith = 90.833 * pi / 180;

      double cosHourAngle =
          (cos(zenith) - sin(latRad) * sin(decRad)) /
          (cos(latRad) * cos(decRad));

      cosHourAngle = cosHourAngle.clamp(-1.0, 1.0);

      final double hourAngle = acos(cosHourAngle) * 180 / pi;

      final double solarNoonLocal =
          12.0 - (lon - (timeZoneOffset * 15)) / 15.0 - (eot / 60.0);

      final double sunriseHours = solarNoonLocal - (hourAngle / 15.0);

      final double sunsetHours = solarNoonLocal + (hourAngle / 15.0);

      String formatTime(double hours) {
        while (hours < 0) {
          hours += 24;
        }

        while (hours >= 24) {
          hours -= 24;
        }

        int h = hours.floor();

        int m = ((hours - h) * 60).round();

        if (m == 60) {
          h += 1;
          m = 0;
        }

        final String period = h >= 12 ? 'PM' : 'AM';

        int displayH = h % 12;

        if (displayH == 0) {
          displayH = 12;
        }

        final String displayM = m.toString().padLeft(2, '0');

        return '$displayH:$displayM $period';
      }

      return {
        'sunrise': formatTime(sunriseHours),
        'sunset': formatTime(sunsetHours),
      };
    } catch (_) {
      return {'sunrise': '05:30 AM', 'sunset': '07:15 PM'};
    }
  }

  // ---------------------------------------------------------------------------
  // WEATHER HELPERS
  // ---------------------------------------------------------------------------

  IconData _getWeatherIcon(int code, int isDay) {
    if (code == 0) {
      return isDay == 1 ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }

    if (code == 1) {
      return isDay == 1 ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
    }

    if (code == 2) {
      return Icons.wb_cloudy_rounded;
    }

    if (code == 3) {
      return Icons.cloud_rounded;
    }

    if (code >= 45 && code <= 48) {
      return Icons.foggy;
    }

    if (code >= 51 && code <= 57) {
      return Icons.grain_rounded;
    }

    if (code >= 61 && code <= 67) {
      return Icons.umbrella_rounded;
    }

    if (code >= 71 && code <= 77) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 80 && code <= 82) {
      return Icons.umbrella_rounded;
    }

    if (code == 85 || code == 86) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 95 && code <= 99) {
      return Icons.thunderstorm_rounded;
    }

    return isDay == 1 ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  }

  Color _getWeatherIconColor(int code, int isDay) {
    if (code == 0) {
      return isDay == 1 ? Colors.orangeAccent : Colors.indigoAccent;
    }

    if (code == 1 || code == 2 || code == 3) {
      return isDay == 1 ? Colors.blueGrey : Colors.indigo;
    }

    if (code >= 45 && code <= 48) {
      return Colors.grey;
    }

    if (code >= 51 && code <= 67) {
      return Colors.blueAccent;
    }

    if (code >= 71 && code <= 77) {
      return Colors.lightBlueAccent;
    }

    if (code >= 80 && code <= 82) {
      return Colors.blueAccent;
    }

    if (code == 85 || code == 86) {
      return Colors.lightBlueAccent;
    }

    if (code >= 95 && code <= 99) {
      return Colors.deepPurpleAccent;
    }

    return isDay == 1 ? Colors.orangeAccent : Colors.indigoAccent;
  }

  String _getWeatherDescription(int code) {
    if (code == 0) {
      return 'ساماڵ و ڕووناک';
    }

    if (code == 1) {
      return 'کەمێک هەور';
    }

    if (code == 2) {
      return 'نیمچە هەور';
    }

    if (code == 3) {
      return 'هەوراوی';
    }

    if (code >= 45 && code <= 48) {
      return 'تەمومژاوی';
    }

    if (code >= 51 && code <= 57) {
      return 'بارانی سووک';
    }

    if (code >= 61 && code <= 67) {
      return 'باراناوی';
    }

    if (code >= 71 && code <= 77) {
      return 'بەفربارین';
    }

    if (code >= 80 && code <= 82) {
      return 'ڕەگبار';
    }

    if (code == 85 || code == 86) {
      return 'بەفری ڕەگبار';
    }

    if (code >= 95 && code <= 99) {
      return 'هەورەبروسکە و زریان';
    }

    return 'کەشوهەوای ئاسایی';
  }

  String _getKurdishDayName(String dateStr) {
    final DateTime date = DateTime.parse(dateStr);

    const List<String> kurdishDays = [
      'دووشەممە',
      'سێشەممە',
      'چوارشەممە',
      'پێنجشەممە',
      'هەینی',
      'شەممە',
      'یەکشەممە',
    ];

    return kurdishDays[date.weekday - 1];
  }

  // ---------------------------------------------------------------------------
  // REPORTS
  // ---------------------------------------------------------------------------

  void _showDetailedAIReportDialog(BuildContext context, WeatherModel data) {
    String report = '';

    final int totalDays = min(6, data.times.length);

    for (int i = 0; i < totalDays; i++) {
      final String dayName = _getKurdishDayName(data.times[i]);

      final String date = data.times[i];

      final dynamic maxT = data.maxTemps[i];

      final dynamic minT = data.minTemps[i];

      final int weatherCode = data.weatherCodes.length > i
          ? data.weatherCodes[i]
          : 0;

      final double tempSun = maxT is num ? maxT.toDouble() : 35.0;

      final double tempShadow = tempSun - 3.5;

      report +=
          '📅 ڕۆژ: $dayName ($date)\n'
          '🌤️ دۆخی کەش: '
          '${_getWeatherDescription(weatherCode)}\n'
          '☀️ پلەی گەرمی لە بەرخۆر: '
          '${tempSun.toStringAsFixed(1)} °C\n'
          '🌳 پلەی گەرمی لە سێبەر: '
          '${tempShadow.toStringAsFixed(1)} °C\n'
          '❄️ نزمترین پلەی گەرمی: '
          '$minT °C\n\n'
          '-----------------------------\n\n';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.psychology_rounded, color: _purple),
                SizedBox(width: 10),
                Text(
                  'ڕاپۆرتی ٦ ڕۆژی',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                report,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: _darkText,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'داخستن',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: _purple, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRainReportDialog(BuildContext context, WeatherModel data) {
    String rainReport = '';

    final int totalDays = min(6, data.times.length);

    for (int i = 0; i < totalDays; i++) {
      final String dayName = _getKurdishDayName(data.times[i]);

      final String date = data.times[i];

      final dynamic rainAmount =
          data.precipitationSums.length > i && data.precipitationSums[i] != null
          ? data.precipitationSums[i]
          : 0.0;

      final dynamic rainProb =
          data.precipitationProbabilities.length > i &&
              data.precipitationProbabilities[i] != null
          ? data.precipitationProbabilities[i]
          : 0;

      rainReport +=
          '📅 ڕۆژ: $dayName ($date)\n'
          '🌧️ بڕی بارانبارین: '
          '$rainAmount ملم\n'
          '📊 ئەگەری بارین: '
          '$rainProb٪\n\n'
          '-----------------------------\n\n';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.water_drop_rounded, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text(
                  'ڕاپۆرتی باران بۆ ٦ ڕۆژ',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                rainReport,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: _darkText,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'داخستن',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDayDetailDialog(
    BuildContext context,
    String date,
    dynamic maxT,
    dynamic minT,
    int weatherCode,
  ) {
    final String dayName = _getKurdishDayName(date);

    final double tempMax = maxT is num ? maxT.toDouble() : 35.0;

    final double tempMin = minT is num ? minT.toDouble() : 20.0;

    final double tempShadow = tempMax - 3.5;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'کەشوهەوای $dayName',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'بەروار: $date',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: _getWeatherIconColor(
                        weatherCode,
                        1,
                      ).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getWeatherIcon(weatherCode, 1),
                      color: _getWeatherIconColor(weatherCode, 1),
                      size: 46,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    _getWeatherDescription(weatherCode),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  Icons.thermostat_rounded,
                  Colors.redAccent,
                  'بەرز',
                  '${tempMax.toStringAsFixed(1)} °C',
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.ac_unit_rounded,
                  Colors.blueAccent,
                  'نزم',
                  '${tempMin.toStringAsFixed(1)} °C',
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.wb_sunny_rounded,
                  Colors.orange,
                  'لە بەرخۆر',
                  '${tempMax.toStringAsFixed(1)} °C',
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.park_rounded,
                  Colors.green,
                  'لە سێبەر',
                  '${tempShadow.toStringAsFixed(1)} °C',
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.nightlight_round,
                  Colors.indigoAccent,
                  'شەو',
                  '${tempMin.toStringAsFixed(1)} °C',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'باشە',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: _purple, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String title,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            '$title: $value',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Icon(icon, color: color, size: 23),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: FutureBuilder<WeatherModel>(
            future: _weatherData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _purple),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Text(
                      'هەڵە: ${snapshot.error}',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: Colors.red, fontSize: 15),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Text(
                    'هیچ زانیارییەکی کەشوهەوا بەردەست نییە.',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                );
              }

              final WeatherModel data = snapshot.data!;

              final double todayMax =
                  data.maxTemps.isNotEmpty && data.maxTemps[0] is num
                  ? (data.maxTemps[0] as num).toDouble()
                  : data.currentTemp.toDouble();

              final double todayMin =
                  data.minTemps.isNotEmpty && data.minTemps[0] is num
                  ? (data.minTemps[0] as num).toDouble()
                  : data.currentTemp.toDouble();

              final double todayRainSum =
                  data.precipitationSums.isNotEmpty &&
                      data.precipitationSums[0] is num
                  ? (data.precipitationSums[0] as num).toDouble()
                  : 0.0;

              final String todayDate = data.times.isNotEmpty
                  ? data.times[0]
                  : DateTime.now().toIso8601String().split('T').first;

              final Map<String, String> sunTimes = _getSunTimes(todayDate);

              final int forecastDays = min(
                6,
                min(
                  data.times.length,
                  min(data.maxTemps.length, data.minTemps.length),
                ),
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool wideScreen = constraints.maxWidth >= 900;

                  final double maxContentWidth = wideScreen
                      ? 1120
                      : double.infinity;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: wideScreen ? 24 : 16,
                          vertical: 14,
                        ),
                        children: [
                          // HEADER
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _showLocationPickerDialog(context),
                                child: _buildNeuContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  radius: 14,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.redAccent,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _cityName,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: _darkText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '  ',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: wideScreen ? 10 : 9,
                                    fontWeight: FontWeight.w800,
                                    color: _secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // SUMMARY CARDS
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.thermostat_rounded,
                                  iconColor: Colors.redAccent,
                                  title: 'بەرزترین',
                                  value: '${todayMax.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.ac_unit_rounded,
                                  iconColor: Colors.blueAccent,
                                  title: 'نزمترین',
                                  value: '${todayMin.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.nightlight_round,
                                  iconColor: Colors.indigoAccent,
                                  title: 'شەوانی',
                                  value: '${todayMin.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // CURRENT WEATHER
                          _buildCurrentWeatherCard(
                            data: data,
                            todayMax: todayMax,
                            todayMin: todayMin,
                            wideScreen: wideScreen,
                          ),

                          const SizedBox(height: 10),

                          // SUN
                          _buildSunCard(
                            sunTimes: sunTimes,
                            wideScreen: wideScreen,
                          ),

                          const SizedBox(height: 12),

                          // MAP
                          _buildMapCard(),

                          const SizedBox(height: 14),

                          // REPORT BUTTONS
                          Row(
                            children: [
                              Expanded(
                                child: _buildReportButton(
                                  icon: Icons.cloud_rounded,
                                  title: 'ڕاپۆرتی گشتی',
                                  color: _purple,
                                  pressed: _isAiPressed,
                                  onTapDown: (_) {
                                    setState(() {
                                      _isAiPressed = true;
                                    });
                                  },
                                  onTapUp: (_) {
                                    setState(() {
                                      _isAiPressed = false;
                                    });
                                  },
                                  onTapCancel: () {
                                    setState(() {
                                      _isAiPressed = false;
                                    });
                                  },
                                  onTap: () => _showDetailedAIReportDialog(
                                    context,
                                    data,
                                  ),
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildReportButton(
                                  icon: Icons.water_drop_rounded,
                                  title: 'ڕاپۆرتی باران',
                                  color: Colors.blueAccent,
                                  pressed: _isRainPressed,
                                  pressedColor: const Color(0xFFD1D9E6),
                                  onTapDown: (_) {
                                    setState(() {
                                      _isRainPressed = true;
                                    });
                                  },
                                  onTapUp: (_) {
                                    setState(() {
                                      _isRainPressed = false;
                                    });
                                  },
                                  onTapCancel: () {
                                    setState(() {
                                      _isRainPressed = false;
                                    });
                                  },
                                  onTap: () =>
                                      _showRainReportDialog(context, data),
                                  wideScreen: wideScreen,
                                  subtitle: todayRainSum > 0
                                      ? 'بارین هەیە'
                                      : 'بارین نییە',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // 6 DAY TITLE
                          const Text(
                            ' بۆ بینینی پێشبینی ڕۆژانی داهاتوو کلیک بکە لەسەر ڕۆژانە  ',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _darkText,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 6 DAY FORECAST
                          _buildForecastGrid(
                            data: data,
                            forecastDays: forecastDays,
                            wideScreen: wideScreen,
                          ),

                          const SizedBox(height: 18),

                          // FOOTER
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFC7D0DF),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                'پڕۆگرامساز: طـە مەستەکانی',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _secondaryText,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFC7D0DF),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARD
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool wideScreen,
  }) {
    return _buildNeuContainer(
      radius: 15,
      padding: EdgeInsets.symmetric(
        vertical: wideScreen ? 9 : 8,
        horizontal: 5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: wideScreen ? 23 : 21),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: wideScreen ? 11 : 10,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: wideScreen ? 19 : 17,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CURRENT WEATHER CARD
  // ---------------------------------------------------------------------------

  Widget _buildCurrentWeatherCard({
    required WeatherModel data,
    required double todayMax,
    required double todayMin,
    required bool wideScreen,
  }) {
    final int code = data.currentWeatherCode;

    return _buildNeuContainer(
      radius: 17,
      padding: EdgeInsets.symmetric(
        horizontal: wideScreen ? 20 : 13,
        vertical: wideScreen ? 14 : 11,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: wideScreen ? 65 : 55,
                  height: wideScreen ? 65 : 55,
                  decoration: BoxDecoration(
                    color: _getWeatherIconColor(
                      code,
                      data.isDay,
                    ).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getWeatherIcon(code, data.isDay),
                    size: wideScreen ? 42 : 36,
                    color: _getWeatherIconColor(code, data.isDay),
                  ),
                ),
                const SizedBox(width: 11),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${data.currentTemp.round()}°C',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: wideScreen ? 36 : 30,
                          fontWeight: FontWeight.w900,
                          color: _darkText,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _getWeatherDescription(code),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: wideScreen ? 14 : 12,
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 1,
            height: wideScreen ? 88 : 70,
            color: const Color(0xFFC7D0DF),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentMiniRow(
                  Icons.thermostat_rounded,
                  Colors.redAccent,
                  'بەرزترین',
                  '${todayMax.round()}°',
                  wideScreen,
                ),
                const SizedBox(height: 7),
                _buildCurrentMiniRow(
                  Icons.ac_unit_rounded,
                  Colors.blueAccent,
                  'نزمترین',
                  '${todayMin.round()}°',
                  wideScreen,
                ),
                const SizedBox(height: 7),
                _buildCurrentMiniRow(
                  Icons.nightlight_round,
                  Colors.indigoAccent,
                  'شەوانی',
                  '${todayMin.round()}°',
                  wideScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMiniRow(
    IconData icon,
    Color color,
    String title,
    String value,
    bool wideScreen,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: wideScreen ? 20 : 17),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: wideScreen ? 12 : 10,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: wideScreen ? 16 : 13,
            fontWeight: FontWeight.w900,
            color: _darkText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUN CARD
  // ---------------------------------------------------------------------------

  Widget _buildSunCard({
    required Map<String, String> sunTimes,
    required bool wideScreen,
  }) {
    return _buildNeuContainer(
      radius: 18,
      padding: EdgeInsets.symmetric(
        horizontal: wideScreen ? 28 : 16,
        vertical: wideScreen ? 13 : 11,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSunItem(
              icon: Icons.wb_sunny_rounded,
              color: Colors.orange,
              title: 'خۆرهەڵاتن',
              time: sunTimes['sunrise']!,
              wideScreen: wideScreen,
            ),
          ),
          Container(
            width: 1,
            height: wideScreen ? 55 : 45,
            color: const Color(0xFFC7D0DF),
          ),
          Expanded(
            child: _buildSunItem(
              icon: Icons.nights_stay_rounded,
              color: Colors.indigo,
              title: 'خۆرئاوابوون',
              time: sunTimes['sunset']!,
              wideScreen: wideScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunItem({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    required bool wideScreen,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: wideScreen ? 29 : 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              title,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: wideScreen ? 13 : 10,
                fontWeight: FontWeight.w800,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: wideScreen ? 17 : 13,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MAP
  // ---------------------------------------------------------------------------

  Widget _buildMapCard() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFA3B1C6),
            offset: Offset(5, 5),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: FlutterMap(
          key: ValueKey('$_latitude-$_longitude'),
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_latitude, _longitude),
            initialZoom: 13.8,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.example.weather_zheer',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_latitude, _longitude),
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.redAccent,
                    size: 37,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildReportButton({
    required IconData icon,
    required String title,
    required Color color,
    required bool pressed,
    required VoidCallback onTap,
    required void Function(TapDownDetails) onTapDown,
    required void Function(TapUpDetails) onTapUp,
    required VoidCallback onTapCancel,
    required bool wideScreen,
    String? subtitle,
    Color? pressedColor,
  }) {
    return GestureDetector(
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.symmetric(
          vertical: wideScreen ? 13 : 11,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: pressed
              ? (pressedColor ?? const Color(0xFFD1D9E6))
              : _background,
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFA3B1C6),
              offset: Offset(4, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: wideScreen ? 26 : 23),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: wideScreen ? 17 : 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: wideScreen ? 9 : 8,
                        fontWeight: FontWeight.w600,
                        color: _secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORECAST GRID
  // ---------------------------------------------------------------------------

  Widget _buildForecastGrid({
    required WeatherModel data,
    required int forecastDays,
    required bool wideScreen,
  }) {
    if (forecastDays == 0) {
      return _buildNeuContainer(
        child: const Text(
          'پێشبینی ڕۆژانە بەردەست نییە.',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;

        if (constraints.maxWidth >= 1000) {
          columns = 3;
        } else if (constraints.maxWidth >= 650) {
          columns = 3;
        } else {
          columns = 2;
        }

        const double spacing = 10;

        final double cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(forecastDays, (i) {
            final String date = data.times[i];

            final String dayName = _getKurdishDayName(date);

            final double maxTemp = data.maxTemps[i] is num
                ? (data.maxTemps[i] as num).toDouble()
                : 0.0;

            final double minTemp = data.minTemps[i] is num
                ? (data.minTemps[i] as num).toDouble()
                : 0.0;

            final int code = data.weatherCodes.length > i
                ? data.weatherCodes[i]
                : 0;

            final double rainProbability =
                data.precipitationProbabilities.length > i &&
                    data.precipitationProbabilities[i] is num
                ? (data.precipitationProbabilities[i] as num).toDouble()
                : 0.0;

            return SizedBox(
              width: cardWidth,
              child: GestureDetector(
                onTap: () =>
                    _showDayDetailDialog(context, date, maxTemp, minTemp, code),
                child: _buildForecastCard(
                  dayName: dayName,
                  date: date,
                  maxTemp: maxTemp,
                  minTemp: minTemp,
                  code: code,
                  rainProbability: rainProbability,
                  wideScreen: wideScreen,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FORECAST CARD - UPDATED
  // ---------------------------------------------------------------------------

  Widget _buildForecastCard({
    required String dayName,
    required String date,
    required double maxTemp,
    required double minTemp,
    required int code,
    required double rainProbability,
    required bool wideScreen,
  }) {
    final Color dayIconColor = _getWeatherIconColor(code, 1);

    final Color nightIconColor = _getWeatherIconColor(code, 0);

    // WeatherModel ـی ئێستا داتای تایبەتی
    // پلەی شەوی نییە، بۆیە minTemp بەکاردێت.
    final double nightTemp = minTemp;

    return _buildNeuContainer(
      radius: 17,
      padding: EdgeInsets.symmetric(
        horizontal: wideScreen ? 13 : 10,
        vertical: wideScreen ? 12 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------------------------------------------------------
          // DAY NAME - CENTERED / BIG / BOLD
          // ---------------------------------------------------------------
          Center(
            child: Text(
              dayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wideScreen ? 17 : 16,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
          ),

          const SizedBox(height: 3),

          // ---------------------------------------------------------------
          // DATE - CENTERED / BIGGER / BOLD
          // ---------------------------------------------------------------
          Center(
            child: Text(
              date,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wideScreen ? 13 : 12,
                fontWeight: FontWeight.w800,
                color: _secondaryText,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // DAY + NIGHT ICONS
          // ---------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildForecastTimeIcon(
                icon: _getWeatherIcon(code, 1),
                color: dayIconColor,
                label: 'ڕۆژ',
                temperature: '${maxTemp.round()}°',
                wideScreen: wideScreen,
              ),
              Container(
                width: 1,
                height: wideScreen ? 60 : 53,
                color: const Color(0xFFC7D0DF),
              ),
              _buildForecastTimeIcon(
                icon: _getWeatherIcon(code, 0),
                color: nightIconColor,
                label: 'شەو',
                temperature: '${nightTemp.round()}°',
                wideScreen: wideScreen,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // WEATHER DESCRIPTION - CENTERED / BIG / BOLD
          // ---------------------------------------------------------------
          Center(
            child: Text(
              _getWeatherDescription(code),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wideScreen ? 14 : 13,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // MAX / MIN
          // ---------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFD9DFE9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.redAccent,
                          size: 17,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${maxTemp.round()}°',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: wideScreen ? 16 : 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'بەرزترین پلەی گەرمی',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: wideScreen ? 10 : 9,
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.blueAccent,
                          size: 17,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${minTemp.round()}°',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: wideScreen ? 15 : 13,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF30458A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'نزمترین پلەی گەرمی',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: wideScreen ? 10 : 9,
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 7),

          // ---------------------------------------------------------------
          // RAIN
          // ---------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${rainProbability.round()}٪',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: wideScreen ? 12 : 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.water_drop_rounded,
                color: Colors.blueAccent,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORECAST DAY/NIGHT ICON
  // ---------------------------------------------------------------------------

  Widget _buildForecastTimeIcon({
    required IconData icon,
    required Color color,
    required String label,
    required String temperature,
    required bool wideScreen,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: wideScreen ? 48 : 43,
          height: wideScreen ? 48 : 43,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: wideScreen ? 28 : 25),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: wideScreen ? 9 : 8,
            fontWeight: FontWeight.w800,
            color: _secondaryText,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          temperature,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: wideScreen ? 14 : 13,
            fontWeight: FontWeight.w900,
            color: _darkText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NEUMORPHIC CONTAINER
  // ---------------------------------------------------------------------------

  Widget _buildNeuContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double radius = 16,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFA3B1C6),
            offset: Offset(5, 5),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}
