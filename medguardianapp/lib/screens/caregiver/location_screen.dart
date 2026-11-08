import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../shared/location_picker_screen.dart';


class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _map;
  DateTime? _lastCentered;
  bool _saving = false;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  /// Opens the full-screen safe-zone editor (search with suggestions, drag
  /// the pin, resize the zone). [at] pre-places the pin, e.g. from a
  /// long-press on the small map.
  Future<void> _editSafeZone({LatLng? at}) async {
    final el = AppData.instance.elderly;
    final loc = AppData.instance.currentLocation;
    final start = at ?? (el.hasHome ? LatLng(el.homeLat!, el.homeLng!) : (loc == null ? null : LatLng(loc.lat, loc.lng)));
    final result = await Navigator.push<PickedLocation>(
      context,
      slideFadeRoute(LocationPickerScreen(
        title: el.name.isEmpty ? 'Home safe zone' : "${el.name.split(' ').first}'s home safe zone",
        initialLat: start?.latitude,
        initialLng: start?.longitude,
        showRadius: true,
        initialRadius: el.safeRadiusM,
      )),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppData.instance.setHome(result.lat, result.lng, radiusM: result.radiusM, address: result.address);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safe zone saved — you will be alerted if they leave it.')));
        _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(result.lat, result.lng), 16));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the safe zone: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final el = data.elderly;
        final loc = data.currentLocation;

        final home = el.hasHome ? LatLng(el.homeLat!, el.homeLng!) : null;
        final person = loc == null ? null : LatLng(loc.lat, loc.lng);
        final center = person ?? home;

        // Follow the person's marker when a fresh fix arrives.
        if (person != null && loc != null && (_lastCentered == null || loc.time.isAfter(_lastCentered!))) {
          _lastCentered = loc.time;
          WidgetsBinding.instance.addPostFrameCallback((_) => _map?.animateCamera(CameraUpdate.newLatLng(person)));
        }

        final stale = loc != null && DateTime.now().difference(loc.time) > const Duration(minutes: 15);
        final inside = loc?.inside;

        return PageShell(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              HeroHeader(
                bottomRadius: 40,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FadeSlideIn(child: Text('LIVE MAP', style: TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6))),
                      SizedBox(height: 3),
                      FadeSlideIn(delayMs: 50, child: Text('Location', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9))),
                    ]),
                  ),
                  if (loc != null)
                    FadeSlideIn(
                      delayMs: 100,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.2))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          LiveDot(color: stale ? AppColors.accent : AppColors.mint),
                          const SizedBox(width: 8),
                          Text(stale ? 'Last seen ${Fmt.timeAgo(loc.time)}' : 'Live', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ]),
                      ),
                    ),
                ]),
              ),
              PageBody(
                top: 22,
                children: staggered([
                  if (data.dependents.isEmpty)
                    const EmptyState(icon: Icons.people_outline_rounded, title: 'Nobody linked yet', subtitle: 'Link a person from the Overview tab to see their location.')
                  else ...[
                    if (center == null)
                      EmptyState(
                        icon: Icons.location_searching_rounded,
                        title: 'Waiting for a location',
                        subtitle: el.shareLocation
                            ? "${el.name.isEmpty ? 'Their' : "${el.name}'s"} phone hasn't shared a position yet. It appears once their app has location permission."
                            : 'Location sharing is turned off on their phone.',
                      )
                    else ...[
                      Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: AppColors.softShadow()),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SizedBox(
                            height: 360,
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(target: center, zoom: 16),
                                  onMapCreated: (c) => _map = c,
                                  // Long-press opens the safe-zone editor with the pin at that spot.
                                  onLongPress: (p) {
                                    HapticFeedback.mediumImpact();
                                    _editSafeZone(at: p);
                                  },
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  gestureRecognizers: {
                                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                                    Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
                                  },
                                  markers: {
                                    if (person != null)
                                      Marker(
                                        markerId: const MarkerId('person'),
                                        position: person,
                                        zIndex: 2,
                                        infoWindow: InfoWindow(title: el.name.isEmpty ? 'Current position' : el.name, snippet: loc == null ? null : 'Updated ${Fmt.timeAgo(loc.time)}'),
                                        icon: BitmapDescriptor.defaultMarkerWithHue(inside == false ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure),
                                      ),
                                    if (home != null)
                                      Marker(
                                        markerId: const MarkerId('home'),
                                        position: home,
                                        zIndex: 1,
                                        infoWindow: const InfoWindow(title: 'Home (safe zone centre)'),
                                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                      ),
                                  },
                                  circles: {
                                    if (home != null)
                                      Circle(circleId: const CircleId('safe'), center: home, radius: el.safeRadiusM, fillColor: AppColors.success.withOpacity(0.16), strokeColor: AppColors.success, strokeWidth: 2),
                                  },
                                ),
                                // Map legend
                                Positioned(left: 12, top: 12, child: _Legend(hasHome: home != null, away: inside == false)),
                                Positioned(
                                  right: 12,
                                  bottom: 12,
                                  child: Column(children: [
                                    if (home != null)
                                      _MapButton(icon: Icons.home_rounded, color: AppColors.success, onTap: () => _map?.animateCamera(CameraUpdate.newLatLngZoom(home, 16))),
                                    if (home != null) const SizedBox(height: 8),
                                    _MapButton(icon: Icons.my_location_rounded, color: AppColors.primary, onTap: () {
                                      if (person != null) _map?.animateCamera(CameraUpdate.newLatLngZoom(person, 16.5));
                                    }),
                                  ]),
                                ),
                                if (_saving)
                                  Positioned.fill(
                                    child: Container(color: Colors.white54, child: const Center(child: CircularProgressIndicator())),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (loc != null) _StatusCard(inside: inside, stale: stale, time: loc.time, address: loc.address),
                      const SizedBox(height: 14),
                    ],
                    _SafeZoneCard(el: el, saving: _saving, onEdit: () => _editSafeZone()),
                    if (center != null) ...[
                      const SizedBox(height: 26),
                      const SectionHeader(title: 'Recent pings', icon: Icons.history_rounded),
                      if (data.locationHistory.isEmpty)
                        const EmptyState(icon: Icons.history_rounded, title: 'No history yet', subtitle: 'A ping is saved every few minutes while they move.')
                      else
                        ...data.locationHistory.map((p) => _PingRow(point: p)),
                    ],
                  ],
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Explains the map colours: blue = the person, red = the person when
/// outside the zone, green = home & safe zone.
class _Legend extends StatelessWidget {
  final bool hasHome;
  final bool away;
  const _Legend({required this.hasHome, required this.away});

  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String label, {bool ring = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: ring ? c.withOpacity(0.25) : c,
                shape: BoxShape.circle,
                border: Border.all(color: c, width: ring ? 2 : 0),
              ),
            ),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.94), borderRadius: BorderRadius.circular(14), boxShadow: AppColors.softShadow()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        row(const Color(0xFF2F8FE0), 'Elderly (live)'),
        if (away) row(AppColors.danger, 'Outside safe zone'),
        row(AppColors.success, hasHome ? 'Home & safe zone' : 'Safe zone (not set)', ring: true),
      ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.softShadow()), child: Icon(icon, color: color)),
    );
  }
}

/// Safe-zone summary with the one action that changes it.
class _SafeZoneCard extends StatelessWidget {
  final ElderlyProfile el;
  final bool saving;
  final VoidCallback onEdit;
  const _SafeZoneCard({required this.el, required this.saving, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final has = el.hasHome;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: has ? AppColors.success.withOpacity(0.3) : AppColors.warning.withOpacity(0.4)),
        boxShadow: AppColors.softShadow(has ? AppColors.success : AppColors.warning),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: has ? const [Color(0xFF4CC38A), Color(0xFF2E9461)] : const [Color(0xFFF2B84B), Color(0xFFE0A527)]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(has ? Icons.home_rounded : Icons.add_home_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(has ? 'Home safe zone' : 'No safe zone yet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                has ? (el.homeAddress.isEmpty ? 'Set around their home' : el.homeAddress) : 'Set their home so you are alerted if they wander away.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
              ),
            ]),
          ),
          if (has)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('${el.safeRadiusM.round()} m', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 16),
        GradientButton(
          label: has ? 'Change safe zone' : 'Set safe zone',
          icon: has ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
          height: 52,
          loading: saving,
          gradient: const LinearGradient(colors: [Color(0xFF4CC38A), Color(0xFF2E9461)]),
          onPressed: onEdit,
        ),
        const SizedBox(height: 10),
        const Row(children: [
          Icon(Icons.touch_app_rounded, size: 14, color: AppColors.textFaint),
          SizedBox(width: 6),
          Expanded(child: Text('Tip: long-press anywhere on the map to start the zone there.', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5))),
        ]),
      ]),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool? inside;
  final bool stale;
  final DateTime time;
  final String? address;
  const _StatusCard({required this.inside, required this.stale, required this.time, this.address});

  @override
  Widget build(BuildContext context) {
    Color c;
    IconData icon;
    String text;
    if (stale) {
      c = AppColors.warning;
      icon = Icons.schedule_rounded;
      text = 'Last seen ${Fmt.timeAgo(time)} — location may be out of date';
    } else if (inside == null) {
      c = AppColors.info;
      icon = Icons.my_location_rounded;
      text = 'Updated ${Fmt.timeAgo(time)} · set a safe zone to get "left home" alerts';
    } else if (inside!) {
      c = AppColors.success;
      icon = Icons.verified_user_rounded;
      text = 'Inside the home safe zone · ${Fmt.timeAgo(time)}';
    } else {
      c = AppColors.danger;
      icon = Icons.warning_amber_rounded;
      text = 'Outside the safe zone · ${Fmt.timeAgo(time)}';
    }
    return SoftCard(
      shadowTint: c,
      gradient: AppColors.cardTint(c),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.18), shape: BoxShape.circle), child: Icon(icon, color: c, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 13.5, height: 1.3)),
              if ((address ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _PingRow extends StatelessWidget {
  final LocationPoint point;
  const _PingRow({required this.point});

  @override
  Widget build(BuildContext context) {
    final away = point.inside == false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: (away ? AppColors.danger : const Color(0xFF2F8FE0)).withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.place_rounded, size: 16, color: away ? AppColors.danger : const Color(0xFF2F8FE0)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(point.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            Text(Fmt.timeAgo(point.time), style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}
