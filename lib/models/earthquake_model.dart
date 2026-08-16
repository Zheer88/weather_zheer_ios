class EarthquakeModel {
  final double mag;
  final String place;
  final String time;
  final double lat;
  final double lon;
  final double depth;

  EarthquakeModel({
    required this.mag,
    required this.place,
    required this.time,
    required this.lat,
    required this.lon,
    required this.depth,
  });

  factory EarthquakeModel.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'];
    final geometry = json['geometry'];
    final coordinates = geometry['coordinates'] as List;

    // وەرگێڕانی مۆڵەتی کات (Timestamp) بۆ کاتی خوێنراوە
    final int millis = properties['time'] ?? 0;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(millis);
    final formattedTime =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return EarthquakeModel(
      mag: (properties['mag'] ?? 0.0).toDouble(),
      place: properties['place'] ?? 'شوێنی نەزانراو',
      time: formattedTime,
      lat: coordinates[1].toDouble(),
      lon: coordinates[0].toDouble(),
      depth: coordinates[2].toDouble(),
    );
  }
}
