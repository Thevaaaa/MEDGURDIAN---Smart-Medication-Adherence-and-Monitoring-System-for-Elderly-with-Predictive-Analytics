import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'app_data.dart';
import 'geocoding_service.dart';
import 'location_snapshot.dart';


class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _sub;
  bool _enabled = false;
  bool _denied = false; // don't re-prompt until the user toggles sharing off/on
  DateTime? _lastWrite;
  DateTime? _lastGeocode;
  bool? _wasInside;

  bool get running => _sub != null;

  Future<void> setEnabled(bool on) async {
    if (!on) _denied = false;
    if (on == _enabled || (on && _denied)) return;
    _enabled = on;
    if (on) {
      await _start();
    } else {
      await _stop();
    }
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

  Future<void> _start() async {
    if (_sub != null) return;
    if (!await _ensurePermission()) {
      _enabled = false;
      _denied = true;
      debugPrint('📍 Location permission unavailable');
      return;
    }

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
            intervalDuration: const Duration(seconds: 30),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'MedGuardian location sharing',
              notificationText: 'Your caregiver can see where you are.',
              enableWakeLock: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.otherNavigation,
            distanceFilter: 20,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object e) => debugPrint('Location stream error: $e'),
    );
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _wasInside = null;
  }

  Future<void> _onPosition(Position p) async {
    final data = AppData.instance;
    final el = data.elderly;

    bool? inside;
    if (el.hasHome) {
      final dist = Geolocator.distanceBetween(el.homeLat!, el.homeLng!, p.latitude, p.longitude);
      // Hysteresis avoids flapping right on the boundary: leave at 100 % of
      // the radius, return at 80 %.
      if (_wasInside == false) {
        inside = dist <= el.safeRadiusM * 0.8;
      } else {
        inside = dist <= el.safeRadiusM;
      }
    }

    final now = DateTime.now();
    final changed = inside != _wasInside;
    if (_lastWrite == null || changed || now.difference(_lastWrite!) > const Duration(seconds: 25)) {
      _lastWrite = now;

      // Reverse-geocode at most every 5 minutes (or on a safe-zone change) so
      // "recent pings" show a human address without hammering the geocoder.
      String? address;
      if (changed || _lastGeocode == null || now.difference(_lastGeocode!) > const Duration(minutes: 5)) {
        _lastGeocode = now;
        address = await GeocodingService.instance.addressFromLatLng(p.latitude, p.longitude);
      }

      await data.publishLocation(lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, inside: inside, address: address);
    }

    if (inside != null) {
      if (_wasInside == true && inside == false) {
        data.triggerGeofenceAlert(true, location: LocationSnapshot(lat: p.latitude, lng: p.longitude));
      } else if (_wasInside == false && inside == true) {
        data.triggerGeofenceAlert(false, location: LocationSnapshot(lat: p.latitude, lng: p.longitude));
      }
      _wasInside = inside;
    }
  }

  /// One-off fix, used for "Set current location as home".
  Future<Position?> currentPosition() async {
    if (!await _ensurePermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (e) {
      debugPrint('getCurrentPosition failed: $e');
      return null;
    }
  }
}
