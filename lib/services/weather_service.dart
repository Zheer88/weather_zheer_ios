import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // شوێنی قەزای سەیدسادق
  static const double latitude = 35.3344;
  static const double longitude = 45.9642;

  // هێنانی زانیاری کەشوهەوا بۆ 12 ڕۆژ
  Future<Map<String, dynamic>> fetchWeather() async {
    final Uri url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current='
      'temperature_2m,'
      'weather_code,'
      'is_day,'
      'wind_speed_10m,'
      'snowfall'
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
      'sunrise,'
      'sunset,'
      'precipitation_sum,'
      'precipitation_probability_max,'
      'wind_speed_10m_max,'
      'snowfall_sum'
      '&timezone=auto'
      '&forecast_days=12',
    );

    try {
      final http.Response response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        return data;
      }

      throw Exception(
        'هەڵە لە وەرگرتنی زانیارییەکانی '
        'کەشوهەوا: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception('کێشە لە پەیوەندی هێڵی ئینتەرنێت: $e');
    }
  }
}
