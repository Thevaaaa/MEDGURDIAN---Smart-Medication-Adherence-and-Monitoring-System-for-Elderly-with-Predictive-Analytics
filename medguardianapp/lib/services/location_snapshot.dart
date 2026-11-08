import 'package:battery_plus/battery_plus.dart';
import 'geocoding_service.dart';


class LocationSnapshot {
  final double lat;
  final double lng;
  const LocationSnapshot({required this.lat, required this.lng});

  String get mapsUrl => 'https://maps.google.com/?q=$lat,$lng';


  Future<String> describe() async {
    final lines = <String>[];

    String? address;
    try {
      address = await GeocodingService.instance.addressFromLatLng(lat, lng).timeout(const Duration(seconds: 6));
    } catch (_) {}
    lines.add(address == null ? '📍 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : '📍 $address');

    try {
      final level = await Battery().batteryLevel.timeout(const Duration(seconds: 3));
      lines.add('🔋 Phone battery: $level%');
    } catch (_) {}

    return lines.join('\n');
  }
}
