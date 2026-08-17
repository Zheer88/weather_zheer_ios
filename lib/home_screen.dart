import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'location_weather_service.dart';
import 'earthquake_service.dart';
import 'models/earthquake_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart'; // پاکێجی گراف

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late Future<WeatherModel> _weatherData;
  late Future<List<EarthquakeModel>> _earthquakeData;

  bool _isLocationLoading = false;

  // گۆڕاوی ڕاگرتنی دۆخی تاریک (Dark Mode)
  bool _isDarkMode = false;

  final MapController _mapController = MapController();

  double _latitude = 35.5558;
  double _longitude = 45.4351;
  double _elevation = 850.0; // گۆڕاوی نوێ بۆ بەرزی زەوی لە ئاستی ڕووی دەریا

  String _cityName = 'سلێمانی';

  // dynamic Color getters based on current mode
  Color get _background =>
      _isDarkMode ? const Color(0xFF1E242D) : const Color(0xFFE0E5EC);
  Color get _darkText =>
      _isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF182333);
  Color get _secondaryText =>
      _isDarkMode ? const Color(0xFFA0AEC0) : const Color(0xFF718096);
  Color get _purple =>
      _isDarkMode ? const Color(0xFF9F7AEA) : const Color(0xFF6C5CE7);

  // Dynamic Shadows for Neumorphism in both light and dark mode
  List<BoxShadow> get _neuShadows => [
    BoxShadow(
      color: _isDarkMode
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.85),
      offset: const Offset(-5, -5),
      blurRadius: 10,
    ),
    BoxShadow(
      color: _isDarkMode
          ? Colors.black.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.12),
      offset: const Offset(5, 5),
      blurRadius: 10,
    ),
  ];

  List<BoxShadow> get _neuShadowsSmall => [
    BoxShadow(
      color: _isDarkMode
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.9),
      offset: const Offset(-3, -3),
      blurRadius: 6,
    ),
    BoxShadow(
      color: _isDarkMode
          ? Colors.black.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.1),
      offset: const Offset(3, 3),
      blurRadius: 6,
    ),
  ];

  // Animation controller for the interactive touch indicator icon
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  // گۆڕاوی نوێ بۆ جووڵەی سەرنجڕاکێشی ئایکۆنی لۆکەیشن
  late Animation<double> _locationBounceAnimation;

  // گۆڕاوێک بۆ بەدواداچوونی جووڵەی ئامێر بە بەردەوامی
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastFetchedPosition; // بۆ کۆنترۆڵکردنی نوێکردنەوەی کەشوهەوا

  // گۆڕاوێک بۆ هەڵگرتنی ناوەکان تا خێراتر بێت و سێرڤەر بلۆکمان نەکات
  final Map<String, String> _placeNameCache = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
    _earthquakeData = EarthquakeService.getRecentEarthquakes();
    _fetchElevation(
      _latitude,
      _longitude,
    ); // هێنانی بەرزی سەرەتایی (تەنها وەک یەدەگ)

    // نوێکردنەوەی خۆکارانەی داتاکان هەموو ٦ کاتژمێر جارێک
    _refreshTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      if (mounted) {
        setState(() {
          _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // دروستکردنی جووڵەی نەرم بۆ ئایکۆنی لۆکەیشن
    _locationBounceAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLiveLocation();
      _startLocationStream(); // دەستپێکردنی بەدواداچونی جووڵەی ئامێر بە هەستیاری زۆرەوە
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LIVE LOCATION STREAM (چاودێریکردنی بەردەوامی جووڵەی ئامێر بە هەستیارییەکی جیوەیی)
  // ---------------------------------------------------------------------------
  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // بەرزترین ئاستی وردی GPS
      distanceFilter:
          0, // سفر کراوە بۆ ئەوەی بچووکترین جووڵەی مۆبایلەکە هەست پێبکات
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateLiveElevationAndLocation(position);
          },
        );
  }

  void _updateLiveElevationAndLocation(Position position) {
    if (!mounted) return;

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;

      // ڕاستەوخۆ وەرگرتنی بەرزی لە هەستەوەرەکانی مۆبایلەکەوە بەبێ چاوەڕێکردنی ئینتەرنێت
      if (position.altitude != 0.0) {
        _elevation = position.altitude;
      }
    });

    // بۆ ئەوەی لەگەڵ هەر بەرزکردنەوەیەکی دەستتدا سێرڤەری کەشوهەوا لۆد نەکرێت و بلۆک نەبیت:
    // تەنها کاتێک کەشوهەوا نوێ دەکەینەوە کە زیاتر لە ٥ کیلۆمەتر جووڵابیت.
    if (_lastFetchedPosition == null ||
        Geolocator.distanceBetween(
              _lastFetchedPosition!.latitude,
              _lastFetchedPosition!.longitude,
              position.latitude,
              position.longitude,
            ) >
            5000) {
      _lastFetchedPosition = position;
      _fetchCityAndWeather(position);
    }
  }

  Future<void> _fetchCityAndWeather(Position position) async {
    if (!mounted) return;

    setState(() {
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

  // ---------------------------------------------------------------------------
  // FETCH ELEVATION METHOD (وەک یەدەگ بەکاردێت کاتێک لە نەخشە شارێک هەڵدەبژێریت)
  // ---------------------------------------------------------------------------
  Future<void> _fetchElevation(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/elevation?latitude=$lat&longitude=$lon',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elevation'] != null) {
          final List elevations = data['elevation'];
          if (elevations.isNotEmpty) {
            if (mounted) {
              setState(() {
                _elevation = (elevations[0] as num).toDouble();
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // MAP LOCATION NAME GETTER (REVERSE GEOCODING)
  // ---------------------------------------------------------------------------

  String _translateEarthquakePlace(String englishPlace) {
    String text = englishPlace;
    text = text.replaceAll(' NNE ', ' باکوور بۆ باکووری ڕۆژهەڵات ');
    text = text.replaceAll(' ENE ', ' ڕۆژهەڵات بۆ باکووری ڕۆژهەڵات ');
    text = text.replaceAll(' ESE ', ' ڕۆژهەڵات بۆ باشووری ڕۆژهەڵات ');
    text = text.replaceAll(' SSE ', ' باشوور بۆ باشووری ڕۆژهەڵات ');
    text = text.replaceAll(' SSW ', ' باشوور بۆ باشووری ڕۆژئاوا ');
    text = text.replaceAll(' WSW ', ' ڕۆژئاوا بۆ باشووری ڕۆژئاوا ');
    text = text.replaceAll(' WNW ', ' ڕۆژئاوا بۆ باکووری ڕۆژئاوا ');
    text = text.replaceAll(' NNW ', ' باکوور بۆ باکووری ڕۆژئاوا ');
    text = text.replaceAll(' NE ', ' باکووری ڕۆژهەڵات ');
    text = text.replaceAll(' SE ', ' باشووری ڕۆژهەڵات ');
    text = text.replaceAll(' SW ', ' باشووری ڕۆژئاوا ');
    text = text.replaceAll(' NW ', ' باکووری ڕۆژئاوا ');
    text = text.replaceAll(' N ', ' باکووری ');
    text = text.replaceAll(' S ', ' باشووری ');
    text = text.replaceAll(' E ', ' ڕۆژهەڵاتی ');
    text = text.replaceAll(' W ', ' ڕۆژئاوای ');
    text = text.replaceAll('km', 'کم');
    text = text.replaceAll(' of ', ' لە ');
    text = text.replaceAll('Iraq', 'عێراق');
    text = text.replaceAll('Kirkuk', 'کەرکووک');
    text = text.replaceAll('Sulaymaniyah', 'سلێمانی');
    text = text.replaceAll('Halabja', 'هەڵەبجە');
    text = text.replaceAll('Erbil', 'هەولێر');
    text = text.replaceAll('Duhok', 'دهۆک');
    text = text.replaceAll('Kalar', 'کەلار');
    text = text.replaceAll('Chamchamal', 'چەمچەماڵ');
    text = text.replaceAll('Kifri', 'کفری');
    text = text.replaceAll('Ranya', 'ڕانیە');
    text = text.replaceAll('Said Sadiq', 'سیدصادق');
    text = text.replaceAll('Dukan', 'دوکان');
    text = text.replaceAll('Zakho', 'زاخۆ');
    text = text.replaceAll('Mosul', 'موسڵ');
    text = text.replaceAll('Baghdad', 'بەغدا');
    text = text.replaceAll('Basra', 'بەسرە');
    return text;
  }

  Future<String> _getRealMapLocationName(
    double lat,
    double lon,
    String fallbackName,
  ) async {
    final cacheKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    if (_placeNameCache.containsKey(cacheKey)) {
      return _placeNameCache[cacheKey]!;
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&accept-language=ckb,ku,ar',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.zheer.weatherapp'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['address'] != null) {
          final addr = data['address'];

          String place =
              addr['village'] ??
              addr['town'] ??
              addr['city'] ??
              addr['county'] ??
              addr['state'] ??
              'عێراق';

          final finalName = 'لەنزیک $place';
          _placeNameCache[cacheKey] = finalName;
          return finalName;
        }
      }
    } catch (_) {}

    return _translateEarthquakePlace(fallbackName);
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

      // بەکارهێنانی فانکشنی نوێ بۆ نوێکردنەوەی هەستیار و خێرا
      _updateLiveElevationAndLocation(position);

      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _background,
            content: Text(
              'شوێنەکەت دۆزرایەوە: $_cityName',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: _darkText, fontWeight: FontWeight.bold),
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
            backgroundColor: _background,
            content: Text(
              errorMsg,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: _darkText, fontWeight: FontWeight.bold),
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
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
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
                    child: GestureDetector(
                      onTap: _isLocationLoading
                          ? null
                          : () async {
                              Navigator.pop(dialogContext);
                              await _getCurrentLocationAndWeather();
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _background,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _neuShadowsSmall,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isLocationLoading
                                ? SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _purple,
                                    ),
                                  )
                                : Icon(
                                    Icons.my_location_rounded,
                                    size: 20,
                                    color: _purple,
                                  ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                _isLocationLoading
                                    ? 'لە دۆزینەوەی شوێن...'
                                    : 'دیاریکردنی لۆکەیشن بە GPS و کەشوهەوا',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: _secondaryText.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Text(
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
                      _buildCityChip('سیدصادق', 35.354339, 45.867086),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
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
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);

        setState(() {
          _latitude = lat;
          _longitude = lon;
          _cityName = name;

          _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
        });
        _fetchElevation(
          lat,
          lon,
        ); // گۆڕینی بەرزی بەپێی شارەکە کاتێک لە دەرەوەی GPS ین
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _neuShadowsSmall,
        ),
        child: Text(
          name,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _darkText,
          ),
        ),
      ),
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

  Color _getWeatherCardTint(int code) {
    if (_isDarkMode) {
      if (code == 0) return const Color(0xFF2B2822);
      if (code >= 1 && code <= 3) return const Color(0xFF22272E);
      if (code >= 45 && code <= 48) return const Color(0xFF25292C);
      if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
        return const Color(0xFF1E2A36);
      }
      if (code >= 71 && code <= 77 || code == 85 || code == 86) {
        return const Color(0xFF1F2B33);
      }
      if (code >= 95 && code <= 99) return const Color(0xFF292233);
      return _background;
    }

    if (code == 0) {
      return const Color(0xFFF7F3EA);
    }
    if (code >= 1 && code <= 3) {
      return const Color(0xFFE8EEF3);
    }
    if (code >= 45 && code <= 48) {
      return const Color(0xFFECEFF1);
    }
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
      return const Color(0xFFE3EDF6);
    }
    if (code >= 71 && code <= 77 || code == 85 || code == 86) {
      return const Color(0xFFEEF4F8);
    }
    if (code >= 95 && code <= 99) {
      return const Color(0xFFEFEAF4);
    }
    return _background;
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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.psychology_rounded, color: _purple),
                const SizedBox(width: 10),
                Text(
                  'ڕاپۆرتی ڕۆژەکان',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                report,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, height: 1.7, color: _darkText),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
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

      final dynamic rainAmount = data.precipitationSums.length > i
          ? data.precipitationSums[i]
          : 0.0;

      final dynamic rainProb = data.precipitationProbabilities.length > i
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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.water_drop_rounded, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Text(
                  'بڕی باران بارین',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                rainReport,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, height: 1.7, color: _darkText),
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

  void _showEarthquakeReportDialog(BuildContext context) {
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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.waves_rounded, color: Colors.deepOrangeAccent),
                const SizedBox(width: 10),
                Text(
                  '  سەرچاوەکانی  (USGS)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<EarthquakeModel>>(
                future: _earthquakeData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrange,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'هەڵە لە وەرگرتنی داتا: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    );
                  }

                  final allEarthquakes = snapshot.data ?? [];
                  final now = DateTime.now();

                  final earthquakes = allEarthquakes.where((eq) {
                    final isIraq = eq.place.toLowerCase().contains('iraq');
                    if (!isIraq) return false;

                    try {
                      final eqTime = DateTime.parse(eq.time);
                      final difference = now.difference(eqTime).inHours;
                      return difference <= 48 && difference >= 0;
                    } catch (_) {
                      return true;
                    }
                  }).toList();

                  if (earthquakes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'هیچ بومەلەرزەیەک لە هەرێمی کوردستان تۆمار نەکراوە لە ٤٨ سەعاتی ڕابردوودا',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _darkText,
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '  بومەلەرزەکان لە هەرێمی کوردستان وعێراق (٤٨ سەعاتی ڕابردوو):',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _secondaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 220,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(
                                  earthquakes.first.lat,
                                  earthquakes.first.lon,
                                ),
                                initialZoom: 6.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.zheer.weatherapp',
                                ),
                                MarkerLayer(
                                  markers: earthquakes.map((eq) {
                                    return Marker(
                                      point: LatLng(eq.lat, eq.lon),
                                      width: 40,
                                      height: 40,
                                      child: Tooltip(
                                        message:
                                            'شوێن: ${eq.place}\nبری گوڕ: ${eq.mag} ڕێختەر\nقوڵی: ${eq.depth.toStringAsFixed(1)} کم\nکات و بەروار: ${eq.time}',
                                        child: const Icon(
                                          Icons.crisis_alert_rounded,
                                          color: Colors.deepOrange,
                                          size: 32,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لیستی بومەلەرزەکان لە هەرێمی کوردستان و عێراق:',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _darkText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...earthquakes.take(10).map((eq) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _background,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _neuShadowsSmall,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String>(
                                    future: _getRealMapLocationName(
                                      eq.lat,
                                      eq.lon,
                                      eq.place,
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Text(
                                          'شوێن: لە دیاریکردندایە...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }

                                      final placeName =
                                          snapshot.data ?? 'نەناسراو';

                                      return Text(
                                        'شوێن: $placeName',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: _darkText,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'بری گوڕ: ${eq.mag} ڕێختەر',
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'قوڵی: ${eq.depth.toStringAsFixed(1)} کم',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'کات و بەروار: ${eq.time}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: _secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'داخستن',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.deepOrange,
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
    WeatherModel data,
  ) {
    final String dayName = _getKurdishDayName(date);

    String searchDate = date.trim();
    if (searchDate.contains('T')) {
      searchDate = searchDate.split('T').first;
    } else if (searchDate.contains(' ')) {
      searchDate = searchDate.split(' ').first;
    }

    List<int> matchedIndices = [];
    DateTime? selectedDt;
    try {
      selectedDt = DateTime.parse(searchDate);
    } catch (_) {}

    for (int i = 0; i < data.hourlyTimes.length; i++) {
      bool isMatch = false;
      if (selectedDt != null) {
        try {
          DateTime hDt = DateTime.parse(data.hourlyTimes[i]);
          if (hDt.year == selectedDt.year &&
              hDt.month == selectedDt.month &&
              hDt.day == selectedDt.day) {
            isMatch = true;
          }
        } catch (_) {}
      }

      if (!isMatch && data.hourlyTimes[i].contains(searchDate)) {
        isMatch = true;
      }

      if (isMatch) {
        matchedIndices.add(i);
      }
    }

    List<int> filteredIndices = [];
    for (int idx in matchedIndices) {
      try {
        DateTime hDt = DateTime.parse(data.hourlyTimes[idx]).toLocal();
        if (hDt.hour % 4 == 0) {
          filteredIndices.add(idx);
        }
      } catch (_) {
        String timeOnly = data.hourlyTimes[idx].contains('T')
            ? data.hourlyTimes[idx].split('T')[1]
            : data.hourlyTimes[idx].split(' ')[1];
        int hour = int.tryParse(timeOnly.split(':')[0]) ?? 0;
        if (hour % 4 == 0) {
          filteredIndices.add(idx);
        }
      }
    }

    if (filteredIndices.length > 8) {
      filteredIndices = filteredIndices.take(8).toList();
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'کەشوهەوای کاتژمێری ($dayName)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _purple),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 340,
              child: filteredIndices.isEmpty
                  ? Center(
                      child: Text(
                        'داتای سەعات بە سەعات بەردەست نییە بۆ ئەم ڕۆژە.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                      ),
                    )
                  : GridView.builder(
                      itemCount: filteredIndices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.5,
                          ),
                      itemBuilder: (context, index) {
                        final realIdx = filteredIndices[index];
                        final String fullTime = data.hourlyTimes[realIdx];

                        final String timeOnly = fullTime.contains('T')
                            ? fullTime.split('T')[1].substring(0, 5)
                            : fullTime;

                        String formattedTime12 = timeOnly;
                        try {
                          int hour24 = int.parse(timeOnly.split(':')[0]);
                          String period = hour24 >= 12 ? 'PM' : 'AM';
                          int hour12 = hour24 % 12;
                          if (hour12 == 0) hour12 = 12;
                          formattedTime12 = '$hour12:00 $period';
                        } catch (_) {}

                        final double temp = data.hourlyTemperatures[realIdx];
                        final int hCode = data.hourlyWeatherCodes[realIdx];
                        final double rain = data.hourlyPrecipitations[realIdx];
                        final double wind = data.hourlyWindSpeeds[realIdx];

                        int humidity = 0;
                        try {
                          if (data.hourlyHumidities.isNotEmpty &&
                              data.hourlyHumidities.length > realIdx) {
                            humidity = data.hourlyHumidities[realIdx];
                          }
                        } catch (_) {
                          humidity = 0;
                        }

                        final int hourVal = int.parse(timeOnly.split(':')[0]);
                        final int isDayTime = (hourVal >= 6 && hourVal < 19)
                            ? 1
                            : 0;

                        final Color weatherColor = _getWeatherIconColor(
                          hCode,
                          isDayTime,
                        );
                        final IconData weatherIcon = _getWeatherIcon(
                          hCode,
                          isDayTime,
                        );

                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _background,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _neuShadowsSmall,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formattedTime12,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: _darkText,
                                    ),
                                  ),
                                  Icon(
                                    weatherIcon,
                                    color: weatherColor,
                                    size: 22,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${temp.round()}°C',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: _purple,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.water_drop,
                                        size: 9,
                                        color: Colors.blueAccent,
                                      ),
                                      Text(
                                        ' ${rain.toStringAsFixed(1)}ملم',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: _secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.air,
                                        size: 9,
                                        color: Colors.teal,
                                      ),
                                      Text(
                                        ' ${wind.round()}کم/س',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: _secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.water,
                                        size: 9,
                                        color: Colors.lightBlue,
                                      ),
                                      Text(
                                        ' %$humidity',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: _secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
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

  Widget _buildNeuContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double radius = 20,
    Color? customColor,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColor ?? _background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _neuShadows,
      ),
      child: child,
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required String title,
    required String value,
    required bool wideScreen,
  }) {
    return _buildNeuContainer(
      radius: 14,
      customColor: cardColor,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
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
                return Center(child: CircularProgressIndicator(color: _purple));
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

              final double todayMax = data.maxTemps.isNotEmpty
                  ? data.maxTemps[0]
                  : data.currentTemp.toDouble();

              final double todayMin = data.minTemps.isNotEmpty
                  ? data.minTemps[0]
                  : data.currentTemp.toDouble();

              final double todayRainSum = data.precipitationSums.isNotEmpty
                  ? data.precipitationSums[0]
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
                          // HEADER (تایبەت بە لۆکەیشن، ئایکۆنی دۆخی تاریک/ڕووناک و کارتی بەرزی زەوی)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _showLocationPickerDialog(context),
                                child: _buildNeuContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  radius: 14,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // جووڵاندنی ئایکۆنی لۆکەیشن بۆ سەرنجڕاکێشانی بەکارهێنەر
                                      AnimatedBuilder(
                                        animation: _locationBounceAnimation,
                                        builder: (context, child) {
                                          return Transform.translate(
                                            offset: Offset(
                                              0,
                                              _locationBounceAnimation.value,
                                            ),
                                            child: child,
                                          );
                                        },
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.redAccent,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _cityName,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: _darkText,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // ئایکۆنێکی بچووکی تیر یان گۆڕین بۆ نیشاندانی ئەوەی دەتوانرێت داگیرسێنرێت
                                      Icon(
                                        Icons.unfold_more_rounded,
                                        size: 14,
                                        color: _secondaryText,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // کارتی GPS، بەرزی زەوی و ئایکۆنی گۆڕینی Dark Mode / Light Mode
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ئایکۆنی گۆڕینی دۆخ لە کەناری کارتی GPS
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isDarkMode = !_isDarkMode;
                                      });
                                    },
                                    child: _buildNeuContainer(
                                      padding: const EdgeInsets.all(8),
                                      radius: 14,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.circle_outlined,
                                            color: _isDarkMode
                                                ? Colors.amber
                                                : _purple,
                                            size: 20,
                                          ),
                                          Positioned(
                                            right: 0,
                                            child: ClipRect(
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                widthFactor: 0.5,
                                                child: Icon(
                                                  Icons.circle,
                                                  color: _isDarkMode
                                                      ? Colors.amber
                                                      : _purple,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // کارتی GPS و بەرزی زەوی
                                  _buildNeuContainer(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    radius: 14,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.terrain_rounded,
                                          color: Colors.teal,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_elevation.toStringAsFixed(2)} م', // پیشاندانی گۆڕانکاری بە پۆینتەوە
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            color: _darkText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // SUMMARY CARDS (ڕەنگە نیۆمۆرفیکییەکان بۆ سێ کارتی سەرەوە)
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.thermostat_rounded,
                                  iconColor: Colors.redAccent,
                                  cardColor: _isDarkMode
                                      ? const Color(0xFF252D38)
                                      : const Color(0xFFE8EEF5),
                                  title: 'بەرزترین',
                                  value: '${todayMax.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.ac_unit_rounded,
                                  iconColor: Colors.blueAccent,
                                  cardColor: _isDarkMode
                                      ? const Color(0xFF252D38)
                                      : const Color(0xFFE8EEF5),
                                  title: 'نزمترین',
                                  value: '${todayMin.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.water_drop_rounded,
                                  iconColor: Colors.cyan,
                                  cardColor: _isDarkMode
                                      ? const Color(0xFF252D38)
                                      : const Color(0xFFE8EEF5),
                                  title: 'باران',
                                  value:
                                      '${todayRainSum.toStringAsFixed(1)} mm',
                                  wideScreen: wideScreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // NEUMORPHIC METEOGRAM CARD (بە هەندەڵکردنی ئایکۆنەکان و ڕەنگدانی خوارەوەی هێڵەکە هاوشیوەی وێنەکە)
                          _buildNeuContainer(
                            radius: 24,
                            customColor: _isDarkMode
                                ? const Color(0xFF232A34)
                                : const Color(0xFFE6ECF5),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // بەشی سەرەوەی کارتەکە کە کات و ئایکۆنی ڕاستەقینەی کەشوهەوای تێدایە هاوشێوەی وێنەکە
                                SizedBox(
                                  height: 38,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: min(
                                      24,
                                      data.hourlyTemperatures.length,
                                    ),
                                    itemBuilder: (context, index) {
                                      if (index % 3 != 0) {
                                        return const SizedBox.shrink();
                                      }
                                      String fullTime =
                                          (data.hourlyTimes.isNotEmpty &&
                                              data.hourlyTimes.length > index)
                                          ? data.hourlyTimes[index]
                                          : '00:00';
                                      String timeOnly = fullTime.contains('T')
                                          ? fullTime
                                                .split('T')[1]
                                                .substring(0, 5)
                                          : fullTime;

                                      int hour24 =
                                          int.tryParse(
                                            timeOnly.split(':')[0],
                                          ) ??
                                          0;
                                      String period = hour24 >= 12
                                          ? 'PM'
                                          : 'AM';
                                      int hour12 = hour24 % 12;
                                      if (hour12 == 0) hour12 = 12;
                                      String formattedTime = '$hour12 $period';

                                      int hCode =
                                          (data.hourlyWeatherCodes.isNotEmpty &&
                                              data.hourlyWeatherCodes.length >
                                                  index)
                                          ? data.hourlyWeatherCodes[index]
                                          : 0;
                                      int isDayTime =
                                          (hour24 >= 6 && hour24 < 19) ? 1 : 0;

                                      return Container(
                                        width: 52,
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              formattedTime,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: _secondaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Icon(
                                              _getWeatherIcon(hCode, isDayTime),
                                              color: _getWeatherIconColor(
                                                hCode,
                                                isDayTime,
                                              ),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),

                                SizedBox(
                                  height: 85,
                                  child: LineChart(
                                    LineChartData(
                                      minX: 0,
                                      maxX:
                                          (min(
                                                    24,
                                                    data
                                                        .hourlyTemperatures
                                                        .length,
                                                  ) -
                                                  1)
                                              .toDouble()
                                              .clamp(0.0, 23.0),
                                      minY: 0,
                                      maxY: 40,
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: true,
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
                                              color: _secondaryText.withValues(
                                                alpha: 0.1,
                                              ),
                                              strokeWidth: 1,
                                            ),
                                        getDrawingVerticalLine: (value) =>
                                            FlLine(
                                              color: _secondaryText.withValues(
                                                alpha: 0.1,
                                              ),
                                              strokeWidth: 1,
                                            ),
                                      ),
                                      titlesData: FlTitlesData(
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: List.generate(
                                            min(
                                              24,
                                              data.hourlyTemperatures.length,
                                            ),
                                            (i) {
                                              double temp =
                                                  data.hourlyTemperatures[i];
                                              double mappedY =
                                                  15.0 + (temp - 15.0) * 0.8;
                                              return FlSpot(
                                                i.toDouble(),
                                                mappedY.clamp(10.0, 38.0),
                                              );
                                            },
                                          ),
                                          isCurved: true,
                                          color: Colors.orange,
                                          barWidth: 2.5,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: Colors.orange.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ACTION BUTTONS
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showDetailedAIReportDialog(
                                    context,
                                    data,
                                  ),
                                  child: _buildNeuContainer(
                                    radius: 18,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.psychology_rounded,
                                              size: 18,
                                              color: _purple,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'کەشوهەوا ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: _darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            return Transform.translate(
                                              offset: Offset(
                                                _pulseAnimation.value,
                                                0,
                                              ),
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: _background,
                                              shape: BoxShape.circle,
                                              boxShadow: _neuShadowsSmall,
                                            ),
                                            child: Icon(
                                              Icons.touch_app_rounded,
                                              size: 12,
                                              color: _purple,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _showRainReportDialog(context, data),
                                  child: _buildNeuContainer(
                                    radius: 18,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.water_drop_rounded,
                                              size: 18,
                                              color: Colors.blueAccent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'بڕی باران',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: _darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            return Transform.translate(
                                              offset: Offset(
                                                _pulseAnimation.value,
                                                0,
                                              ),
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: _background,
                                              shape: BoxShape.circle,
                                              boxShadow: _neuShadowsSmall,
                                            ),
                                            child: const Icon(
                                              Icons.touch_app_rounded,
                                              size: 12,
                                              color: Colors.blueAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _showEarthquakeReportDialog(context),
                                  child: _buildNeuContainer(
                                    radius: 18,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.waves_rounded,
                                              size: 18,
                                              color: Colors.deepOrangeAccent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'بومەلەرزە',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: _darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            return Transform.translate(
                                              offset: Offset(
                                                _pulseAnimation.value,
                                                0,
                                              ),
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: _background,
                                              shape: BoxShape.circle,
                                              boxShadow: _neuShadowsSmall,
                                            ),
                                            child: const Icon(
                                              Icons.touch_app_rounded,
                                              size: 12,
                                              color: Colors.deepOrangeAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // SUNRISE & SUNSET
                          _buildNeuContainer(
                            radius: 18,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.wb_sunny_rounded,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'خۆرهەڵاتن: ${sunTimes['sunrise'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: _darkText,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 20,
                                  width: 1,
                                  color: _secondaryText.withValues(alpha: 0.3),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.wb_twilight_rounded,
                                      color: Colors.deepOrange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'خۆرئاوا: ${sunTimes['sunset'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: _darkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // FORECAST LIST
                          const SizedBox(height: 6),
                          ...List.generate(forecastDays, (i) {
                            final String date = data.times[i];
                            final String dayName = _getKurdishDayName(date);
                            final dynamic maxT = data.maxTemps[i];
                            final dynamic minT = data.minTemps[i];
                            final int code = data.weatherCodes.length > i
                                ? data.weatherCodes[i]
                                : 0;

                            final Color cardTint = _getWeatherCardTint(code);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: GestureDetector(
                                onTap: () => _showDayDetailDialog(
                                  context,
                                  date,
                                  maxT,
                                  minT,
                                  code,
                                  data,
                                ),
                                child: _buildNeuContainer(
                                  radius: 16,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  customColor: cardTint,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: cardTint,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: _neuShadowsSmall,
                                            ),
                                            child: Icon(
                                              _getWeatherIcon(code, 1),
                                              color: _getWeatherIconColor(
                                                code,
                                                1,
                                              ),
                                              size: 32,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dayName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  color: _darkText,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                date,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: _secondaryText
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${maxT?.round() ?? 0}° / ${minT?.round() ?? 0}°',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  color: _darkText,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _getWeatherDescription(code),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: _secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          AnimatedBuilder(
                                            animation: _pulseAnimation,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(
                                                  _pulseAnimation.value,
                                                  0,
                                                ),
                                                child: child,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: cardTint,
                                                shape: BoxShape.circle,
                                                boxShadow: _neuShadowsSmall,
                                              ),
                                              child: Icon(
                                                Icons.touch_app_rounded,
                                                size: 14,
                                                color: _purple,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 16),

                          // MAP PREVIEW
                          Text(
                            'شوێنەکەت لەسەر نەخشە      -        پڕۆگرامساز: ژیر مەستەکانــ©2026ـــی',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _darkText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _neuShadows,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: SizedBox(
                                height: 180,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      _latitude,
                                      _longitude,
                                    ),
                                    initialZoom: 12.0,
                                    interactionOptions:
                                        const InteractionOptions(
                                          flags: InteractiveFlag.none,
                                        ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.zheer.weatherapp',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(_latitude, _longitude),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_pin,
                                            color: Colors.redAccent,
                                            size: 38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
}

class WeatherModel {
  final double currentTemp;
  final int isDay;
  final List<String> times;
  final List<double> maxTemps;
  final List<double> minTemps;
  final List<int> weatherCodes;
  final List<double> precipitationSums;
  final List<int> precipitationProbabilities;

  final List<String> hourlyTimes;
  final List<double> hourlyTemperatures;
  final List<int> hourlyWeatherCodes;
  final List<double> hourlyPrecipitations;
  final List<double> hourlyWindSpeeds;
  final List<int> hourlyHumidities;

  WeatherModel({
    required this.currentTemp,
    required this.isDay,
    required this.times,
    required this.maxTemps,
    required this.minTemps,
    required this.weatherCodes,
    required this.precipitationSums,
    required this.precipitationProbabilities,
    required this.hourlyTimes,
    required this.hourlyTemperatures,
    required this.hourlyWeatherCodes,
    required this.hourlyPrecipitations,
    required this.hourlyWindSpeeds,
    required this.hourlyHumidities,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final currentWeather = json['current'] ?? json['current_weather'] ?? {};
    final daily = json['daily'] ?? {};
    final hourly = json['hourly'] ?? {};

    List<double> parseDoubleList(dynamic data) {
      if (data == null) return <double>[];
      return List<double>.from(
        (data as List).map((e) => (e as num).toDouble()),
      );
    }

    List<int> parseIntList(dynamic data) {
      if (data == null) return <int>[];
      return List<int>.from((data as List).map((e) => (e as num).toInt()));
    }

    List<String> parseStringList(dynamic data) {
      if (data == null) return <String>[];
      return List<String>.from((data as List).map((e) => e.toString()));
    }

    return WeatherModel(
      currentTemp:
          (currentWeather['temperature_2m'] ??
                  currentWeather['temperature'] as num?)
              ?.toDouble() ??
          0.0,
      isDay: (currentWeather['is_day'] as num?)?.toInt() ?? 1,

      times: parseStringList(daily['time']),
      maxTemps: parseDoubleList(daily['temperature_2m_max']),
      minTemps: parseDoubleList(daily['temperature_2m_min']),
      weatherCodes: parseIntList(daily['weathercode'] ?? daily['weather_code']),
      precipitationSums: parseDoubleList(daily['precipitation_sum']),
      precipitationProbabilities: parseIntList(
        daily['precipitation_probability_max'],
      ),

      hourlyTimes: parseStringList(hourly['time']),
      hourlyTemperatures: parseDoubleList(hourly['temperature_2m']),
      hourlyWeatherCodes: parseIntList(
        hourly['weather_code'] ?? hourly['weathercode'],
      ),
      hourlyPrecipitations: parseDoubleList(hourly['precipitation']),
      hourlyWindSpeeds: parseDoubleList(
        hourly['wind_speed_10m'] ?? hourly['windspeed_10m'],
      ),
      hourlyHumidities: parseIntList(
        hourly['relative_humidity_2m'] ?? hourly['relativehumidity_2m'],
      ),
    );
  }
}
