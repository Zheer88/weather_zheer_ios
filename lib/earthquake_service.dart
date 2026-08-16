import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/earthquake_model.dart';

class EarthquakeService {
  // بەکارهێنانی پێگەی گشتی USGS
  static const String _url =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_month.geojson';

  static Future<List<EarthquakeModel>> getRecentEarthquakes() async {
    try {
      final response = await http.get(Uri.parse(_url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'];

        // گۆڕینی بۆ لیست و پاشان فلتەرکردنی تەنها بۆ وڵاتی عێراق
        List<EarthquakeModel> allEarthquakes = features
            .map((json) => EarthquakeModel.fromJson(json))
            .toList();

        // فلتەرکردن بۆ ئەوەی تەنها ئەو شوێنانە بهێنێت کە 'Iraq' یان تێدایە
        List<EarthquakeModel> iraqEarthquakes = allEarthquakes.where((eq) {
          return eq.place.toLowerCase().contains('iraq');
        }).toList();

        return iraqEarthquakes;
      } else {
        throw Exception('شکست لە هێنانی زانیاری بومەلەرزەکان');
      }
    } catch (e) {
      throw Exception('هەڵە ڕوویدا: $e');
    }
  }
}
