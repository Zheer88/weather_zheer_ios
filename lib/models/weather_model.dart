class WeatherModel {
  final List<dynamic> times;
  final List<dynamic> maxTemps;
  final List<dynamic> minTemps;
  final List<dynamic> weatherCodes;
  final List<dynamic> precipitationSums;
  final List<dynamic> precipitationProbabilities;
  final double currentTemp;
  final int currentWeatherCode;
  final int isDay;

  WeatherModel({
    required this.times,
    required this.maxTemps,
    required this.minTemps,
    required this.weatherCodes,
    required this.precipitationSums,
    required this.precipitationProbabilities,
    required this.currentTemp,
    required this.currentWeatherCode,
    required this.isDay,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current =
        (json['current'] ?? json['current_weather'] ?? {})
            as Map<String, dynamic>;
    final daily = (json['daily'] ?? {}) as Map<String, dynamic>;

    final currentTemperature =
        current['temperature_2m'] ?? current['temperature'] ?? 0;
    final currentCode = current['weather_code'] ?? current['weathercode'] ?? 0;
    final currentIsDay = current['is_day'] ?? 1;

    return WeatherModel(
      times: daily['time'] ?? <dynamic>[],
      maxTemps: daily['temperature_2m_max'] ?? <dynamic>[],
      minTemps: daily['temperature_2m_min'] ?? <dynamic>[],
      weatherCodes: daily['weather_code'] ?? <dynamic>[],
      precipitationSums: daily['precipitation_sum'] ?? <dynamic>[],
      precipitationProbabilities:
          daily['precipitation_probability_max'] ?? <dynamic>[],
      currentTemp: currentTemperature is num
          ? currentTemperature.toDouble()
          : 0.0,
      currentWeatherCode: currentCode is num ? currentCode.toInt() : 0,
      isDay: currentIsDay is num ? currentIsDay.toInt() : 1,
    );
  }
}
