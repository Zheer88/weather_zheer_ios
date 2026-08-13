import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_zheer/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // لێرەدا ناوەکەمان گۆڕیوە بۆ کڵاسە دروستەکە کە خۆت ناوت لێناوە
    await tester.pumpWidget(const WeatherZheerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
