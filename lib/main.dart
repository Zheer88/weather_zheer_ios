import 'package:flutter/material.dart';
import 'home_screen.dart';

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
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Arial',
      ),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF030712),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 410, maxHeight: 880),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(37),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
