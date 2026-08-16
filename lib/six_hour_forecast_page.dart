import 'package:flutter/material.dart';

class SixHourForecastModal extends StatelessWidget {
  const SixHourForecastModal({super.key});

  @override
  Widget build(BuildContext context) {
    // داتای نموونەیی بۆ کاتژمێرەکانی کەشوهەوا کە ئایکۆن و ڕەنگ بەپێی دۆخەکە دەگۆڕێن
    final List<Map<String, dynamic>> forecastData = [
      {
        'time': 'AM 8:00',
        'temp': '30°C',
        'condition': 'هەوری تەواو',
        'icon': Icons.cloud,
        'color': Colors.blueGrey,
        'rain': '0.0 ملم',
        'wind': '5 کم/س',
        'humidity': '%31',
      },
      {
        'time': 'AM 4:00',
        'temp': '27°C',
        'condition': 'شەوی ڕووناک',
        'icon': Icons.nightlight_round,
        'color': Colors.indigo,
        'rain': '0.0 ملم',
        'wind': '5 کم/س',
        'humidity': '%35',
      },
      {
        'time': 'AM 12:00',
        'temp': '28°C',
        'condition': 'شەوی ئەستێرەیی',
        'icon': Icons.brightness_3,
        'color': Colors.deepPurple,
        'rain': '0.0 ملم',
        'wind': '5 کم/س',
        'humidity': '%35',
      },
      {
        'time': 'PM 4:00',
        'temp': '33°C',
        'condition': 'خۆرەتاو',
        'icon': Icons.wb_sunny,
        'color': Colors.orange,
        'rain': '0.0 ملم',
        'wind': '6 کم/س',
        'humidity': '%28',
      },
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFE0E5EC),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // سەرڕستەی پۆپ-ئەپ و دوگمەی داخستن
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'کەشوهەوای کاتژمێری (دووشەممە)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 48), // بۆ هاوسەنگکردنی ناوەڕاست
              ],
            ),
            const SizedBox(height: 10),

            // گرید ڤیو بۆ پیشاندانی ٢ کارت لەسەر یەک (٢ ستوون) بە شێوەیەک کە هەمووی دەردەکەوێت
            SizedBox(
              height: 380, // قەبارەی گونجاو بۆ مۆبایل
              child: GridView.builder(
                itemCount: forecastData.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // ٢ کارت لە پاڵ یەکتر لە هەر ڕیزێکدا
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85, // ڕێژەی درێژی و پانی کارتەکان
                ),
                itemBuilder: (context, index) {
                  final item = forecastData[index];
                  return NeumorphicWeatherCard(
                    time: item['time'],
                    temp: item['temp'],
                    condition: item['condition'],
                    icon: item['icon'],
                    accentColor: item['color'],
                    rain: item['rain'],
                    wind: item['wind'],
                    humidity: item['humidity'],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // دوگمەی باشە
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('باشە', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// کارتی نۆمۆرفیزم بۆ هەر کاتژمێرێک بە گۆڕانی ڕەنگ و ئایکۆنی ڕاستەقینە
class NeumorphicWeatherCard extends StatelessWidget {
  final String time;
  final String temp;
  final String condition;
  final IconData icon;
  final Color accentColor;
  final String rain;
  final String wind;
  final String humidity;

  const NeumorphicWeatherCard({
    super.key,
    required this.time,
    required this.temp,
    required this.condition,
    required this.icon,
    required this.accentColor,
    required this.rain,
    required this.wind,
    required this.humidity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E5EC),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Icon(icon, size: 30, color: accentColor),
          const SizedBox(height: 6),
          Text(
            temp,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            condition,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
          const Divider(height: 12),
          // زانیاری وردتر (باران، با، ڕێژەی نم نم)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                rain,
                style: const TextStyle(fontSize: 9, color: Colors.blue),
              ),
              Text(
                wind,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            humidity,
            style: const TextStyle(fontSize: 9, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
