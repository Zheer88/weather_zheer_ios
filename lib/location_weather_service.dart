import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationWeatherService {
  /// وەرگرتنی شوێنی بەکارهێنەر
  static Future<Position> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('تکایە GPS / Location چالاک بکە.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('مۆڵەتی GPS ڕەتکرایەوە.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('مۆڵەتی GPS داخراوە. لە Settings ـی براوزەر چالاکی بکە.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// دۆزینەوەی ناوی شار
  static Future<String> getCityName(double latitude, double longitude) async {
    final Uri url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2'
      '&lat=$latitude'
      '&lon=$longitude'
      '&accept-language=ku',
    );

    final response = await http.get(
      url,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'weather_zheer/1.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('نەتوانرا ناوی شوێن بدۆزرێتەوە.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final address = (data['address'] ?? {}) as Map<String, dynamic>;

    return (address['city'] ??
            address['town'] ??
            address['municipality'] ??
            address['village'] ??
            address['county'] ??
            'شوێنی نەناسراو')
        .toString();
  }

  /// وەرگرتنی کەشوهەوا
  static Future<Map<String, dynamic>> getWeather(
    double latitude,
    double longitude,
  ) async {
    final Uri url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current='
      'temperature_2m,'
      'weather_code,'
      'is_day'
      '&hourly='
      'temperature_2m,'
      'relative_humidity_2m,'
      'precipitation,'
      'weather_code,'
      'wind_speed_10m'
      '&daily='
      'weather_code,'
      'temperature_2m_max,'
      'temperature_2m_min,'
      'precipitation_sum,'
      'precipitation_probability_max,'
      'sunrise,'
      'sunset,'
      'windspeed_10m_max'
      '&timezone=auto'
      '&forecast_days=12',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'کێشە لە وەرگرتنی زانیاری کەشوهەوا: '
        '${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
