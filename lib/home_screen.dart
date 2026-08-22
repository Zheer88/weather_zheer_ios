import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'earthquake_service.dart';
import 'location_weather_service.dart';
import 'models/earthquake_model.dart';

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

  final MapController _fullscreenMapController = MapController();

  double _latitude = 35.5558;
  double _longitude = 45.4351;
  double _elevation = 850.0;

  String _cityName = 'سلێمانی';
  String _mapLayerType = 'normal';

  Color get _background =>
      _isDarkMode ? const Color(0xFF1E242D) : const Color(0xFFE0E5EC);
  Color get _darkText =>
      _isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF182333);
  Color get _secondaryText =>
      _isDarkMode ? const Color(0xFFA0AEC0) : const Color(0xFF718096);
  Color get _purple =>
      _isDarkMode ? const Color(0xFF9F7AEA) : const Color(0xFF6C5CE7);

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
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mapIconBounceAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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
      distanceFilter: 0,
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

  Future<Map<String, dynamic>?> _fetchAirQualityData(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone&timezone=auto',
      );
      final response = await http.get(url);
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
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.zheer.weatherapp'},
      );
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
        'status': 'پاک',
        'color': const Color(0xFF4ADE80),
        'desc': 'کوالێتی هەوا زۆر باشە و هیچ مەترسییەکی تەندروستی نییە.',
      };
    } else if (aqi <= 100) {
      return {
        'status': 'ئاسایی',
        'color': const Color(0xFFFBBF24),
        'desc':
            'کوالێتی هەوا پەسەندە، بەڵام بۆ کەسانی هەستیار کاریگەری کەم دەبێت.',
      };
    } else if (aqi <= 150) {
      return {
        'status': 'ناپاکی بۆ هەستیار',
        'color': const Color(0xFFF97316),
        'desc': 'کەسانی خاوەن نەخۆشییەکانی هەناسە و منداڵان دەبێت ئاگاداربن.',
      };
    } else if (aqi <= 200) {
      return {
        'status': 'ناپاک',
        'color': const Color(0xFFEF4444),
        'desc':
            'هەموو کەسێک لەوانەیە هەست بە کاریگەرییە نەرێنییەکانی هەوا بکات.',
      };
    } else {
      return {
        'status': 'مەترسیدار',
        'color': const Color(0xFFDC2626),
        'desc':
            'ئاگاداری تەندروستی گشتی، هەوای دەرەوە بە تەواوی پیس و ژەهراوییە.',
      };
    }
  }

  void _showAirQualityDialog(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color iosCardBg = isDark
        ? const Color(0xFF1E2638).withValues(alpha: 0.85)
        : const Color(0xFFE2EAF4).withValues(alpha: 0.95);
    final Color iosBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF161E2E), const Color(0xFF0F172A)]
                      : [const Color(0xFFE9F1FA), const Color(0xFFD5E3F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: iosBorderColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchAirQualityData(_latitude, _longitude),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.cyan),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data == null) {
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'داتای جۆری و کوالێتیی هەوا بۆ ئەم ناوچەیە لە بارکردندایە',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(
                                'داخستن',
                                style: TextStyle(
                                  color: _purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.air_rounded,
                                    color: Colors.cyan,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'کوالێتیی هەوا — $_cityName',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: _darkText,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
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
                                    Icons.close_rounded,
                                    color: _darkText,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: iosCardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: iosBorderColor),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$usAqi',
                                          style: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w900,
                                            color: statusColor,
                                            height: 1.1,
                                          ),
                                        ),
                                        Text(
                                          'ئاستی ڕاستەقینە',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        statusInfo['status'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(color: iosBorderColor, height: 1),
                                const SizedBox(height: 10),
                                Text(
                                  statusInfo['desc'] as String,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    fontWeight: FontWeight.w700,
                                    color: _darkText.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.35,
                            children: [
                              _buildIosAirQualityGridItem(
                                title: 'تەنی زیانبەخش',
                                value: '$pm25',
                                unit: 'مایکروگرام',
                                icon: Icons.grain_rounded,
                                iconColor: Colors.deepOrangeAccent,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosAirQualityGridItem(
                                title: 'تۆز و گەردیلە',
                                value: '$pm10',
                                unit: 'مایکروگرام',
                                icon: Icons.blur_on_rounded,
                                iconColor: Colors.amber.shade800,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosAirQualityGridItem(
                                title: 'گازی ئۆزۆن',
                                value: '$o3',
                                unit: 'مایکروگرام',
                                icon: Icons.wb_sunny_outlined,
                                iconColor: Colors.blueAccent,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosAirQualityGridItem(
                                title: 'نایترۆجین',
                                value: '$no2',
                                unit: 'مایکروگرام',
                                icon: Icons.science_outlined,
                                iconColor: Colors.purpleAccent,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosAirQualityGridItem(
                                title: 'کاربۆن مۆنۆکسید',
                                value: '$co',
                                unit: 'مایکروگرام',
                                icon: Icons.cloud_outlined,
                                iconColor: Colors.teal,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
                              ),
                              _buildIosAirQualityGridItem(
                                title: 'دوانۆکسیدی گۆگرد',
                                value: '$so2',
                                unit: 'مایکروگرام',
                                icon: Icons.warning_amber_rounded,
                                iconColor: Colors.redAccent,
                                cardBg: iosCardBg,
                                borderColor: iosBorderColor,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _darkText,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _secondaryText,
                ),
              ),
            ],
          ),
        ],
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

        return Directionality(
          textDirection: TextDirection.rtl,
          child: GestureDetector(
            onTap: () => _showAirQualityDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? const Color(0xFF1E252D)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: _neuShadowsSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            color: Color(0xFF4ADE80),
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'کوالێتی هەوا: $_cityName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
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
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          statusName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'بارودۆخ: $statusName',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            'ڕێژە: $aqi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) {
                          final bool isActive = aqi >= (index * 50);
                          Color segColor = const Color(0xFF4ADE80);
                          if (index == 1) segColor = const Color(0xFFFBBF24);
                          if (index == 2) segColor = const Color(0xFFF97316);
                          if (index == 3 || index == 4) {
                            segColor = const Color(0xFFEF4444);
                          }

                          return Expanded(
                            child: Container(
                              height: 10,
                              margin: EdgeInsets.only(
                                right: index == 0 ? 0 : 3,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? segColor
                                    : (_isDarkMode
                                          ? Colors.black45
                                          : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${(index + 1) * 50}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isActive
                                      ? Colors.white
                                      : _secondaryText,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            '٠ پاک',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4ADE80),
                            ),
                          ),
                          Text(
                            '٥٠ ئاسایی',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                          Text(
                            '١٠٠ ناپاک',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          Text(
                            '٢٠٠+ مەترسیدار',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEF4444),
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
      _updateLiveElevationAndLocation(position);

      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _background,
            content: Text(
              'شوێنەکەت دۆزرایەوە: $_cityName',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _background,
            content: Text(
              errorMsg,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            duration: const Duration(seconds: 4),
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
        ? const Color(0xFF1E2638).withValues(alpha: 0.85)
        : const Color(0xFFE2EAF4).withValues(alpha: 0.95);
    final Color iosBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF161E2E), const Color(0xFF0F172A)]
                      : [const Color(0xFFE9F1FA), const Color(0xFFD5E3F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: iosBorderColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.terrain_rounded,
                                color: Colors.teal,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'وردەکاری ئاستی دەریا و بەرزی',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _darkText,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
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
                                Icons.close_rounded,
                                color: _darkText,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 180,
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
                                      Icons.location_pin,
                                      color: Colors.redAccent,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSeaLevelRow(
                        title: 'بەرزی لە ئاستی دەریا',
                        value: '${_elevation.toStringAsFixed(1)} مەتر',
                        icon: Icons.gps_fixed_rounded,
                        color: Colors.teal,
                        cardBg: iosCardBg,
                        borderColor: iosBorderColor,
                      ),
                      const SizedBox(height: 10),
                      _buildSeaLevelRow(
                        title: 'فشاری بەرگەهەوا',
                        value: '${seaLevelPressure.toStringAsFixed(1)} hPa',
                        icon: Icons.speed_rounded,
                        color: Colors.orangeAccent,
                        cardBg: iosCardBg,
                        borderColor: iosBorderColor,
                      ),
                      const SizedBox(height: 10),
                      _buildSeaLevelRow(
                        title: 'جیاوازی لەگەڵ ئاستی ئاسایی',
                        value:
                            '${elevationDiff >= 0 ? '+' : ''}${elevationDiff.toStringAsFixed(1)} مەتر',
                        icon: Icons.compare_arrows_rounded,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
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
    );
  }

  void _showFullscreenMapDialog(BuildContext context) {
    String mapSearchQuery = '';
    List<dynamic> mapSearchResults = [];
    bool isMapSearching = false;
    Timer? mapDebounce;
    final TextEditingController mapSearchController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
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
                  color: _background,
                  padding: const EdgeInsets.all(12),
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: _neuShadows,
                      ),
                      clipBehavior: Clip.antiAlias,
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
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                            Icons.location_pin,
                                            color: Colors.redAccent,
                                            size: 32,
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
                            child: GestureDetector(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _background,
                                  shape: BoxShape.circle,
                                  boxShadow: _neuShadowsSmall,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: _darkText,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _background.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: _neuShadowsSmall,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMapLayerButton(
                                    icon: Icons.play_circle_fill_rounded,
                                    label: '',
                                    type: 'animated',
                                    setStateDialog: setStateDialog,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildMapLayerButton(
                                    icon: Icons.satellite_alt_rounded,
                                    label: '',
                                    type: 'satellite',
                                    setStateDialog: setStateDialog,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildMapLayerButton(
                                    icon: Icons.touch_app_rounded,
                                    label: '',
                                    type: 'interactive',
                                    setStateDialog: setStateDialog,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildMapLayerButton(
                                    icon: Icons.thermostat_rounded,
                                    label: '',
                                    type: 'temp',
                                    setStateDialog: setStateDialog,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            top: 16,
                            left: 65,
                            right: 65,
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: _background.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _neuShadowsSmall,
                                  ),
                                  child: TextField(
                                    controller: mapSearchController,
                                    style: TextStyle(
                                      color: _darkText,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'گەران بۆ شار...',
                                      hintStyle: TextStyle(
                                        color: _secondaryText.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 14,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: _purple,
                                      ),
                                      suffixIcon: mapSearchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear_rounded,
                                                color: _secondaryText,
                                              ),
                                              onPressed: () {
                                                mapSearchController.clear();
                                                setStateDialog(() {
                                                  mapSearchQuery = '';
                                                  mapSearchResults = [];
                                                });
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                    ),
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        mapSearchQuery = value;
                                      });

                                      if (mapDebounce != null &&
                                          mapDebounce!.isActive) {
                                        mapDebounce!.cancel();
                                      }

                                      mapDebounce = Timer(
                                        const Duration(milliseconds: 800),
                                        () async {
                                          if (value.trim().isEmpty) {
                                            setStateDialog(() {
                                              mapSearchResults = [];
                                              isMapSearching = false;
                                            });
                                            return;
                                          }
                                          setStateDialog(() {
                                            isMapSearching = true;
                                          });
                                          final results =
                                              await _searchCityByName(value);
                                          setStateDialog(() {
                                            mapSearchResults = results;
                                            isMapSearching = false;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                                if (isMapSearching)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _background,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _neuShadowsSmall,
                                    ),
                                    child: CircularProgressIndicator(
                                      color: _purple,
                                    ),
                                  ),
                                if (!isMapSearching &&
                                    mapSearchResults.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                          0.4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _background.withValues(
                                        alpha: 0.95,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _neuShadowsSmall,
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: mapSearchResults.length,
                                      separatorBuilder: (context, index) =>
                                          Divider(
                                            color: _secondaryText.withValues(
                                              alpha: 0.2,
                                            ),
                                            height: 1,
                                          ),
                                      itemBuilder: (context, index) {
                                        final result = mapSearchResults[index];
                                        final fullName =
                                            result['display_name'] as String;
                                        final shortName =
                                            result['name'] as String? ??
                                            fullName.split(',').first;

                                        return ListTile(
                                          title: Text(
                                            shortName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
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
                                          onTap: () {
                                            final lat = double.parse(
                                              result['lat'].toString(),
                                            );
                                            final lon = double.parse(
                                              result['lon'].toString(),
                                            );

                                            // نوێکردنەوەی زانیارییەکان
                                            setState(() {
                                              _latitude = lat;
                                              _longitude = lon;
                                              _cityName = shortName;
                                              _weatherData =
                                                  _loadWeatherForCoordinates(
                                                    lat,
                                                    lon,
                                                  );
                                            });
                                            _fetchElevation(lat, lon);

                                            // بردنی نەخشەکە بۆ شوێنە نوێیەکە
                                            _fullscreenMapController.move(
                                              LatLng(lat, lon),
                                              10.0,
                                            );

                                            // خاوێنکردنەوەی گەڕان
                                            mapSearchController.clear();
                                            setStateDialog(() {
                                              mapSearchQuery = '';
                                              mapSearchResults = [];
                                            });
                                          },
                                        );
                                      },
                                    ),
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
      child: GestureDetector(
        onTap: () {
          setStateDialog(() {
            _mapLayerType = type;
          });
          setState(() {
            _mapLayerType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? _purple : _background,
            shape: BoxShape.circle,
            boxShadow: _neuShadowsSmall,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : _darkText,
            size: 22,
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

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            contentPadding: const EdgeInsets.all(20),
            titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            title: Row(
              children: [
                Icon(Icons.search_rounded, color: _purple, size: 28),
                const SizedBox(width: 10),
                Text(
                  'گەڕان بۆ ناوچەکان',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF252D38)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _neuShadowsSmall,
                        ),
                        child: TextField(
                          controller: searchController,
                          style: TextStyle(
                            color: _darkText,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ناوی شار یان وڵات بنووسە...',
                            hintStyle: TextStyle(
                              color: _secondaryText.withValues(alpha: 0.7),
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.location_city_rounded,
                              color: _secondaryText,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: _secondaryText,
                                    ),
                                    onPressed: () {
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
                              vertical: 18,
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
                              const Duration(milliseconds: 800),
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
                                final results = await _searchCityByName(value);
                                setStateDialog(() {
                                  searchResults = results;
                                  isSearching = false;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (searchQuery.isEmpty)
                        GestureDetector(
                          onTap: _isLocationLoading
                              ? null
                              : () async {
                                  Navigator.pop(dialogContext);
                                  await _getCurrentLocationAndWeather();
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _purple.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isLocationLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _purple,
                                        ),
                                      )
                                    : Icon(
                                        Icons.my_location_rounded,
                                        size: 24,
                                        color: _purple,
                                      ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _isLocationLoading
                                        ? 'لە دۆزینەوەی شوێن...'
                                        : 'دۆزینەوەی شوێنی ئێستام',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _purple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (searchQuery.isEmpty) const SizedBox(height: 24),
                      if (searchQuery.isEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'شارە باوەکان:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _secondaryText,
                            ),
                          ),
                        ),
                      if (searchQuery.isEmpty) const SizedBox(height: 12),
                      if (searchQuery.isEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.start,
                          children: [
                            _buildCityChip('سلێمانی', 35.5558, 45.4351),
                            _buildCityChip('هەولێر', 36.1901, 44.0091),
                            _buildCityChip('دهۆک', 36.8679, 42.9885),
                            _buildCityChip('هەڵەبجە', 35.1772, 45.9877),
                            _buildCityChip('کەرکووک', 35.4681, 44.3922),
                          ],
                        ),

                      if (searchQuery.isNotEmpty && isSearching)
                        const Padding(
                          padding: EdgeInsets.all(30.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      if (searchQuery.isNotEmpty &&
                          !isSearching &&
                          searchResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: Center(
                            child: Text(
                              'هیچ ناوچەیەک نەدۆزرایەوە',
                              style: TextStyle(
                                color: _secondaryText,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                      if (searchQuery.isNotEmpty &&
                          !isSearching &&
                          searchResults.isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            separatorBuilder: (context, index) => Divider(
                              color: _secondaryText.withValues(alpha: 0.1),
                            ),
                            itemBuilder: (context, index) {
                              final result = searchResults[index];
                              final fullName = result['display_name'] as String;
                              final shortName =
                                  result['name'] as String? ??
                                  fullName.split(',').first;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? const Color(0xFF252D38)
                                        : const Color(0xFFE8EEF5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.redAccent,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  shortName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: _darkText,
                                  ),
                                ),
                                subtitle: Text(
                                  fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _secondaryText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  setState(() {
                                    _latitude = double.parse(
                                      result['lat'].toString(),
                                    );
                                    _longitude = double.parse(
                                      result['lon'].toString(),
                                    );
                                    _cityName = shortName;
                                    _weatherData = _loadWeatherForCoordinates(
                                      _latitude,
                                      _longitude,
                                    );
                                  });
                                  _fetchElevation(_latitude, _longitude);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'داخستن',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 16,
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
        _fetchElevation(lat, lon);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _neuShadowsSmall,
        ),
        child: Text(
          name,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 16,
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
        if (displayH == 0) displayH = 12;
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

  IconData _getWeatherIcon(int code, int isDay) {
    if (code == 0) {
      return isDay == 1 ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
    if (code == 1) {
      return isDay == 1 ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
    }
    if (code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 57) return Icons.grain_rounded;
    if (code >= 61 && code <= 67) return Icons.umbrella_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
    if (code == 85 || code == 86) return Icons.ac_unit_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return isDay == 1 ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  }

  Color _getWeatherIconColor(int code, int isDay) {
    if (code == 0) {
      return isDay == 1 ? Colors.orangeAccent : Colors.indigoAccent;
    }
    if (code == 1 || code == 2 || code == 3) {
      return isDay == 1 ? Colors.blueGrey : Colors.indigo;
    }
    if (code >= 45 && code <= 48) return Colors.grey;
    if (code >= 51 && code <= 67) return Colors.blueAccent;
    if (code >= 71 && code <= 77) return Colors.lightBlueAccent;
    if (code >= 80 && code <= 82) return Colors.blueAccent;
    if (code == 85 || code == 86) return Colors.lightBlueAccent;
    if (code >= 95 && code <= 99) return Colors.deepPurpleAccent;
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

    if (code == 0) return const Color(0xFFF7F3EA);
    if (code >= 1 && code <= 3) return const Color(0xFFE8EEF3);
    if (code >= 45 && code <= 48) return const Color(0xFFECEFF1);
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
      return const Color(0xFFE3EDF6);
    }
    if (code >= 71 && code <= 77 || code == 85 || code == 86) {
      return const Color(0xFFEEF4F8);
    }
    if (code >= 95 && code <= 99) return const Color(0xFFEFEAF4);
    return _background;
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'ساماڵ و ڕووناک';
    if (code == 1) return 'کەمێک هەور';
    if (code == 2) return 'نیمچە هەور';
    if (code == 3) return 'هەوراوی';
    if (code >= 45 && code <= 48) return 'تەمومژاوی';
    if (code >= 51 && code <= 57) return 'بارانی سووک';
    if (code >= 61 && code <= 67) return 'باراناوی';
    if (code >= 71 && code <= 77) return 'بەفربارین';
    if (code >= 80 && code <= 82) return 'ڕەگبار';
    if (code == 85 || code == 86) return 'بەفری ڕەگبار';
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

  void _showDetailedAIReportDialog(BuildContext context, WeatherModel data) {
    final int totalDays = min(6, data.times.length);
    final bool isDark = _isDarkMode;
    final Color iosCardBg = isDark
        ? const Color(0xFF1E2638).withValues(alpha: 0.85)
        : const Color(0xFFE2EAF4).withValues(alpha: 0.95);
    final Color iosBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

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
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF161E2E), const Color(0xFF0F172A)]
                      : [const Color(0xFFE9F1FA), const Color(0xFFD5E3F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: iosBorderColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.psychology_rounded,
                                color: _purple,
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ڕاپۆرتی کەشوهەوا ($_cityName)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _darkText,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
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
                                Icons.close_rounded,
                                color: _darkText,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: iosCardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: iosBorderColor),
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
                                      Icon(
                                        _getWeatherIcon(weatherCode, 1),
                                        color: _getWeatherIconColor(
                                          weatherCode,
                                          1,
                                        ),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dayName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: _darkText,
                                            ),
                                          ),
                                          Text(
                                            date,
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
                                    icon: Icons.wb_sunny_rounded,
                                    iconColor: Colors.orangeAccent,
                                    title: 'لە بەرخۆر',
                                    value: '${tempSun.toStringAsFixed(1)} پلە',
                                  ),
                                  _buildIosReportStat(
                                    icon: Icons.park_rounded,
                                    iconColor: Colors.teal,
                                    title: 'لە سێبەر',
                                    value:
                                        '${tempShadow.toStringAsFixed(1)} پلە',
                                  ),
                                  _buildIosReportStat(
                                    icon: Icons.ac_unit_rounded,
                                    iconColor: Colors.blueAccent,
                                    title: 'نزمترین',
                                    value: '${minT?.round() ?? 0} پلە',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
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
        ? const Color(0xFF1E2638).withValues(alpha: 0.85)
        : const Color(0xFFE2EAF4).withValues(alpha: 0.95);
    final Color iosBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF161E2E), const Color(0xFF0F172A)]
                        : [const Color(0xFFE9F1FA), const Color(0xFFD5E3F4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.6 : 0.15,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: iosBorderColor, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.water_drop_rounded,
                                  color: Colors.blueAccent,
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'پێشبینی باران و بەفر',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: _darkText,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
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
                                  Icons.close_rounded,
                                  color: _darkText,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 175,
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

                              return Container(
                                width: 110,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: iosCardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: iosBorderColor),
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
                                          date.length > 5
                                              ? date.substring(5)
                                              : date,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
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
                                              Icons.water_drop_rounded,
                                              size: 14,
                                              color: Colors.blueAccent,
                                            ),
                                            const SizedBox(width: 2),
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
                                              Icons.ac_unit_rounded,
                                              size: 14,
                                              color: Colors.lightBlueAccent,
                                            ),
                                            const SizedBox(width: 2),
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
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF132038,
                                  ).withValues(alpha: 0.95)
                                : Colors.blue.shade50.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.analytics_rounded,
                                    color: Colors.blueAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'کۆی گشتی پێشبینیکراوی ($totalDays ڕۆژ)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _darkText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: _secondaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${sumTotalRain.toStringAsFixed(1)} ملم',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.blueAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: _secondaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${sumTotalSnow.toStringAsFixed(1)} سم',
                                            style: TextStyle(
                                              fontSize: 20,
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
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: Colors.greenAccent.shade700,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'سەرچاوە: Open-Meteo DWD / NOAA Global Models',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _secondaryText,
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

  ////============================================

  Widget _buildIosReportStat({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _secondaryText,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
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
                const Icon(
                  Icons.waves_rounded,
                  color: Colors.deepOrangeAccent,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'سەرچاوەی بومەلەرزە',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 19,
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
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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
                            fontSize: 16,
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
                          'بومەلەرزەکان لە هەرێمی کوردستان و عێراق (٤٨ سەعاتی ڕابردوو):',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
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
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: _darkText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...earthquakes.take(10).map((eq) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _background,
                                borderRadius: BorderRadius.circular(14),
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
                                            fontSize: 16,
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
                                          fontSize: 16,
                                          color: _darkText,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'بری گوڕ: ${eq.mag} ڕێختەر',
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'قوڵی: ${eq.depth.toStringAsFixed(1)} کم',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'کات و بەروار: ${eq.time}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
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
                    fontSize: 16,
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
        ? const Color(0xFF1E2638).withValues(alpha: 0.85)
        : const Color(0xFFE2EAF4).withValues(alpha: 0.95);
    final Color iosBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

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
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF161E2E), const Color(0xFF0F172A)]
                      : [const Color(0xFFE9F1FA), const Color(0xFFD5E3F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: iosBorderColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_cityName — $dayName',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _secondaryText,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
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
                                Icons.close_rounded,
                                color: _darkText,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          Icon(
                            _getWeatherIcon(weatherCode, 1),
                            color: _getWeatherIconColor(weatherCode, 1),
                            size: 60,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${maxT?.round() ?? 0}°',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: _darkText,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            _getWeatherDescription(weatherCode),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _secondaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'بەرزترین: ${maxT?.round() ?? 0}°  •  نزمترین: ${minT?.round() ?? 0}°',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _darkText.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: iosCardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: iosBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: _secondaryText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'پێشبینی کاتژمێری',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: _secondaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: iosBorderColor, height: 1),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: matchedIndices.length,
                                separatorBuilder: (context, i) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final realIdx = matchedIndices[index];
                                  final String fullTime =
                                      data.hourlyTimes[realIdx];
                                  final String timeOnly = fullTime.contains('T')
                                      ? fullTime.split('T')[1].substring(0, 5)
                                      : fullTime;

                                  String formattedTime12 = timeOnly;
                                  int hour24 = 0;
                                  try {
                                    hour24 = int.parse(timeOnly.split(':')[0]);
                                    String period = hour24 >= 12
                                        ? 'پاشنیوەڕۆ'
                                        : 'بەیانی';
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

                                  return Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formattedTime12,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: _darkText,
                                        ),
                                      ),
                                      Icon(
                                        _getWeatherIcon(hCode, isDayTime),
                                        color: _getWeatherIconColor(
                                          hCode,
                                          isDayTime,
                                        ),
                                        size: 28,
                                      ),
                                      Text(
                                        '${temp.round()}°',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: _darkText,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          _buildIosInfoCard(
                            title: 'بارانبارین',
                            value: '${totalRain.toStringAsFixed(1)} مم',
                            subtitle: 'بڕی پێشبینیکراو بۆ ئەمڕۆ',
                            icon: Icons.water_drop_rounded,
                            iconColor: Colors.blueAccent,
                            cardBg: iosCardBg,
                            borderColor: iosBorderColor,
                          ),
                          _buildIosInfoCard(
                            title: 'بڕی بەفر',
                            value: '${totalSnow.toStringAsFixed(1)} سم',
                            subtitle: 'کۆی بەفربارینی ڕۆژەکە',
                            icon: Icons.ac_unit_rounded,
                            iconColor: Colors.lightBlueAccent,
                            cardBg: iosCardBg,
                            borderColor: iosBorderColor,
                          ),
                          _buildIosInfoCard(
                            title: 'خێرایی با',
                            value: '${maxWind.round()} کم/س',
                            subtitle: 'بەرزترین کاتی هەڵکردن',
                            icon: Icons.air_rounded,
                            iconColor: Colors.tealAccent.shade700,
                            cardBg: iosCardBg,
                            borderColor: iosBorderColor,
                          ),
                          _buildIosInfoCard(
                            title: 'شێی هەوا',
                            value: '%$avgHumidity',
                            subtitle: 'تێکڕای ڕێژەی شێ',
                            icon: Icons.water_rounded,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _secondaryText,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _darkText,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _secondaryText,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
          ),
        ],
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
      child: GestureDetector(
        onTap: onTap,
        child: _buildNeuContainer(
          radius: 14,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Center(
                  child: Text(
                    'هیچ زانیارییەکی کەشوهەوا بەردەست نییە.',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _showLocationSearchDialog(context),
                                  child: _buildNeuContainer(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    radius: 14,
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
                                            Icons.location_on_rounded,
                                            color: Colors.redAccent,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _cityName,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: _darkText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.unfold_more_rounded,
                                          size: 18,
                                          color: _secondaryText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        _showFullscreenMapDialog(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _background,
                                        shape: BoxShape.circle,
                                        boxShadow: _neuShadowsSmall,
                                      ),
                                      child: const Icon(
                                        Icons.public_rounded,
                                        color: Colors.blueAccent,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isDarkMode = !_isDarkMode;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _background,
                                        shape: BoxShape.circle,
                                        boxShadow: _neuShadowsSmall,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.circle_outlined,
                                            color: _isDarkMode
                                                ? Colors.amber
                                                : _purple,
                                            size: 22,
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
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () =>
                                        _showSeaLevelDetailsDialog(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _background,
                                        shape: BoxShape.circle,
                                        boxShadow: _neuShadowsSmall,
                                      ),
                                      child: const Icon(
                                        Icons.terrain_rounded,
                                        color: Colors.teal,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                              const SizedBox(width: 10),
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.water_drop_rounded,
                                  iconColor: Colors.cyan,
                                  cardColor: _isDarkMode
                                      ? const Color(0xFF252D38)
                                      : const Color(0xFFE8EEF5),
                                  title: 'باران',
                                  value:
                                      '${todayRainSum.toStringAsFixed(1)} مم',
                                  wideScreen: wideScreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildNeuContainer(
                            radius: 24,
                            customColor: _isDarkMode
                                ? const Color(0xFF232A34)
                                : const Color(0xFFE6ECF5),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 48,
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
                                          ? 'پاشنیوەڕۆ'
                                          : 'بەیانی';
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
                                        width: 65,
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              formattedTime,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: _secondaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Icon(
                                              _getWeatherIcon(hCode, isDayTime),
                                              color: _getWeatherIconColor(
                                                hCode,
                                                isDayTime,
                                              ),
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 95,
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
                                const SizedBox(height: 14),
                                Divider(
                                  color: _secondaryText.withValues(alpha: 0.2),
                                  height: 1,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.wb_sunny_rounded,
                                          color: Colors.orange,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'خۆرهەڵاتن: ${sunTimes['sunrise'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: _darkText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      height: 18,
                                      width: 1,
                                      color: _secondaryText.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.wb_twilight_rounded,
                                          color: Colors.deepOrange,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'خۆرئاوا: ${sunTimes['sunset'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 14,
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildActionCard(
                                title: 'کەشوهەوا',
                                icon: Icons.psychology_rounded,
                                color: _purple,
                                onTap: () =>
                                    _showDetailedAIReportDialog(context, data),
                              ),
                              const SizedBox(width: 10),
                              _buildActionCard(
                                title: 'بڕی باران',
                                icon: Icons.water_drop_rounded,
                                color: Colors.blueAccent,
                                onTap: () =>
                                    _showRainReportDialog(context, data),
                              ),
                              const SizedBox(width: 10),
                              _buildActionCard(
                                title: 'بومەلەرزە',
                                icon: Icons.waves_rounded,
                                color: Colors.deepOrangeAccent,
                                onTap: () =>
                                    _showEarthquakeReportDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                                  radius: 14,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  customColor: cardTint,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: cardTint,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: _neuShadowsSmall,
                                            ),
                                            child: AnimatedBuilder(
                                              animation: _rotateAnimation,
                                              builder: (context, child) {
                                                return Transform.rotate(
                                                  angle: _rotateAnimation.value,
                                                  child: child,
                                                );
                                              },
                                              child: Icon(
                                                _getWeatherIcon(code, 1),
                                                color: _getWeatherIconColor(
                                                  code,
                                                  1,
                                                ),
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dayName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
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
                                          const SizedBox(width: 8),
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
                                                color: cardTint,
                                                shape: BoxShape.circle,
                                                boxShadow: _neuShadowsSmall,
                                              ),
                                              child: Icon(
                                                Icons.touch_app_rounded,
                                                size: 13,
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
                          _buildAirQualityImageBannerCard(),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '    گەشەپێدەر: زێر مەستاکانی ©٢٠٢٦    ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: _darkText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
