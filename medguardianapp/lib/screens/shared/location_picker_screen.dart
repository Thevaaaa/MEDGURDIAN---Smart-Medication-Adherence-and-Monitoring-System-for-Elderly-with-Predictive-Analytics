import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

/// Result handed back to whoever pushed the picker.
class PickedLocation {
  final double lat;
  final double lng;
  final String address;
  final double? radiusM;
  const PickedLocation({required this.lat, required this.lng, required this.address, this.radiusM});
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String title;

  /// Show the safe-zone circle and a radius slider.
  final bool showRadius;
  final double initialRadius;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.title = 'Set a location',
    this.showRadius = false,
    this.initialRadius = 200,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _fallback = LatLng(3.1390, 101.6869); // Kuala Lumpur, used only if no start point / GPS is available

  GoogleMapController? _map;
  LatLng _picked = _fallback;
  LatLng _cameraCenter = _fallback;
  String? _address;
  bool _resolvingAddress = false;
  bool _locating = false;
  bool _searching = false;
  late double _radius = widget.initialRadius.clamp(50, 1000).toDouble();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _addressDebounce;
  Timer? _searchDebounce;
  List<GeoResult> _suggestions = const [];
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      _cameraCenter = _picked;
      _resolveAddress(_picked);
    } else {
      _useCurrentLocation(silent: true);
    }
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _movePin(LatLng p, {bool animateCamera = false}) {
    HapticFeedback.selectionClick();
    setState(() {
      _picked = p;
      _address = null;
      _suggestions = const [];
    });
    if (animateCamera) _map?.animateCamera(CameraUpdate.newLatLngZoom(p, 17));
    _resolveAddress(p);
  }

  void _resolveAddress(LatLng p) {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _resolvingAddress = true);
      final resolved = await GeocodingService.instance.addressFromLatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _address = resolved ?? '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
        _resolvingAddress = false;
      });
    });
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => _locating = true);
    final pos = await LocationService.instance.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (pos == null) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get your current location. Check location permission.')));
      return;
    }
    final p = LatLng(pos.latitude, pos.longitude);
    _cameraCenter = p;
    _movePin(p, animateCamera: true);
  }

  /// Debounced live suggestions while typing.
  void _onQueryChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_searchSeq;
      final results = await GeocodingService.instance.suggest(q, biasLat: _cameraCenter.latitude, biasLng: _cameraCenter.longitude);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  Future<void> _submitSearch() async {
    if (_suggestions.isNotEmpty) {
      _choose(_suggestions.first);
      return;
    }
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final result = await GeocodingService.instance.searchAddress(q, biasLat: _cameraCenter.latitude, biasLng: _cameraCenter.longitude);
    if (!mounted) return;
    setState(() => _searching = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching place found. Try adding the city name.')));
      return;
    }
    _choose(result);
  }

  void _choose(GeoResult r) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final p = LatLng(r.lat, r.lng);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(p, 17));
    setState(() {
      _picked = p;
      _cameraCenter = p;
      _address = r.name.isNotEmpty && r.name != r.address ? '${r.name}, ${r.address}' : r.address;
      _suggestions = const [];
      _searchCtrl.text = r.name.isNotEmpty ? r.name : r.address;
    });
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(
        lat: _picked.latitude,
        lng: _picked.longitude,
        address: _address ?? '${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)}',
        radiusM: widget.showRadius ? _radius : null,
      ),
    );
  }

  IconData _iconFor(String kind) {
    final k = kind.toLowerCase();
    if (k.contains('hospital') || k.contains('clinic') || k.contains('doctor')) return Icons.local_hospital_rounded;
    if (k.contains('pharmacy')) return Icons.local_pharmacy_rounded;
    if (k.contains('house') || k.contains('residential') || k.contains('apartments')) return Icons.home_rounded;
    if (k.contains('city') || k.contains('town') || k.contains('village') || k.contains('suburb')) return Icons.location_city_rounded;
    if (k.contains('road') || k.contains('street') || k.contains('residential')) return Icons.signpost_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final showList = _searchFocus.hasFocus && (_suggestions.isNotEmpty || _searching);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 16),
            onMapCreated: (c) => _map = c,
            onTap: (p) {
              if (_searchFocus.hasFocus) {
                FocusScope.of(context).unfocus();
                return;
              }
              _movePin(p);
            },
            onLongPress: (p) {
              HapticFeedback.mediumImpact();
              _movePin(p);
            },
            onCameraMove: (pos) => _cameraCenter = pos.target,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked,
                draggable: true,
                onDragEnd: _movePin,
                icon: BitmapDescriptor.defaultMarkerWithHue(widget.showRadius ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure),
              ),
            },
            circles: {
              if (widget.showRadius)
                Circle(
                  circleId: const CircleId('zone'),
                  center: _picked,
                  radius: _radius,
                  fillColor: AppColors.success.withOpacity(0.16),
                  strokeColor: AppColors.success,
                  strokeWidth: 2,
                ),
            },
          ),
          // ── Search bar + live suggestions ──────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(children: [
                Row(children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.softShadow()), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: _searchFocus.hasFocus ? AppColors.primary : Colors.transparent, width: 1.5),
                        boxShadow: AppColors.softShadow(),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        onSubmitted: (_) => _submitSearch(),
                        decoration: InputDecoration(
                          hintText: 'Search a place or address',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searching
                              ? const Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)))
                              : (_searchCtrl.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _onQueryChanged('');
                                      },
                                    )),
                        ),
                      ),
                    ),
                  ),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !showList
                      ? const SizedBox(width: double.infinity)
                      : Container(
                          margin: const EdgeInsets.only(top: 10, left: 56),
                          constraints: const BoxConstraints(maxHeight: 330),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.softShadow()),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: _suggestions.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Shimmer(child: Text('Looking for places near you…', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textFaint))),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    itemCount: _suggestions.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 62, color: AppColors.line),
                                    itemBuilder: (context, i) {
                                      final r = _suggestions[i];
                                      return FadeSlideIn(
                                        delayMs: i * 35,
                                        child: InkWell(
                                          onTap: () => _choose(r),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                            child: Row(children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                                                child: Icon(_iconFor(r.kind), color: AppColors.primary, size: 19),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                                                  if (r.address.isNotEmpty && r.address != r.name)
                                                    Text(r.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                                                ]),
                                              ),
                                              const Icon(Icons.north_west_rounded, size: 16, color: AppColors.textFaint),
                                            ]),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                ),
              ]),
            ),
          ),
          // ── My-location button ────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: widget.showRadius ? 300 : 230,
            child: Pressable(
              onTap: () => _useCurrentLocation(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.softShadow()),
                child: _locating ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2.4)) : const Icon(Icons.my_location_rounded, color: AppColors.primary),
              ),
            ),
          ),
          // ── Bottom sheet ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -6))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 14),
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: (widget.showRadius ? AppColors.success : AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
                      child: Icon(widget.showRadius ? Icons.home_rounded : Icons.place_rounded, color: widget.showRadius ? AppColors.success : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _resolvingAddress
                            ? const Shimmer(key: ValueKey('s'), child: Text('Finding address…', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textFaint)))
                            : Text(
                                _address ?? '${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)}',
                                key: ValueKey(_address),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                              ),
                      ),
                    ),
                  ]),
                  if (widget.showRadius) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      const Text('Safe-zone size', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text('${_radius.round()} m', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ),
                    ]),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.success, thumbColor: AppColors.success, inactiveTrackColor: AppColors.success.withOpacity(0.15), overlayColor: AppColors.success.withOpacity(0.12)),
                      child: Slider(
                        value: _radius,
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        onChanged: (v) {
                          if (v.round() != _radius.round()) HapticFeedback.selectionClick();
                          setState(() => _radius = v);
                        },
                      ),
                    ),
                  ] else
                    const SizedBox(height: 6),
                  const Text('Tap or long-press the map, drag the pin, or search above.', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                  const SizedBox(height: 14),
                  GradientButton(
                    label: widget.showRadius ? 'Save safe zone' : 'Confirm this location',
                    icon: Icons.check_rounded,
                    gradient: widget.showRadius ? const LinearGradient(colors: [Color(0xFF4CC38A), Color(0xFF2E9461)]) : AppColors.heroGradient,
                    onPressed: _resolvingAddress ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
