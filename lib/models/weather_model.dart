class WeatherModel {
  final double currentTemp;
  final int isDay;
  final List<String> times;
  final List<double> maxTemps;
  final List<double> minTemps;
  final List<int> weatherCodes;
  final List<double> precipitationSums;
  final List<int> precipitationProbabilities;

  // سەعاتەکان
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
