import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_zheer/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // لێرەدا ناوەکەمان گۆڕیوە بۆ کڵاسە دروستەکە
    await tester.pumpWidget(const WeatherZheerApp());

    // دڵنیابوونەوە لەوەی کە ئەپەکە بەبێ کێشە کاردەکات
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}