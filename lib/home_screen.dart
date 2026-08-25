import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;

import 'earthquake_service.dart';
import 'location_weather_service.dart';
import 'models/earthquake_model.dart';

/// خزمەتگوزاری پەخشکردنی دەنگی کلیک بە فیدباکی لەرینەوە بۆ تەواوی پلاتفۆرمەکان
class SoundFeedbackService {
  static void playClick() {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
}

/// ویجێتی کارتی کارلێککار بۆ پێدانی دەنگ، قەبارەی پەستان و گۆڕانی ڕووناکی لەکاتی گرتەکردندا
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          SoundFeedbackService.playClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (widget.onTap != null) {
            widget.onTap!();
          }
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 90),
            opacity: _isPressed ? 0.75 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

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
  bool _isDarkMode = false;
  bool _isManualLocation = false;

  final MapController _fullscreenMapController = MapController();

  double _latitude = 35.5558;
  double _longitude = 45.4351;
  double _elevation = 850.0;

  String _cityName = 'سلێمانی';
  String _mapLayerType = 'normal';

  Color get _darkText =>
      _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get _secondaryText =>
      _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _purple =>
      _isDarkMode ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
  Color get _iosGlassBorder => _isDarkMode
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.6);

  List<Color> get _iosAtmosphereGradient => _isDarkMode
      ? const [
          Color(0xFF0B0F19),
          Color(0xFF111827),
          Color(0xFF1E1B4B),
          Color(0xFF0F172A),
        ]
      : const [
          Color(0xFF38BDF8),
          Color(0xFF60A5FA),
          Color(0xFF818CF8),
          Color(0xFFE0E7FF),
        ];

  List<BoxShadow> get _neuShadows => [
    BoxShadow(
      color: _isDarkMode
          ? Colors.black.withValues(alpha: 0.45)
          : const Color(0xFF1E293B).withValues(alpha: 0.12),
      offset: const Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -2,
    ),
  ];

  List<BoxShadow> get _neuShadowsSmall => [
    BoxShadow(
      color: _isDarkMode
          ? Colors.black.withValues(alpha: 0.35)
          : const Color(0xFF1E293B).withValues(alpha: 0.08),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -1,
    ),
  ];

  late AnimationController _pulseController;
  late Animation<double> _locationBounceAnimation;
  late Animation<double> _mapIconBounceAnimation;
  late Animation<double> _rotateAnimation;

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastFetchedPosition;

  final Map<String, String> _placeNameCache = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
    _earthquakeData = EarthquakeService.getRecentEarthquakes();
    _fetchElevation(_latitude, _longitude);

    _refreshTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      if (mounted) {
        setState(() {
          _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _locationBounceAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _mapIconBounceAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLiveLocation();
      _startLocationStream();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 100,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!_isManualLocation) {
              _updateLiveElevationAndLocation(position);
            }
          },
        );
  }

  void _updateLiveElevationAndLocation(Position position) {
    if (!mounted) return;

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;

      if (position.altitude != 0.0) {
        _elevation = position.altitude;
      }
    });

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

  Future<void> _fetchElevation(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/elevation?latitude=$lat&longitude=$lon',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 7));
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

  Future<Map<String, dynamic>?> _fetchAirQualityData(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone&timezone=auto',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['current'] != null) {
          return data['current'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> _searchCityByName(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=6&accept-language=ckb,ku,ar',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'com.zheer.weatherapp'})
          .timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  int _calculateRealAqi(Map<String, dynamic>? data) {
    if (data == null) return 0;
    if (data['us_aqi'] != null) {
      return (data['us_aqi'] as num).toInt();
    }
    final double pm25 = (data['pm2_5'] as num?)?.toDouble() ?? 0.0;
    if (pm25 <= 12.0) {
      return ((50 / 12.0) * pm25).round();
    } else if (pm25 <= 35.4) {
      return (51 + ((49 / 23.3) * (pm25 - 12.1))).round();
    } else if (pm25 <= 55.4) {
      return (101 + ((49 / 19.9) * (pm25 - 35.5))).round();
    } else if (pm25 <= 150.4) {
      return (151 + ((49 / 94.9) * (pm25 - 55.5))).round();
    } else {
      return (201 + ((99 / 99.5) * (pm25 - 150.5))).round().clamp(0, 500);
    }
  }

  Map<String, dynamic> _getAqiStatus(int aqi) {
    if (aqi <= 50) {
      return {
        'status': 'خاوێن',
        'color': const Color(0xFF10B981),
        'desc': 'کوالێتی هەوا زۆر باشە و هیچ مەترسییەکی تەندروستی نییە.',
      };
    } else if (aqi <= 100) {
      return {
        'status': 'ئاسایی',
        'color': const Color(0xFFF59E0B),
        'desc': 'کوالێتی هەوا لە ئاستی ئاساییدایە.',
      };
    } else if (aqi <= 200) {
      return {
        'status': 'ژەهراوی',
        'color': const Color(0xFFEF4444),
        'desc':
            'هەوا پیس و ژەهراوییە و دەبێت هاوڵاتییان بەتایبەت نەخۆش ئاگاداربن.',
      };
    } else {
      return {
        'status': 'مەترسیدار',
        'color': const Color(0xFF881337),
        'desc': 'ئاگاداری تەندروستی گشتی، هەوا لە ئاستێکی زۆر مەترسیداردایە.',
      };
    }
  }

  void _showAirQualityDialog(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color cardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.65);
    final Color borderColor = _iosGlassBorder;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: _neuShadows,
                    ),
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchAirQualityData(_latitude, _longitude),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 200,
                            child: Center(
                              child: CupertinoActivityIndicator(radius: 16),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data == null) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'داتای کوالێتیی هەوا بەردەست نییە یان ئینتەرنێت نییە.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _darkText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              PressableCard(
                                onTap: () => Navigator.pop(dialogContext),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _purple,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'داخستن',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        final aqiData = snapshot.data!;
                        final int usAqi = _calculateRealAqi(aqiData);
                        final dynamic pm25 = aqiData['pm2_5'] ?? 0;
                        final dynamic pm10 = aqiData['pm10'] ?? 0;
                        final dynamic co = aqiData['carbon_monoxide'] ?? 0;
                        final dynamic no2 = aqiData['nitrogen_dioxide'] ?? 0;
                        final dynamic so2 = aqiData['sulphur_dioxide'] ?? 0;
                        final dynamic o3 = aqiData['ozone'] ?? 0;

                        final statusInfo = _getAqiStatus(usAqi);
                        final Color statusColor = statusInfo['color'] as Color;

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  PressableCard(
                                    onTap: () => Navigator.pop(dialogContext),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        color: _darkText,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'کوالێتی هەوا — $_cityName',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                        color: _darkText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Compact Overview Card
                              PressableCard(
                                onTap: () {},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: borderColor),
                                    boxShadow: _neuShadowsSmall,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$usAqi',
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                              color: statusColor,
                                              height: 1.0,
                                              letterSpacing: -1.0,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'AQI',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: _secondaryText,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            height: 16,
                                            width: 1,
                                            color: borderColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: statusColor.withValues(
                                                  alpha: 0.35,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              statusInfo['status'] as String,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Divider(color: borderColor, height: 1),
                                      const SizedBox(height: 8),
                                      Text(
                                        statusInfo['desc'] as String,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                          color: _darkText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Air Components Grid
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.45,
                                children: [
                                  _buildIosAirQualityGridItem(
                                    title: 'تەنی زیانبەخش',
                                    value: '$pm25',
                                    unit: 'µg/m³',
                                    icon: CupertinoIcons.circle_grid_hex,
                                    iconColor: Colors.deepOrangeAccent,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                  ),
                                  _buildIosAirQualityGridItem(
                                    title: 'تۆز و گەردیلە',
                                    value: '$pm10',
                                    unit: 'µg/m³',
                                    icon: CupertinoIcons.sparkles,
                                    iconColor: Colors.amber.shade800,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                  ),
                                  _buildIosAirQualityGridItem(
                                    title: 'گازی ئۆزۆن',
                                    value: '$o3',
                                    unit: 'µg/m³',
                                    icon: CupertinoIcons.sun_max,
                                    iconColor: Colors.blueAccent,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                  ),
                                  _buildIosAirQualityGridItem(
                                    title: 'نایترۆجین',
                                    value: '$no2',
                                    unit: 'µg/m³',
                                    icon: CupertinoIcons.lab_flask,
                                    iconColor: Colors.purpleAccent,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                  ),
                                  _buildIosAirQualityGridItem(
                                    title: 'کاربۆن مۆنۆکسید',
                                    value: '$co',
                                    unit: 'µg/m³',
                                    icon: CupertinoIcons.cloud,
                                    iconColor: Colors.teal,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                  ),
                                  _buildIosAirQualityGridItem(
                                    title: 'دوانۆکسیدی گۆگرد',
                                    value: '$so2',
                                    unit: 'µg/m³',
                                    icon:
                                        CupertinoIcons.exclamationmark_triangle,
                                    iconColor: Colors.redAccent,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIosAirQualityGridItem({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    return PressableCard(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: _neuShadowsSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: iconColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirQualityImageBannerCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchAirQualityData(_latitude, _longitude),
      builder: (context, snapshot) {
        int aqi = 0;
        if (snapshot.hasData && snapshot.data != null) {
          aqi = _calculateRealAqi(snapshot.data);
        }

        final statusInfo = _getAqiStatus(aqi);
        final Color statusColor = statusInfo['color'] as Color;
        final String statusName = statusInfo['status'] as String;

        final double progressRatio = (aqi / 250.0).clamp(0.0, 1.0);
        final List<int> scales = [25, 50, 100, 150, 200, 250];

        return Directionality(
          textDirection: TextDirection.rtl,
          child: PressableCard(
            onTap: () => _showAirQualityDialog(context),
            child: _buildNeuContainer(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              CupertinoIcons.wind,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'کوالێتی هەوا: $_cityName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: _darkText,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          statusName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'هەوای ئێستا: $statusName',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            'ڕێژە: $aqi ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double fullWidth = constraints.maxWidth;
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF881337),
                                      Color(0xFFEF4444),
                                      Color(0xFFF59E0B),
                                      Color(0xFF10B981),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: (fullWidth * progressRatio).clamp(
                                  0.0,
                                  fullWidth - 14,
                                ),
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: statusColor,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: scales.map((val) {
                          return Text(
                            '$val',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: aqi >= val ? _darkText : _secondaryText,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'خاوێن',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          Text(
                            'ئاسایی',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          Text(
                            'ژەهراوی',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          Text(
                            'مەترسیدار',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF881337),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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

      final response = await http
          .get(url, headers: {'User-Agent': 'com.zheer.weatherapp'})
          .timeout(const Duration(seconds: 7));

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
        _isManualLocation = false;
      });
    }

    try {
      final Position position =
          await LocationWeatherService.getCurrentLocation();
      _updateLiveElevationAndLocation(position);

      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _isDarkMode
                ? const Color(0xFF1E293B)
                : Colors.white,
            content: Text(
              'شوێنەکەت دۆزرایەوە: $_cityName',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _darkText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLocationLoading = false;
      });

      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _isDarkMode
                ? const Color(0xFF1E293B)
                : Colors.white,
            content: const Text(
              'کێشە لە پەیوەستبوون بە هێڵی ئینتەرنێت یان GPS ڕوویدا!',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: CupertinoColors.destructiveRed,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSeaLevelDetailsDialog(BuildContext context) {
    double seaLevelPressure = 1013.25 - (_elevation * 0.12);
    double standardElevation = 850.0;
    double elevationDiff = _elevation - standardElevation;

    final bool isDark = _isDarkMode;
    final Color iosCardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.65);
    final Color iosBorderColor = _iosGlassBorder;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 20,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: iosBorderColor, width: 1.5),
                    boxShadow: _neuShadows,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.map_pin_ellipse,
                                    color: Colors.teal,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'وردەکاری ئاستی دەریا و بەرزی',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                    color: _darkText,
                                  ),
                                ),
                              ],
                            ),
                            PressableCard(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: _darkText,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 170,
                            decoration: BoxDecoration(
                              border: Border.all(color: iosBorderColor),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(_latitude, _longitude),
                                initialZoom: 11.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName: 'com.zheer.weatherapp',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(_latitude, _longitude),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        CupertinoIcons.location_solid,
                                        color: CupertinoColors.systemRed,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSeaLevelRow(
                          title: 'بەرزی لە ئاستی دەریا',
                          value: '${_elevation.toStringAsFixed(1)} مەتر',
                          icon: CupertinoIcons.scope,
                          color: Colors.teal,
                          cardBg: iosCardBg,
                          borderColor: iosBorderColor,
                        ),
                        const SizedBox(height: 8),
                        _buildSeaLevelRow(
                          title: 'فشاری بەرگەهەوا',
                          value: '${seaLevelPressure.toStringAsFixed(1)} hPa',
                          icon: CupertinoIcons.gauge,
                          color: Colors.orangeAccent,
                          cardBg: iosCardBg,
                          borderColor: iosBorderColor,
                        ),
                        const SizedBox(height: 8),
                        _buildSeaLevelRow(
                          title: 'جیاوازی لەگەڵ ئاستی ئاسایی',
                          value:
                              '${elevationDiff >= 0 ? '+' : ''}${elevationDiff.toStringAsFixed(1)} مەتر',
                          icon: CupertinoIcons.arrow_up_down,
                          color: Colors.blueAccent,
                          cardBg: iosCardBg,
                          borderColor: iosBorderColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeaLevelRow({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
  }) {
    return PressableCard(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: _neuShadowsSmall,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreenMapDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
            if (_mapLayerType == 'satellite') {
              tileUrl =
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
            } else if (_mapLayerType == 'animated' ||
                _mapLayerType == 'interactive') {
              tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
            } else if (_mapLayerType == 'temp') {
              tileUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  padding: const EdgeInsets.all(12),
                  child: SafeArea(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _fullscreenMapController,
                            options: MapOptions(
                              initialCenter: LatLng(_latitude, _longitude),
                              initialZoom: 7.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: tileUrl,
                                userAgentPackageName: 'com.zheer.weatherapp',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_latitude, _longitude),
                                    width: 75,
                                    height: 65,
                                    child: AnimatedBuilder(
                                      animation: _mapIconBounceAnimation,
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            0,
                                            _mapIconBounceAnimation.value,
                                          ),
                                          child: child,
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: CupertinoColors.systemRed,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              _cityName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            CupertinoIcons.location_solid,
                                            color: CupertinoColors.systemRed,
                                            size: 30,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: PressableCard(
                              onTap: () => Navigator.pop(dialogContext),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isDarkMode
                                          ? Colors.black45
                                          : Colors.white60,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _iosGlassBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      color: _darkText,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? Colors.black45
                                        : Colors.white60,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: _iosGlassBorder),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMapLayerButton(
                                        icon: CupertinoIcons.play_circle_fill,
                                        label: 'ئەنیمەیشن',
                                        type: 'animated',
                                        setStateDialog: setStateDialog,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildMapLayerButton(
                                        icon: CupertinoIcons.globe,
                                        label: 'سەتەلایت',
                                        type: 'satellite',
                                        setStateDialog: setStateDialog,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildMapLayerButton(
                                        icon: CupertinoIcons.hand_draw_fill,
                                        label: 'کارلێککار',
                                        type: 'interactive',
                                        setStateDialog: setStateDialog,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildMapLayerButton(
                                        icon: CupertinoIcons.thermometer,
                                        label: 'پلەی گەرمی',
                                        type: 'temp',
                                        setStateDialog: setStateDialog,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapLayerButton({
    required IconData icon,
    required String label,
    required String type,
    required StateSetter setStateDialog,
  }) {
    final bool isSelected = _mapLayerType == type;
    return Tooltip(
      message: label,
      child: PressableCard(
        onTap: () {
          setStateDialog(() {
            _mapLayerType = type;
          });
          setState(() {
            _mapLayerType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isSelected
                ? _purple
                : (_isDarkMode
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.06)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : _darkText,
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showLocationSearchDialog(BuildContext context) {
    String searchQuery = '';
    List<dynamic> searchResults = [];
    bool isSearching = false;
    Timer? debounce;
    final TextEditingController searchController = TextEditingController();
    final bool isDark = _isDarkMode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: _iosGlassBorder, width: 1.5),
                    boxShadow: _neuShadows,
                  ),
                  child: StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: _purple.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  CupertinoIcons.search,
                                  color: _purple,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'گەڕان بۆ ناوچەکان',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                  color: _darkText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _iosGlassBorder),
                            ),
                            child: TextField(
                              controller: searchController,
                              style: TextStyle(
                                color: _darkText,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'ناوی شار یان وڵات بنووسە...',
                                hintStyle: TextStyle(
                                  color: _secondaryText.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  CupertinoIcons.building_2_fill,
                                  color: _secondaryText,
                                  size: 18,
                                ),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          CupertinoIcons.clear_circled_solid,
                                          color: _secondaryText,
                                        ),
                                        onPressed: () {
                                          SoundFeedbackService.playClick();
                                          searchController.clear();
                                          setStateDialog(() {
                                            searchQuery = '';
                                            searchResults = [];
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (value) {
                                setStateDialog(() {
                                  searchQuery = value;
                                });

                                if (debounce != null && debounce!.isActive) {
                                  debounce!.cancel();
                                }

                                debounce = Timer(
                                  const Duration(milliseconds: 700),
                                  () async {
                                    if (value.trim().isEmpty) {
                                      setStateDialog(() {
                                        searchResults = [];
                                        isSearching = false;
                                      });
                                      return;
                                    }
                                    setStateDialog(() {
                                      isSearching = true;
                                    });
                                    final results = await _searchCityByName(
                                      value,
                                    );
                                    setStateDialog(() {
                                      searchResults = results;
                                      isSearching = false;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (searchQuery.isEmpty)
                            PressableCard(
                              onTap: _isLocationLoading
                                  ? null
                                  : () async {
                                      Navigator.pop(dialogContext);
                                      await _getCurrentLocationAndWeather();
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _purple.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _isLocationLoading
                                        ? const CupertinoActivityIndicator(
                                            radius: 10,
                                          )
                                        : Icon(
                                            CupertinoIcons.location_fill,
                                            size: 18,
                                            color: _purple,
                                          ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _isLocationLoading
                                            ? 'لە دۆزینەوەی شوێن...'
                                            : 'دۆزینەوەی شوێنی ئێستام (GPS)',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: _purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (searchQuery.isEmpty) const SizedBox(height: 16),
                          if (searchQuery.isEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'شارە باوەکان:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _secondaryText,
                                ),
                              ),
                            ),
                          if (searchQuery.isEmpty) const SizedBox(height: 8),
                          if (searchQuery.isEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.start,
                              children: [
                                _buildCityChip('سلێمانی', 35.5558, 45.4351),
                                _buildCityChip('هەولێر', 36.1901, 44.0091),
                                _buildCityChip('دهۆک', 36.8679, 42.9885),
                                _buildCityChip('هەڵەبجە', 35.1772, 45.9877),
                                _buildCityChip('کەرکووک', 35.4681, 44.3922),
                                _buildCityChip('سیدصادق', 35.371102, 45.856458),
                              ],
                            ),
                          if (searchQuery.isNotEmpty && isSearching)
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: CupertinoActivityIndicator(radius: 14),
                              ),
                            ),
                          if (searchQuery.isNotEmpty &&
                              !isSearching &&
                              searchResults.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'هیچ ناوچەیەک نەدۆزرایەوە',
                                  style: TextStyle(
                                    color: _secondaryText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          if (searchQuery.isNotEmpty &&
                              !isSearching &&
                              searchResults.isNotEmpty)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: searchResults.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: _secondaryText.withValues(alpha: 0.15),
                                ),
                                itemBuilder: (context, index) {
                                  final result = searchResults[index];
                                  final fullName =
                                      result['display_name'] as String;
                                  final shortName =
                                      result['name'] as String? ??
                                      fullName.split(',').first;

                                  return PressableCard(
                                    onTap: () {
                                      Navigator.pop(dialogContext);
                                      setState(() {
                                        _isManualLocation = true;
                                        _latitude = double.parse(
                                          result['lat'].toString(),
                                        );
                                        _longitude = double.parse(
                                          result['lon'].toString(),
                                        );
                                        _cityName = shortName;
                                        _weatherData =
                                            _loadWeatherForCoordinates(
                                              _latitude,
                                              _longitude,
                                            );
                                      });
                                      _fetchElevation(_latitude, _longitude);
                                    },
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemRed
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.location_solid,
                                          color: CupertinoColors.systemRed,
                                          size: 16,
                                        ),
                                      ),
                                      title: Text(
                                        shortName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: _darkText,
                                        ),
                                      ),
                                      subtitle: Text(
                                        fullName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _secondaryText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              PressableCard(
                                onTap: () => Navigator.pop(dialogContext),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'داخستن',
                                    style: TextStyle(
                                      color: _secondaryText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityChip(String name, double lat, double lon) {
    final bool isDark = _isDarkMode;
    return PressableCard(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _isManualLocation = true;
          _latitude = lat;
          _longitude = lon;
          _cityName = name;
          _weatherData = _loadWeatherForCoordinates(_latitude, _longitude);
        });
        _fetchElevation(lat, lon);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _iosGlassBorder),
        ),
        child: Text(
          name,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: _darkText,
          ),
        ),
      ),
    );
  }

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
        final String period = h >= 12 ? 'پاشنیوەڕۆ' : 'بەیانی';
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
      return {'sunrise': '٠٥:٣٠ بەیانی', 'sunset': '٠٧:١٥ پاشنیوەڕۆ'};
    }
  }

  Widget _buildWeatherVisualIcon(int code, int isDay, {double size = 36}) {
    const Color sunOrange = Color(0xFFFF7A00);
    const Color outlineBlue = Color(0xFF0066FF);

    Widget content;

    if (code == 0) {
      content = Icon(
        isDay == 1 ? CupertinoIcons.sun_max : CupertinoIcons.moon,
        color: sunOrange,
        size: size,
      );
    } else if (code == 1 || code == 2) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              isDay == 1 ? CupertinoIcons.sun_max : CupertinoIcons.moon,
              color: sunOrange,
              size: size * 0.65,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Icon(
              CupertinoIcons.cloud,
              color: outlineBlue,
              size: size * 0.85,
            ),
          ),
        ],
      );
    } else if (code == 3) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              CupertinoIcons.cloud,
              color: outlineBlue.withValues(alpha: 0.6),
              size: size * 0.75,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Icon(
              CupertinoIcons.cloud,
              color: outlineBlue,
              size: size * 0.85,
            ),
          ),
        ],
      );
    } else if (code >= 45 && code <= 48) {
      content = Icon(CupertinoIcons.wind, color: outlineBlue, size: size);
    } else if (code >= 51 && code <= 57) {
      content = Icon(
        CupertinoIcons.cloud_drizzle,
        color: outlineBlue,
        size: size,
      );
    } else if (code >= 61 && code <= 67 || (code >= 80 && code <= 82)) {
      content = Icon(CupertinoIcons.cloud_rain, color: outlineBlue, size: size);
    } else if (code >= 71 && code <= 77 || code == 85 || code == 86) {
      content = Icon(CupertinoIcons.cloud_snow, color: outlineBlue, size: size);
    } else if (code >= 95 && code <= 99) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Icon(CupertinoIcons.cloud_bolt, color: outlineBlue, size: size),
          Positioned(
            bottom: 0,
            child: Icon(
              CupertinoIcons.bolt,
              color: sunOrange,
              size: size * 0.5,
            ),
          ),
        ],
      );
    } else {
      content = Icon(
        isDay == 1 ? CupertinoIcons.sun_max : CupertinoIcons.moon,
        color: sunOrange,
        size: size,
      );
    }

    return SizedBox(
      width: size * 1.25,
      height: size * 1.15,
      child: Center(child: content),
    );
  }

  Color _getWeatherCardTint(int code) {
    if (_isDarkMode) {
      if (code == 0) return const Color(0xFF2E261A).withValues(alpha: 0.6);
      if (code >= 1 && code <= 3) {
        return const Color(0xFF1E293B).withValues(alpha: 0.6);
      }
      if (code >= 45 && code <= 48) {
        return const Color(0xFF334155).withValues(alpha: 0.6);
      }
      if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
        return const Color(0xFF1E3A8A).withValues(alpha: 0.5);
      }
      if (code >= 71 && code <= 77 || code == 85 || code == 86) {
        return const Color(0xFF0F766E).withValues(alpha: 0.5);
      }
      if (code >= 95 && code <= 99) {
        return const Color(0xFF4C1D95).withValues(alpha: 0.5);
      }
      return Colors.white.withValues(alpha: 0.08);
    }

    if (code == 0) return const Color(0xFFFFFBEB).withValues(alpha: 0.7);
    if (code >= 1 && code <= 3) {
      return const Color(0xFFF1F5F9).withValues(alpha: 0.7);
    }
    if (code >= 45 && code <= 48) {
      return const Color(0xFFF8FAFC).withValues(alpha: 0.7);
    }
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
      return const Color(0xFFEFF6FF).withValues(alpha: 0.7);
    }
    if (code >= 71 && code <= 77 || code == 85 || code == 86) {
      return const Color(0xFFF0FDF4).withValues(alpha: 0.7);
    }
    if (code >= 95 && code <= 99) {
      return const Color(0xFFFAF5FF).withValues(alpha: 0.7);
    }
    return Colors.white.withValues(alpha: 0.7);
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'ساماڵ و ڕووناک';
    if (code == 1) return 'کەمێک هەور';
    if (code == 2) return 'نیمچە هەور';
    if (code == 3) return 'هەوراوی';
    if (code >= 45 && code <= 48) return 'تەمومژاوی';
    if (code >= 51 && code <= 57) return 'بارانی کەم';
    if (code >= 61 && code <= 67) return 'باراناوی';
    if (code >= 71 && code <= 77) return 'بەفربارین';
    if (code >= 80 && code <= 82) return 'بارانی بەلێزمە';
    if (code == 85 || code == 86) return 'بەفری زۆر';
    if (code >= 95 && code <= 99) return 'هەورەبروسکە و زریان';
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

  List<double> _calculateMovingAverage(List<double> data, int windowSize) {
    if (data.isEmpty) return [];
    List<double> ma = [];
    for (int i = 0; i < data.length; i++) {
      int start = max(0, i - windowSize ~/ 2);
      int end = min(data.length - 1, i + windowSize ~/ 2);
      double sum = 0.0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        sum += data[j];
        count++;
      }
      ma.add(count > 0 ? (sum / count) : data[i]);
    }
    return ma;
  }

  void _showDetailedAIReportDialog(BuildContext context, WeatherModel data) {
    final int totalDays = min(6, data.times.length);
    final bool isDark = _isDarkMode;
    final Color iosCardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.65);
    final Color iosBorderColor = _iosGlassBorder;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: iosBorderColor, width: 1.5),
                    boxShadow: _neuShadows,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _purple.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.sparkles,
                                    color: _purple,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ڕاپۆرتی کەشوهەوا ($_cityName)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                    color: _darkText,
                                  ),
                                ),
                              ],
                            ),
                            PressableCard(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: _darkText,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(totalDays, (i) {
                          final String dayName = _getKurdishDayName(
                            data.times[i],
                          );
                          final String date = data.times[i];
                          final dynamic maxT = data.maxTemps[i];
                          final dynamic minT = data.minTemps[i];
                          final int weatherCode = data.weatherCodes.length > i
                              ? data.weatherCodes[i]
                              : 0;

                          final double tempSun = maxT is num
                              ? maxT.toDouble()
                              : 35.0;
                          final double tempShadow = tempSun - 3.5;

                          return PressableCard(
                            onTap: () {},
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: iosCardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: iosBorderColor),
                                boxShadow: _neuShadowsSmall,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          _buildWeatherVisualIcon(
                                            weatherCode,
                                            1,
                                            size: 34,
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dayName,
                                                style: TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: _darkText,
                                                ),
                                              ),
                                              Text(
                                                date,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _getWeatherDescription(weatherCode),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: _purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Divider(color: iosBorderColor, height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildIosReportStat(
                                        icon: CupertinoIcons.sun_max,
                                        iconColor: Colors.amber,
                                        title: 'لە بەرخۆر',
                                        value: '${tempSun.toStringAsFixed(1)}°',
                                      ),
                                      _buildIosReportStat(
                                        icon: CupertinoIcons.tree,
                                        iconColor: Colors.teal,
                                        title: 'لە سێبەر',
                                        value:
                                            '${tempShadow.toStringAsFixed(1)}°',
                                      ),
                                      _buildIosReportStat(
                                        icon: CupertinoIcons.snow,
                                        iconColor: Colors.blueAccent,
                                        title: 'نزمترین',
                                        value: '${minT?.round() ?? 0}°',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRainReportDialog(BuildContext context, WeatherModel data) {
    final int totalDays = min(6, data.times.length);
    final bool isDark = _isDarkMode;
    final Color iosCardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.65);
    final Color iosBorderColor = _iosGlassBorder;

    double sumTotalRain = 0.0;
    double sumTotalSnow = 0.0;

    for (int i = 0; i < totalDays; i++) {
      if (data.precipitationSums.length > i) {
        sumTotalRain += data.precipitationSums[i];
      }
      if (data.snowfallSums.length > i) {
        sumTotalSnow += data.snowfallSums[i];
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: iosBorderColor, width: 1.5),
                      boxShadow: _neuShadows,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.drop,
                                    color: Colors.blueAccent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'پێشبینی باران و بەفر',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                    color: _darkText,
                                  ),
                                ),
                              ],
                            ),
                            PressableCard(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: _darkText,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: totalDays,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final String dayName = _getKurdishDayName(
                                data.times[i],
                              );
                              final String date = data.times[i].split('T')[0];
                              final dynamic rainAmount =
                                  data.precipitationSums.length > i
                                  ? data.precipitationSums[i]
                                  : 0.0;
                              final dynamic snowAmount =
                                  data.snowfallSums.length > i
                                  ? data.snowfallSums[i]
                                  : 0.0;
                              final dynamic rainProb =
                                  data.precipitationProbabilities.length > i
                                  ? data.precipitationProbabilities[i]
                                  : 0;

                              return PressableCard(
                                onTap: () {},
                                child: Container(
                                  width: 110,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: iosCardBg,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: iosBorderColor),
                                    boxShadow: _neuShadowsSmall,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        children: [
                                          Text(
                                            dayName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: _darkText,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            date,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '$rainProb٪',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                CupertinoIcons.drop,
                                                size: 14,
                                                color: Colors.blueAccent,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$rainAmount مم',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: _darkText,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                CupertinoIcons.snow,
                                                size: 14,
                                                color: Colors.lightBlueAccent,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$snowAmount سم',
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
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                                : Colors.blue.shade50.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.chart_bar_alt_fill,
                                    color: Colors.blueAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'کۆی گشتی پێشبینیکراوی ($totalDays ڕۆژ)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: _darkText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: iosCardBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: iosBorderColor,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'کۆی باران',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _secondaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${sumTotalRain.toStringAsFixed(1)} مم',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.blueAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: iosCardBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: iosBorderColor,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'کۆی بەفر',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _secondaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${sumTotalSnow.toStringAsFixed(1)} سم',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.lightBlueAccent
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIosReportStat({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _secondaryText,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEarthquakeReportDialog(BuildContext context) {
    int selectedFilter = 0;
    final MapController mapController = MapController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final double dialogHeight = MediaQuery.of(context).size.height * 0.76;
        final bool isDark = _isDarkMode;
        final Color iosCardBg = isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.65);
        final Color iosBorderColor = _iosGlassBorder;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      height: dialogHeight,
                      width: double.maxFinite,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: iosBorderColor, width: 1.5),
                        boxShadow: _neuShadows,
                      ),
                      child: FutureBuilder<List<EarthquakeModel>>(
                        future: _earthquakeData,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CupertinoActivityIndicator(radius: 16),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'هەڵە لە وەرگرتنی داتای بومەلەرزە: هێڵی ئینتەرنێت نییە.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _darkText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          final allEarthquakes = snapshot.data ?? [];
                          final now = DateTime.now();

                          final thisMonthEarthquakes = allEarthquakes.where((
                            eq,
                          ) {
                            try {
                              final eqTime = DateTime.parse(eq.time);
                              return eqTime.year == now.year &&
                                  eqTime.month == now.month;
                            } catch (_) {
                              return true;
                            }
                          }).toList();

                          final displayedEarthquakes = thisMonthEarthquakes
                              .where((eq) {
                                if (selectedFilter == 0) {
                                  final distance =
                                      Geolocator.distanceBetween(
                                        _latitude,
                                        _longitude,
                                        eq.lat,
                                        eq.lon,
                                      ) /
                                      1000;
                                  return distance <= 250;
                                } else {
                                  final p = eq.place.toLowerCase();
                                  return p.contains('iraq') ||
                                      p.contains('kurdistan') ||
                                      (eq.lat >= 29.0 &&
                                          eq.lat <= 38.0 &&
                                          eq.lon >= 38.5 &&
                                          eq.lon <= 49.0);
                                }
                              })
                              .toList();

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  bottom: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrangeAccent
                                                .withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.waveform_path_ecg,
                                            color: Colors.deepOrangeAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'بومەلەرزەکانی ئەم مانگە',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                            color: _darkText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    PressableCard(
                                      onTap: () => Navigator.pop(dialogContext),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white12
                                              : Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.xmark,
                                          color: _darkText,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: iosCardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: iosBorderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: PressableCard(
                                          onTap: () {
                                            setModalState(() {
                                              selectedFilter = 0;
                                            });
                                            mapController.move(
                                              LatLng(_latitude, _longitude),
                                              7.5,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selectedFilter == 0
                                                  ? Colors.deepOrangeAccent
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'ناوچەی $_cityName',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: selectedFilter == 0
                                                    ? Colors.white
                                                    : _secondaryText,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: PressableCard(
                                          onTap: () {
                                            setModalState(() {
                                              selectedFilter = 1;
                                            });
                                            mapController.move(
                                              const LatLng(34.0, 44.0),
                                              5.8,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selectedFilter == 1
                                                  ? Colors.deepOrangeAccent
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'سنوری عێراق و هەرێم',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: selectedFilter == 1
                                                    ? Colors.white
                                                    : _secondaryText,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    height: 145,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: iosBorderColor),
                                    ),
                                    child: FlutterMap(
                                      mapController: mapController,
                                      options: MapOptions(
                                        initialCenter: selectedFilter == 0
                                            ? LatLng(_latitude, _longitude)
                                            : const LatLng(35.0, 44.5),
                                        initialZoom: selectedFilter == 0
                                            ? 7.5
                                            : 5.8,
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
                                              point: LatLng(
                                                _latitude,
                                                _longitude,
                                              ),
                                              width: 28,
                                              height: 28,
                                              child: const Icon(
                                                CupertinoIcons.location_fill,
                                                color: Colors.blueAccent,
                                                size: 22,
                                              ),
                                            ),
                                            ...displayedEarthquakes.map((eq) {
                                              return Marker(
                                                point: LatLng(eq.lat, eq.lon),
                                                width: 32,
                                                height: 32,
                                                child: const Icon(
                                                  CupertinoIcons
                                                      .waveform_circle_fill,
                                                  color:
                                                      Colors.deepOrangeAccent,
                                                  size: 26,
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: displayedEarthquakes.isEmpty
                                    ? Center(
                                        child: Text(
                                          'هیچ بومەلەرزەیەک بۆ ئەم مانگە تۆمار نەکراوە.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _secondaryText,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        itemCount: displayedEarthquakes.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 6),
                                        itemBuilder: (context, index) {
                                          final eq =
                                              displayedEarthquakes[index];
                                          return PressableCard(
                                            onTap: () {
                                              mapController.move(
                                                LatLng(eq.lat, eq.lon),
                                                8.5,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: iosCardBg,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: iosBorderColor,
                                                ),
                                                boxShadow: _neuShadowsSmall,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: FutureBuilder<String>(
                                                          future:
                                                              _getRealMapLocationName(
                                                                eq.lat,
                                                                eq.lon,
                                                                eq.place,
                                                              ),
                                                          builder: (context, snap) {
                                                            return Text(
                                                              snap.data ??
                                                                  _translateEarthquakePlace(
                                                                    eq.place,
                                                                  ),
                                                              style: TextStyle(
                                                                fontSize: 13.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color:
                                                                    _darkText,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 7,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .deepOrangeAccent
                                                              .withValues(
                                                                alpha: 0.18,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'گوڕ: ${eq.mag} ڕێختەر',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: Colors
                                                                .deepOrangeAccent,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'قوڵی: ${eq.depth.toStringAsFixed(1)} کم',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors
                                                              .redAccent
                                                              .shade400,
                                                        ),
                                                      ),
                                                      Text(
                                                        eq.time,
                                                        textDirection:
                                                            TextDirection.ltr,
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: _secondaryText,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
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

    if (matchedIndices.isEmpty) {
      matchedIndices = List.generate(
        min(24, data.hourlyTimes.length),
        (i) => i,
      );
    }

    double totalRain = 0.0;
    double totalSnow = 0.0;
    double maxWind = 0.0;
    int avgHumidity = 0;

    for (int idx in matchedIndices) {
      if (data.hourlyPrecipitations.length > idx) {
        totalRain += data.hourlyPrecipitations[idx];
      }
      if (data.hourlyWindSpeeds.length > idx &&
          data.hourlyWindSpeeds[idx] > maxWind) {
        maxWind = data.hourlyWindSpeeds[idx];
      }
      if (data.hourlyHumidities.length > idx) {
        avgHumidity += data.hourlyHumidities[idx];
      }
    }
    if (matchedIndices.isNotEmpty) {
      avgHumidity = (avgHumidity / matchedIndices.length).round();
    }

    int dayIdx = data.times.indexOf(searchDate);
    if (dayIdx != -1 && data.snowfallSums.length > dayIdx) {
      totalSnow = data.snowfallSums[dayIdx];
    }

    final bool isDark = _isDarkMode;
    final Color iosCardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.65);
    final Color iosBorderColor = _iosGlassBorder;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: iosBorderColor, width: 1.5),
                      boxShadow: _neuShadows,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              PressableCard(
                                onTap: () => Navigator.pop(dialogContext),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.xmark,
                                    color: _darkText,
                                    size: 16,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_cityName — $dayName',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                        color: _darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      date,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 28),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Weather Banner
                          PressableCard(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: iosCardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: iosBorderColor),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildWeatherVisualIcon(
                                    weatherCode,
                                    1,
                                    size: 38,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${maxT?.round() ?? 0}°',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: _darkText,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 18,
                                    width: 1.2,
                                    color: _secondaryText.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _getWeatherDescription(weatherCode),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _purple,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '(${minT?.round() ?? 0}° / ${maxT?.round() ?? 0}°)',
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Hourly Prediction Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: iosCardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: iosBorderColor),
                              boxShadow: _neuShadowsSmall,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.time,
                                      size: 16,
                                      color: _secondaryText,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'پێشبینی کاتژمێری',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: _secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(color: iosBorderColor, height: 1),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 96,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: matchedIndices.length,
                                    separatorBuilder: (context, i) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final realIdx = matchedIndices[index];
                                      final String fullTime =
                                          data.hourlyTimes[realIdx];
                                      final String timeOnly =
                                          fullTime.contains('T')
                                          ? fullTime
                                                .split('T')[1]
                                                .substring(0, 5)
                                          : fullTime;

                                      String formattedTime12 = timeOnly;
                                      int hour24 = 0;
                                      try {
                                        hour24 = int.parse(
                                          timeOnly.split(':')[0],
                                        );
                                        String period = hour24 >= 12
                                            ? 'پ.ن'
                                            : 'ب';
                                        int hour12 = hour24 % 12;
                                        if (hour12 == 0) hour12 = 12;
                                        formattedTime12 = '$hour12 $period';
                                      } catch (_) {}

                                      final double temp =
                                          data.hourlyTemperatures[realIdx];
                                      final int hCode =
                                          data.hourlyWeatherCodes[realIdx];
                                      final int isDayTime =
                                          (hour24 >= 6 && hour24 < 19) ? 1 : 0;

                                      return PressableCard(
                                        onTap: () {},
                                        child: Container(
                                          width: 52,
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                formattedTime12,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: _darkText,
                                                ),
                                              ),
                                              _buildWeatherVisualIcon(
                                                hCode,
                                                isDayTime,
                                                size: 26,
                                              ),
                                              Text(
                                                '${temp.round()}°',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: _darkText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Centered Grid Info Cards
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.35,
                            children: [
                              _buildIosInfoCard(
                                title: 'بارانبارین',
                                value: '${totalRain.toStringAsFixed(1)} مم',
                                subtitle: 'بڕی پێشبینیکراو بۆ ئەمڕۆ',
                                icon: CupertinoIcons.drop,
                                iconColor: Colors.blueAccent,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosInfoCard(
                                title: 'بڕی بەفر',
                                value: '${totalSnow.toStringAsFixed(1)} سم',
                                subtitle: 'کۆی بەفربارینی ڕۆژەکە',
                                icon: CupertinoIcons.snow,
                                iconColor: Colors.lightBlueAccent,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosInfoCard(
                                title: 'خێرایی با',
                                value: '${maxWind.round()} کم/س',
                                subtitle: 'بەرزترین کاتی هەڵکردن',
                                icon: CupertinoIcons.wind,
                                iconColor: Colors.tealAccent.shade700,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosInfoCard(
                                title: 'شێی هەوا',
                                value: '%$avgHumidity',
                                subtitle: 'تێکڕای ڕێژەی شێ',
                                icon: CupertinoIcons.circle_grid_hex,
                                iconColor: Colors.cyan,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIosInfoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    return PressableCard(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: _neuShadowsSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeuContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double radius = 20,
    Color? customColor,
  }) {
    final bool isDark = _isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                customColor ??
                (isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _iosGlassBorder, width: 1.2),
            boxShadow: _neuShadows,
          ),
          child: child,
        ),
      ),
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
    return PressableCard(
      onTap: () {},
      child: _buildNeuContainer(
        radius: 14,
        customColor: cardColor,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: _darkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: PressableCard(
        onTap: onTap,
        child: _buildNeuContainer(
          radius: 16,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: _darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: _buildNeuContainer(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.destructiveRed.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.wifi_slash,
                  size: 40,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هێڵی ئینتەرنێتت نییە یان زۆر خاوە!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تکایە پەیوەندی هێڵی ئینتەرنێتەکەت (Wi-Fi یان داتا) بپشکنە و دووبارە تاقی بکەرەوە.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: _secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              PressableCard(
                onTap: () {
                  setState(() {
                    _weatherData = _loadWeatherForCoordinates(
                      _latitude,
                      _longitude,
                    );
                    _earthquakeData = EarthquakeService.getRecentEarthquakes();
                  });
                  _fetchElevation(_latitude, _longitude);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        CupertinoIcons.refresh_bold,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'دووبارە هەوڵبدەرەوە',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _iosAtmosphereGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: FutureBuilder<WeatherModel>(
              future: _weatherData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CupertinoActivityIndicator(
                      radius: 18,
                      color: _purple,
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return _buildNetworkErrorState();
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

                    return SizedBox(
                      width: double.infinity,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: wideScreen ? 20 : 12,
                          vertical: 10,
                        ),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: PressableCard(
                                  onTap: () =>
                                      _showLocationSearchDialog(context),
                                  child: _buildNeuContainer(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    radius: 16,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
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
                                            CupertinoIcons.location_solid,
                                            color: CupertinoColors.systemRed,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _cityName,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              letterSpacing: -0.3,
                                              color: _darkText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          CupertinoIcons
                                              .chevron_up_chevron_down,
                                          size: 14,
                                          color: _secondaryText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PressableCard(
                                    onTap: () =>
                                        _showFullscreenMapDialog(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: _isDarkMode
                                            ? const Color(
                                                0xFF1E293B,
                                              ).withValues(alpha: 0.6)
                                            : Colors.white.withValues(
                                                alpha: 0.65,
                                              ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _iosGlassBorder,
                                        ),
                                        boxShadow: _neuShadowsSmall,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.map_fill,
                                        color: Colors.blueAccent,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  PressableCard(
                                    onTap: () {
                                      setState(() {
                                        _isDarkMode = !_isDarkMode;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: _isDarkMode
                                            ? const Color(
                                                0xFF1E293B,
                                              ).withValues(alpha: 0.6)
                                            : Colors.white.withValues(
                                                alpha: 0.65,
                                              ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _iosGlassBorder,
                                        ),
                                        boxShadow: _neuShadowsSmall,
                                      ),
                                      child: Icon(
                                        _isDarkMode
                                            ? CupertinoIcons.moon_stars_fill
                                            : CupertinoIcons.sun_max_fill,
                                        color: _isDarkMode
                                            ? Colors.amber
                                            : _purple,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  PressableCard(
                                    onTap: () =>
                                        _showSeaLevelDetailsDialog(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: _isDarkMode
                                            ? const Color(
                                                0xFF1E293B,
                                              ).withValues(alpha: 0.6)
                                            : Colors.white.withValues(
                                                alpha: 0.65,
                                              ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _iosGlassBorder,
                                        ),
                                        boxShadow: _neuShadowsSmall,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.compass,
                                        color: Colors.teal,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Top Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: CupertinoIcons.thermometer_sun,
                                  iconColor: CupertinoColors.systemRed,
                                  cardColor: _isDarkMode
                                      ? const Color(
                                          0xFF1E293B,
                                        ).withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.6),
                                  title: 'بەرزترین',
                                  value: '${todayMax.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: CupertinoIcons.snow,
                                  iconColor: Colors.blueAccent,
                                  cardColor: _isDarkMode
                                      ? const Color(
                                          0xFF1E293B,
                                        ).withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.6),
                                  title: 'نزمترین',
                                  value: '${todayMin.round()}°',
                                  wideScreen: wideScreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: CupertinoIcons.drop,
                                  iconColor: Colors.cyan,
                                  cardColor: _isDarkMode
                                      ? const Color(
                                          0xFF1E293B,
                                        ).withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.6),
                                  title: 'باران',
                                  value:
                                      '${todayRainSum.toStringAsFixed(1)} مم',
                                  wideScreen: wideScreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Chart Container
                          Builder(
                            builder: (context) {
                              final int hourlyCount = min(
                                24,
                                data.hourlyTemperatures.length,
                              );
                              final List<double> rawTemps = data
                                  .hourlyTemperatures
                                  .take(hourlyCount)
                                  .toList();
                              final List<double> rawRains =
                                  (data.hourlyPrecipitations.isNotEmpty
                                          ? data.hourlyPrecipitations
                                          : List.filled(hourlyCount, 0.0))
                                      .take(hourlyCount)
                                      .map((e) => (e as num).toDouble())
                                      .toList();

                              final List<double> maTemps =
                                  _calculateMovingAverage(rawTemps, 3);
                              final List<double> maRains =
                                  _calculateMovingAverage(rawRains, 3);

                              final int currentHour = DateTime.now().hour;
                              final bool isCurrentlyDay =
                                  currentHour >= 6 && currentHour < 19;

                              return _buildNeuContainer(
                                radius: 20,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            _buildWeatherVisualIcon(
                                              0,
                                              isCurrentlyDay ? 1 : 0,
                                              size: 26,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isCurrentlyDay
                                                  ? 'ئێستا: ڕۆژە'
                                                  : 'ئێستا: شەوە',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: _darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _purple.withValues(
                                              alpha: 0.18,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '٢٤ کاتژمێر',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: _purple,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 64,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: hourlyCount,
                                        itemBuilder: (context, index) {
                                          String fullTime =
                                              (data.hourlyTimes.isNotEmpty &&
                                                  data.hourlyTimes.length >
                                                      index)
                                              ? data.hourlyTimes[index]
                                              : '00:00';
                                          String timeOnly =
                                              fullTime.contains('T')
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
                                              ? 'د.ن'
                                              : 'ب';
                                          int hour12 = hour24 % 12;
                                          if (hour12 == 0) hour12 = 12;
                                          String formattedTime =
                                              '$hour12 $period';
                                          int hCode =
                                              (data
                                                      .hourlyWeatherCodes
                                                      .isNotEmpty &&
                                                  data
                                                          .hourlyWeatherCodes
                                                          .length >
                                                      index)
                                              ? data.hourlyWeatherCodes[index]
                                              : 0;
                                          int isDayTime =
                                              (hour24 >= 6 && hour24 < 19)
                                              ? 1
                                              : 0;
                                          double currentMaTemp =
                                              maTemps.length > index
                                              ? maTemps[index]
                                              : (rawTemps.length > index
                                                    ? rawTemps[index]
                                                    : 0.0);

                                          return PressableCard(
                                            onTap: () {},
                                            child: Container(
                                              width: 48,
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    formattedTime,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _secondaryText,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  _buildWeatherVisualIcon(
                                                    hCode,
                                                    isDayTime,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${currentMaTemp.round()}°',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: _darkText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Chart
                                    SizedBox(
                                      height: 58,
                                      child: LineChart(
                                        LineChartData(
                                          minX: 0,
                                          maxX: (hourlyCount - 1)
                                              .toDouble()
                                              .clamp(0.0, 23.0),
                                          minY: 0,
                                          maxY: 45,
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: true,
                                            getDrawingHorizontalLine: (value) =>
                                                FlLine(
                                                  color: _secondaryText
                                                      .withValues(alpha: 0.08),
                                                  strokeWidth: 1,
                                                ),
                                            getDrawingVerticalLine: (value) =>
                                                FlLine(
                                                  color: _secondaryText
                                                      .withValues(alpha: 0.08),
                                                  strokeWidth: 1,
                                                ),
                                          ),
                                          titlesData: const FlTitlesData(
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
                                                hourlyCount,
                                                (i) {
                                                  double temp = maTemps[i];
                                                  double mappedY =
                                                      18.0 +
                                                      (temp - 15.0) * 0.7;
                                                  return FlSpot(
                                                    i.toDouble(),
                                                    mappedY.clamp(12.0, 42.0),
                                                  );
                                                },
                                              ),
                                              isCurved: true,
                                              curveSmoothness: 0.35,
                                              color: Colors.orange,
                                              barWidth: 2.2,
                                              isStrokeCapRound: true,
                                              dotData: FlDotData(
                                                show: true,
                                                getDotPainter:
                                                    (
                                                      spot,
                                                      percent,
                                                      bar,
                                                      index,
                                                    ) {
                                                      return FlDotCirclePainter(
                                                        radius: 1.5,
                                                        color: Colors.white,
                                                        strokeWidth: 1.2,
                                                        strokeColor:
                                                            Colors.orange,
                                                      );
                                                    },
                                              ),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.orange.withValues(
                                                      alpha: 0.2,
                                                    ),
                                                    Colors.orange.withValues(
                                                      alpha: 0.0,
                                                    ),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                              ),
                                            ),
                                            LineChartBarData(
                                              spots: List.generate(
                                                hourlyCount,
                                                (i) {
                                                  double temp = maTemps[i];
                                                  double lowEstimate =
                                                      temp - 4.5;
                                                  double mappedY =
                                                      18.0 +
                                                      (lowEstimate - 15.0) *
                                                          0.7;
                                                  return FlSpot(
                                                    i.toDouble(),
                                                    mappedY.clamp(6.0, 36.0),
                                                  );
                                                },
                                              ),
                                              isCurved: true,
                                              curveSmoothness: 0.35,
                                              color: Colors.tealAccent.shade400,
                                              barWidth: 1.8,
                                              isStrokeCapRound: true,
                                              dotData: FlDotData(
                                                show: true,
                                                getDotPainter:
                                                    (
                                                      spot,
                                                      percent,
                                                      bar,
                                                      index,
                                                    ) {
                                                      return FlDotCirclePainter(
                                                        radius: 1.2,
                                                        color: Colors.white,
                                                        strokeWidth: 1.0,
                                                        strokeColor: Colors
                                                            .tealAccent
                                                            .shade400,
                                                      );
                                                    },
                                              ),
                                              belowBarData: BarAreaData(
                                                show: false,
                                              ),
                                            ),
                                            LineChartBarData(
                                              spots: List.generate(
                                                hourlyCount,
                                                (i) {
                                                  double rain = maRrains(
                                                    maRains,
                                                    i,
                                                  );
                                                  double mappedY = (rain * 5.0)
                                                      .clamp(0.0, 22.0);
                                                  return FlSpot(
                                                    i.toDouble(),
                                                    mappedY,
                                                  );
                                                },
                                              ),
                                              isCurved: true,
                                              curveSmoothness: 0.25,
                                              color: const Color(0xFF38BDF8),
                                              barWidth: 2.0,
                                              isStrokeCapRound: true,
                                              dotData: FlDotData(
                                                show: true,
                                                getDotPainter:
                                                    (
                                                      spot,
                                                      percent,
                                                      bar,
                                                      index,
                                                    ) {
                                                      return FlDotCirclePainter(
                                                        radius: spot.y > 0
                                                            ? 1.8
                                                            : 0,
                                                        color: Colors.white,
                                                        strokeWidth: 1.2,
                                                        strokeColor:
                                                            const Color(
                                                              0xFF38BDF8,
                                                            ),
                                                      );
                                                    },
                                              ),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(
                                                      0xFF38BDF8,
                                                    ).withValues(alpha: 0.25),
                                                    const Color(
                                                      0xFF38BDF8,
                                                    ).withValues(alpha: 0.01),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'گەرمی',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.tealAccent.shade400,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'نزمی',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF38BDF8),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'باران',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Divider(
                                      color: _secondaryText.withValues(
                                        alpha: 0.15,
                                      ),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.sunrise,
                                              color: Colors.amber,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'خۆرهەڵاتن: ${sunTimes['sunrise'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: _darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          height: 16,
                                          width: 1.2,
                                          color: _secondaryText.withValues(
                                            alpha: 0.25,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.sunset,
                                              color: Colors.deepOrange,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'خۆرئاوا: ${sunTimes['sunset'] ?? ''}',
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
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Action Cards
                          Row(
                            children: [
                              _buildActionCard(
                                title: 'کەشوهەوا',
                                icon: CupertinoIcons.sparkles,
                                color: _purple,
                                onTap: () =>
                                    _showDetailedAIReportDialog(context, data),
                              ),
                              const SizedBox(width: 8),
                              _buildActionCard(
                                title: 'بڕی باران',
                                icon: CupertinoIcons.drop,
                                color: Colors.blueAccent,
                                onTap: () =>
                                    _showRainReportDialog(context, data),
                              ),
                              const SizedBox(width: 8),
                              _buildActionCard(
                                title: 'بومەلەرزە',
                                icon: CupertinoIcons.waveform_path_ecg,
                                color: Colors.deepOrangeAccent,
                                onTap: () =>
                                    _showEarthquakeReportDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 6 Days Forecast List
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
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: PressableCard(
                                onTap: () => _showDayDetailDialog(
                                  context,
                                  date,
                                  maxT,
                                  minT,
                                  code,
                                  data,
                                ),
                                child: _buildNeuContainer(
                                  radius: 18,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  customColor: cardTint,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          AnimatedBuilder(
                                            animation: _rotateAnimation,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle: _rotateAnimation.value,
                                                child: child,
                                              );
                                            },
                                            child: _buildWeatherVisualIcon(
                                              code,
                                              1,
                                              size: 34,
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
                                                  fontSize: 16.5,
                                                  letterSpacing: -0.3,
                                                  color: _darkText,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                date,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                  color: _secondaryText
                                                      .withValues(alpha: 0.9),
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
                                                  fontSize: 15.5,
                                                  letterSpacing: -0.3,
                                                  color: _darkText,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _getWeatherDescription(code),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: _secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 10),
                                          AnimatedBuilder(
                                            animation: _rotateAnimation,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle:
                                                    _rotateAnimation.value * 2,
                                                child: child,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: _purple.withValues(
                                                  alpha: 0.15,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                CupertinoIcons
                                                    .hand_point_left_fill,
                                                size: 15,
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
                          const SizedBox(height: 12),

                          // Air Quality Banner Card
                          _buildAirQualityImageBannerCard(),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '     programmer: Zheer T Mastakany ©2026  ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: _darkText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double maRrains(List<double> list, int i) => list.length > i ? list[i] : 0.0;
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
  final List<double> snowfallSums;

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
    required this.snowfallSums,
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
      snowfallSums: parseDoubleList(daily['snowfall_sum']),
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
