WEATHER ZHEER - ANDROID SETUP

This project did not contain an android/ folder in the supplied ZIP.
The included setup_android.ps1 creates the Android platform using Flutter, then adds:
- INTERNET permission
- ACCESS_COARSE_LOCATION permission
- ACCESS_FINE_LOCATION permission
- HTTPS-only cleartext networking setting

It does NOT remove or rewrite lib/, assets/, web/, ios/, or your app features.

Run from the project root in PowerShell:
  Set-ExecutionPolicy -Scope Process Bypass
  .\setup_android.ps1

The script will run:
  flutter create --platforms=android .
  flutter pub get
  flutter analyze
  flutter build apk --release

Final APK:
  build\app\outputs\flutter-apk\app-release.apk
