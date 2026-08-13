import 'package:flutter/material.dart';
import 'home_screen.dart';

// ئەگەر دەتەوێت ڕاستەوخۆ شاشەی لۆکەیشن تاقی بکەیتەوە، دەتوانیت ئەمەیان لێرە بهێڵیتەوە
// یان لە ناو home_screen بانگهێشتی بکەیت.

void main() {
  runApp(const WeatherZheerApp());
}

class WeatherZheerApp extends StatelessWidget {
  const WeatherZheerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Zheer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(
          0xFFE0E5EC,
        ), // شێوازی Neumorphism کە بەکارتهێناوە
        fontFamily: 'Arial',
      ),
      // لێرەدا شاشەی سەرەکی پڕۆژەکەت دەستنیشان کراوە
      home: const HomeScreen(),
    );
  }
}
