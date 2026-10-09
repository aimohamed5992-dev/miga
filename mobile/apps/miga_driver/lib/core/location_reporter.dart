import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'services.dart';

/// While the driver is online and the app is open, sends the phone's position every 30 s so operations can see
/// drivers on the admin live map. Asks for location permission once; if refused, it simply stays silent.
class LocationReporter {
  LocationReporter._();
  static final instance = LocationReporter._();

  static const interval = Duration(seconds: 30);
  Timer? _timer;
  bool _denied = false;

  bool get running => _timer != null;

  void start() {
    if (_timer != null || _denied) return;
    _send();
    _timer = Timer.periodic(interval, (_) => _send());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _send() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _denied = true;
        stop();
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      await AppServices.api.driver.reportLocation(p.latitude, p.longitude);
    } catch (e) {
      // Best effort: a missed update only makes the admin map a little older.
      debugPrint('location report skipped: $e');
    }
  }
}
