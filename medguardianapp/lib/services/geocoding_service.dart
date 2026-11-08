import 'dart:convert';
import 'dart:io';
import 'package:geocoding/geocoding.dart' as geo;


class GeoResult {
  final double lat;
  final double lng;
  final String address;

  /// Short place name for suggestion rows ("Penang Adventist Hospital").
  final String name;

  /// e.g. "hospital", "street", "city" — used to pick a suggestion icon.
  final String kind;

  const GeoResult({required this.lat, required this.lng, required this.address, this.name = '', this.kind = ''});
}


class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  String _format(geo.Placemark p) {
    final parts = <String>[
      if ((p.street ?? '').isNotEmpty) p.street!,
      if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
      if ((p.locality ?? '').isNotEmpty) p.locality!,
      if ((p.postalCode ?? '').isNotEmpty) p.postalCode!,
      if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      if ((p.country ?? '').isNotEmpty) p.country!,
    ];
    // De-duplicate consecutive identical fragments some geocoders repeat.
    final seen = <String>{};
    final deduped = parts.where((p) => seen.add(p.toLowerCase()));
    return deduped.isEmpty ? 'Unknown location' : deduped.join(', ');
  }

  /// Turns coordinates into a human-readable address, e.g. for showing under
  /// a dropped map pin or in the "recent pings" list. Returns null if the
  /// platform geocoder has nothing (rural areas, geocoder unavailable, etc).
  Future<String?> addressFromLatLng(double lat, double lng) async {
    try {
      final places = await geo.placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return null;
      return _format(places.first);
    } catch (_) {
      return null;
    }
  }

  /// Live search suggestions while typing, ranked by distance from
  /// [biasLat]/[biasLng] (the map centre or the user's position) — so
  /// "Adventist Hospital" finds the one in Penang, not Hong Kong.
  ///
  /// Uses the free Photon (OpenStreetMap) search API — no key needed — and
  /// falls back to the platform geocoder if the network call fails.
  Future<List<GeoResult>> suggest(String query, {double? biasLat, double? biasLng, int limit = 6}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final params = <String, String>{
        'q': q,
        'limit': '$limit',
        'lang': 'en',
        if (biasLat != null && biasLng != null) 'lat': biasLat.toStringAsFixed(5),
        if (biasLat != null && biasLng != null) 'lon': biasLng.toStringAsFixed(5),
        if (biasLat != null && biasLng != null) 'location_bias_scale': '0.3',
      };
      final uri = Uri.https('photon.komoot.io', '/api/', params);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final req = await client.getUrl(uri);
        req.headers.set(HttpHeaders.userAgentHeader, 'MedGuardian/1.0 (Flutter)');
        final res = await req.close().timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) throw HttpException('status ${res.statusCode}');
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final out = <GeoResult>[];
        for (final f in (json['features'] as List? ?? const [])) {
          final props = Map<String, dynamic>.from((f as Map)['properties'] as Map? ?? const {});
          final coords = ((f['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
          if (coords.length < 2) continue;
          final name = (props['name'] ?? props['street'] ?? '').toString();
          final street = [props['housenumber'], props['street']].where((e) => e != null && '$e'.isNotEmpty).join(' ');
          final parts = <String>[
            if (street.isNotEmpty && street != name) street,
            for (final k in ['district', 'city', 'county', 'state', 'country'])
              if ((props[k] ?? '').toString().isNotEmpty) props[k].toString(),
          ];
          final seen = <String>{name.toLowerCase()};
          final address = parts.where((p) => seen.add(p.toLowerCase())).join(', ');
          out.add(GeoResult(
            lat: (coords[1] as num).toDouble(),
            lng: (coords[0] as num).toDouble(),
            name: name.isEmpty ? address : name,
            address: address.isEmpty ? name : address,
            kind: (props['osm_value'] ?? props['type'] ?? '').toString(),
          ));
        }
        if (out.isNotEmpty) return out;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // fall through to the platform geocoder
    }
    final one = await _platformSearch(q);
    return one == null ? const [] : [one];
  }

  /// Forward-geocodes free-text (e.g. typed into a search box) into
  /// coordinates + a clean formatted address, preferring results near
  /// [biasLat]/[biasLng]. Returns null if nothing matches.
  Future<GeoResult?> searchAddress(String query, {double? biasLat, double? biasLng}) async {
    final list = await suggest(query, biasLat: biasLat, biasLng: biasLng, limit: 1);
    if (list.isNotEmpty) return list.first;
    return _platformSearch(query);
  }

  Future<GeoResult?> _platformSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    try {
      final locations = await geo.locationFromAddress(trimmed);
      if (locations.isEmpty) return null;
      final loc = locations.first;
      final address = await addressFromLatLng(loc.latitude, loc.longitude) ?? trimmed;
      return GeoResult(lat: loc.latitude, lng: loc.longitude, address: address, name: trimmed);
    } catch (_) {
      return null;
    }
  }
}
