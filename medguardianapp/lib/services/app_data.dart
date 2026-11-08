import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'location_snapshot.dart';
import 'notification_service.dart';
import 'risk_api_service.dart';
import 'risk_predictor.dart';


const String kVitalsClearedAtPref = 'mg_vitals_cleared_at';

class AppData extends ChangeNotifier with WidgetsBindingObserver {
  AppData._();
  static final AppData instance = AppData._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Session ────────────────────────────────────────────────────────
  String? _uid;
  AppUser? me;
  bool _linksLoaded = false;

  bool get isElderly => me?.role == UserRole.elderly;
  bool get isCaregiver => me?.role == UserRole.caregiver;

  /// True once we know the role (and, for caregivers, their links).
  bool get ready => me != null && (isElderly || _linksLoaded);

  // ── Active elderly + data ──────────────────────────────────────────
  String? activeElderlyId;
  ElderlyProfile elderly = ElderlyProfile();
  List<ElderlyProfile> dependents = [];
  List<Caregiver> caregivers = [];

  List<Medication> medications = [];
  List<DoseLog> doseLogs = [];
  List<Appointment> appointments = [];
  List<SymptomLog> symptoms = [];
  List<VitalReading> vitals = [];
  List<AlertItem> alerts = [];
  LocationPoint? currentLocation;
  List<LocationPoint> locationHistory = [];

  RiskResult risk = RiskResult.empty();

  /// Large-text mode is an elderly-only accessibility setting. It is saved
  /// per account on this phone and never affects caregiver screens.
  bool largeText = false;
  bool get largeTextActive => isElderly && largeText;

  void toggleLargeText() {
    largeText = !largeText;
    notifyListeners();
    final uid = _uid;
    if (uid != null) {
      SharedPreferences.getInstance().then((p) => p.setBool('mg_large_text_$uid', largeText)).catchError((Object e) {
        _err('largeText', e);
        return false;
      });
    }
  }

  Future<void> _loadLargeText() async {
    try {
      final p = await SharedPreferences.getInstance();
      largeText = isElderly && (p.getBool('mg_large_text_$_uid') ?? false);
      notifyListeners();
    } catch (e) {
      _err('largeText', e);
    }
  }

  // ── Internals ──────────────────────────────────────────────────────
  final List<StreamSubscription> _sessionSubs = [];
  final List<StreamSubscription> _elderlySubs = [];
  final Map<String, StreamSubscription> _depSubs = {};
  final Map<String, ElderlyProfile> _depProfiles = {};
  Timer? _maintenance;
  int _tick = 0;
  bool _doseLoaded = false;
  bool _alertsLoaded = false;
  bool _ensuring = false;
  final Set<String> _pendingDoseIds = {};
  final Set<String> _autoMissing = {};
  final Set<String> _missAlerted = {};
  final Set<String> _reminded = {};
  DateTime? _lastHistoryWrite;
  int? _offsetWritten;

  String get _who => (isElderly ? me?.name : null) ?? (elderly.name.isEmpty ? 'Your loved one' : elderly.name);

  String get _target => activeElderlyId ?? _uid ?? '';
  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(_target);
  CollectionReference<Map<String, dynamic>> _col(String name) => _userDoc.collection(name);

  String newId() => _db.collection('_ids').doc().id;

  void _err(String label, Object e) => debugPrint('⚠️ AppData[$label]: $e');

  // ════════════════════════════════════════════════════════════════════
  // Session lifecycle
  // ════════════════════════════════════════════════════════════════════

  Future<void> start(User user) async {
    if (_uid == user.uid) return;
    await stop();
    _uid = user.uid;
    WidgetsBinding.instance.addObserver(this);

    _sessionSubs.add(_db.collection('users').doc(user.uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final firstTime = me == null;
      me = AppUser.fromMap(snap.id, snap.data()!);
      if (firstTime) _onRoleKnown();
      notifyListeners();
    }, onError: (Object e) => _err('me', e)));

    unawaited(NotificationService.instance.registerForUser(user.uid));
  }

  void _onRoleKnown() {
    _loadLargeText();
    if (isElderly) {
      _attachElderly(_uid!);
      _syncOffset();
      _maintenance = Timer.periodic(const Duration(minutes: 1), (_) => _maintenanceTick());
    } else {
      _watchLinks();
    }
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    _maintenance?.cancel();
    _maintenance = null;
    for (final s in _sessionSubs) {
      await s.cancel();
    }
    _sessionSubs.clear();
    for (final s in _depSubs.values) {
      await s.cancel();
    }
    _depSubs.clear();
    _depProfiles.clear();
    await _cancelElderlySubs();
    _uid = null;
    _offsetWritten = null;
    me = null;
    largeText = false;
    _linksLoaded = false;
    activeElderlyId = null;
    dependents = [];
    caregivers = [];
    elderly = ElderlyProfile();
    _clearLists();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refreshPermission();
      if (isElderly) _maintenanceTick(force: true);
    }
  }

  Future<void> _cancelElderlySubs() async {
    for (final s in _elderlySubs) {
      await s.cancel();
    }
    _elderlySubs.clear();
  }

  void _clearLists() {
    medications = [];
    doseLogs = [];
    appointments = [];
    symptoms = [];
    vitals = [];
    alerts = [];
    currentLocation = null;
    locationHistory = [];
    caregivers = [];
    risk = RiskResult.empty();
    _apiRisk = null;
    _apiRiskKey = null;
    _apiRiskInFlight = null;
    _riskRetry?.cancel();
    _doseLoaded = false;
    _alertsLoaded = false;
    _pendingDoseIds.clear();
    _autoMissing.clear();
    _missAlerted.clear();
    _reminded.clear();
  }

  // ════════════════════════════════════════════════════════════════════
  // Caregiver: linked dependents
  // ════════════════════════════════════════════════════════════════════

  void _watchLinks() {
    _sessionSubs.add(_db.collection('links').where('caregiverId', isEqualTo: _uid).snapshots().listen((qs) {
      final ids = qs.docs.map((d) => (d.data()['elderlyId'] ?? '') as String).where((s) => s.isNotEmpty).toList();

      // Drop subscriptions for people who are no longer linked.
      for (final gone in _depSubs.keys.where((k) => !ids.contains(k)).toList()) {
        _depSubs.remove(gone)?.cancel();
        _depProfiles.remove(gone);
      }
      // Subscribe to profiles of newly linked people.
      for (final id in ids) {
        if (_depSubs.containsKey(id)) continue;
        _depSubs[id] = _db.collection('users').doc(id).snapshots().listen((snap) {
          if (snap.exists) _depProfiles[id] = ElderlyProfile.fromMap(snap.id, snap.data()!);
          _rebuildDependents(ids);
        }, onError: (Object e) => _err('dependent $id', e));
      }

      _linksLoaded = true;
      _rebuildDependents(ids);

      if (ids.isEmpty) {
        activeElderlyId = null;
        _cancelElderlySubs();
        _clearLists();
        elderly = ElderlyProfile();
      } else if (activeElderlyId == null || !ids.contains(activeElderlyId)) {
        _attachElderly(ids.first);
      }
      notifyListeners();
    }, onError: (Object e) => _err('links', e)));
  }

  void _rebuildDependents(List<String> ids) {
    dependents = [for (final id in ids) if (_depProfiles[id] != null) _depProfiles[id]!];
    notifyListeners();
  }

  void selectDependent(String elderlyId) {
    if (elderlyId == activeElderlyId) return;
    _attachElderly(elderlyId);
  }

  /// Caregiver: link to an elderly user with the 6-digit code they share.
  Future<void> linkWithCode(String code, String relation) async {
    final uid = _uid;
    final profile = me;
    if (uid == null || profile == null) throw Exception('Not signed in.');
    final trimmed = code.trim();
    if (trimmed.length != 6) throw Exception('Enter the 6-digit code.');

    final codeSnap = await _db.collection('linkCodes').doc(trimmed).get();
    if (!codeSnap.exists) throw Exception('No one found with that code. Check it and try again.');
    final elderlyId = codeSnap.data()!['elderlyId'] as String;
    if (elderlyId == uid) throw Exception('You cannot link to yourself.');
    if (dependents.any((d) => d.uid == elderlyId)) throw Exception('You are already linked to this person.');

    await _db.collection('links').doc('${elderlyId}_$uid').set({
      'elderlyId': elderlyId,
      'caregiverId': uid,
      'code': trimmed,
      'caregiverName': profile.name,
      'caregiverPhone': profile.phone,
      'caregiverPhotoUrl': profile.photoUrl,
      'relation': relation,
      'elderlyName': (codeSnap.data()!['elderlyName'] ?? '') as String,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeLink(String linkId) => _db.collection('links').doc(linkId).delete();

  Future<void> unlinkDependent(String elderlyId) async {
    if (_uid == null) return;
    await removeLink('${elderlyId}_$_uid');
  }

  // ════════════════════════════════════════════════════════════════════
  // Attach to an elderly person's data
  // ════════════════════════════════════════════════════════════════════

  Future<void> _attachElderly(String eid) async {
    await _cancelElderlySubs();
    _clearLists();
    activeElderlyId = eid;
    if (_uid != eid) elderly = ElderlyProfile(uid: eid);
    notifyListeners();

    final userDoc = _db.collection('users').doc(eid);
    final now = DateTime.now();

    _elderlySubs.add(userDoc.snapshots().listen((s) {
      if (!s.exists) return;
      elderly = ElderlyProfile.fromMap(s.id, s.data()!);
      notifyListeners();
    }, onError: (Object e) => _err('profile', e)));

    _elderlySubs.add(userDoc.collection('medications').snapshots().listen((qs) {
      medications = qs.docs.map((d) => Medication.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      _ensureDoses();
    }, onError: (Object e) => _err('medications', e)));

    _elderlySubs.add(userDoc
        .collection('doseLogs')
        .where('scheduledTime', isGreaterThan: Timestamp.fromDate(now.subtract(const Duration(days: 30))))
        .orderBy('scheduledTime')
        .snapshots()
        .listen((qs) {
      doseLogs = qs.docs.map((d) => DoseLog.fromMap(d.id, d.data())).toList();
      _pendingDoseIds.removeWhere((id) => doseLogs.any((d) => d.id == id));
      _doseLoaded = true;
      _recomputeRisk();
      notifyListeners();
      _ensureDoses();
      _maybeRiskAlert();
    }, onError: (Object e) => _err('doseLogs', e)));

    _elderlySubs.add(userDoc
        .collection('appointments')
        .where('dateTime', isGreaterThan: Timestamp.fromDate(now.subtract(const Duration(days: 2))))
        .orderBy('dateTime')
        .snapshots()
        .listen((qs) {
      appointments = qs.docs.map((d) => Appointment.fromMap(d.id, d.data())).toList();
      notifyListeners();
    }, onError: (Object e) => _err('appointments', e)));

    _elderlySubs.add(userDoc.collection('symptoms').orderBy('time', descending: true).limit(50).snapshots().listen((qs) {
      symptoms = qs.docs.map((d) => SymptomLog.fromMap(d.id, d.data())).toList();
      _recomputeRisk();
      notifyListeners();
    }, onError: (Object e) => _err('symptoms', e)));

    _elderlySubs.add(userDoc.collection('vitals').orderBy('time', descending: true).limit(40).snapshots().listen((qs) {
      vitals = qs.docs.map((d) => VitalReading.fromMap(d.id, d.data())).toList();
      _recomputeRisk();
      notifyListeners();
    }, onError: (Object e) => _err('vitals', e)));

    _elderlySubs.add(userDoc.collection('alerts').orderBy('time', descending: true).limit(100).snapshots().listen((qs) {
      alerts = qs.docs.map((d) => AlertItem.fromMap(d.id, d.data())).toList();
      _alertsLoaded = true;
      notifyListeners();
      _maybeRiskAlert();
    }, onError: (Object e) => _err('alerts', e)));

    _elderlySubs.add(userDoc.collection('location').doc('current').snapshots().listen((s) {
      currentLocation = s.exists ? LocationPoint.fromMap(s.data()!) : null;
      notifyListeners();
    }, onError: (Object e) => _err('location', e)));

    _elderlySubs.add(userDoc.collection('locationHistory').orderBy('time', descending: true).limit(12).snapshots().listen((qs) {
      locationHistory = qs.docs.map((d) => LocationPoint.fromMap(d.data())).toList();
      notifyListeners();
    }, onError: (Object e) => _err('locationHistory', e)));

    // The elderly user also sees who is linked to them.
    if (_uid == eid) {
      _elderlySubs.add(_db.collection('links').where('elderlyId', isEqualTo: eid).snapshots().listen((qs) {
        caregivers = qs.docs.map((d) => Caregiver.fromLink(d.id, d.data())).toList();
        notifyListeners();
      }, onError: (Object e) => _err('caregivers', e)));
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Medications
  // ════════════════════════════════════════════════════════════════════

  Future<void> addMedication(Medication m) async {
    await _col('medications').doc(m.id).set(m.toMap());
  }

  Future<void> updateMedication(Medication m) async {
    await _col('medications').doc(m.id).set(m.toMap());
    // Future pending doses may no longer match the new times — drop them;
    // _ensureDoses() regenerates the right ones from the next snapshot.
    final now = DateTime.now();
    final logs = await _col('doseLogs').where('medicationId', isEqualTo: m.id).get();
    final batch = _db.batch();
    var n = 0;
    for (final d in logs.docs) {
      final data = d.data();
      final when = (data['scheduledTime'] as Timestamp).toDate();
      if (data['status'] == 'pending' && when.isAfter(now)) {
        batch.delete(d.reference);
        n++;
      }
    }
    if (n > 0) await batch.commit();
  }

  Future<void> deleteMedication(String id) async {
    final logs = await _col('doseLogs').where('medicationId', isEqualTo: id).get();
    final batch = _db.batch();
    for (final d in logs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_col('medications').doc(id));
    await batch.commit();
    await deleteMedicationPhoto(id);
  }

  /// Quick stock change (e.g. "refill") without touching scheduled doses.
  Future<void> setMedicationStock(String id, int stock) => _col('medications').doc(id).update({'stock': stock.clamp(0, 999)});

  Reference _medPhotoRef(String medId) => FirebaseStorage.instance.ref('medications/$_target/$medId.jpg');

  /// Uploads a medicine photo to Cloud Storage at
  /// `medications/{elderlyUid}/{medId}.jpg` and returns its download URL.
  /// The caller stores the URL on the medication doc (via add/update).
  Future<String> uploadMedicationPhoto(String medId, Uint8List bytes) async {
    if (_target.isEmpty) throw Exception('Not signed in.');
    final ref = _medPhotoRef(medId);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    // Cache-bust so a replaced photo shows immediately.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Best-effort removal of a medicine photo from Cloud Storage.
  Future<void> deleteMedicationPhoto(String medId) async {
    if (_target.isEmpty) return;
    try {
      await _medPhotoRef(medId).delete();
    } catch (_) {
      // Never uploaded or already gone — fine.
    }
  }

  Medication? medicationById(String id) {
    for (final m in medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════
  // Doses
  // ════════════════════════════════════════════════════════════════════

  static String doseId(String medId, DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${medId}_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }

  /// Creates the doc only if it does not exist yet, so a dose the server (or
  /// another device) already created — and possibly updated — is never reset.
  Future<void> _createIfAbsent(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) tx.set(ref, data);
    });
  }

  /// Keeps today + the next 2 days of dose docs generated so the Cloud
  /// Function can push reminders even if the app isn't opened.
  Future<void> _ensureDoses() async {
    if (!isElderly || !_doseLoaded || _ensuring || _uid == null) return;
    _ensuring = true;
    try {
      final existing = doseLogs.map((d) => d.id).toSet();
      final now = DateTime.now();
      final jobs = <Future<void>>[];
      final ids = <String>[];
      for (var day = 0; day < 3; day++) {
        final date = DateTime(now.year, now.month, now.day + day);
        for (final med in medications) {
          for (final t in med.times) {
            final sched = DateTime(date.year, date.month, date.day, t.hour, t.minute);
            if (!sched.isAfter(now)) continue; // never create doses in the past
            final id = doseId(med.id, sched);
            if (existing.contains(id) || _pendingDoseIds.contains(id)) continue;
            _pendingDoseIds.add(id);
            ids.add(id);
            final data = DoseLog(id: id, medicationId: med.id, medName: med.name, dosage: med.dosage, scheduledTime: sched).toMap();
            jobs.add(_createIfAbsent(_col('doseLogs').doc(id), data));
          }
        }
      }
      if (jobs.isNotEmpty) {
        try {
          await Future.wait(jobs);
        } catch (e) {
          _pendingDoseIds.removeAll(ids); // retry on the next tick (e.g. was offline)
          rethrow;
        }
      }
    } catch (e) {
      _err('ensureDoses', e);
    } finally {
      _ensuring = false;
    }
  }

  /// The server generates dose docs in the user's local calendar; it needs
  /// their current UTC offset to do that correctly.
  void _syncOffset() {
    if (!isElderly || _uid == null) return;
    final off = DateTime.now().timeZoneOffset.inMinutes;
    if (off == _offsetWritten) return;
    _offsetWritten = off;
    _db.collection('users').doc(_uid).set({'utcOffsetMinutes': off}, SetOptions(merge: true)).catchError((Object e) {
      _offsetWritten = null;
      _err('offset', e);
    });
  }

  void _maintenanceTick({bool force = false}) {
    _tick++;
    _syncOffset();
    if (force || _tick % 5 == 0) _ensureDoses();
    // The 15-minute "you can take it now" push is sent by the sendReminders
    // Cloud Function; _remindUpcoming() stays as an offline fallback only.
    _autoMissOverdue();
  }

  /// Local "you can take it now" reminder 15 minutes before each dose, as a
  /// backup to the server push (see functions/medguardian_sweeps.js) while
  /// the app is running.
  void _remindUpcoming() {
    if (!isElderly) return;
    final now = DateTime.now();
    for (final d in doseLogs) {
      if (d.status != DoseStatus.pending) continue;
      if (now.isBefore(d.opensAt) || now.isAfter(d.scheduledTime)) continue;
      if (!_reminded.add(d.id)) continue;
      NotificationService.instance.showLocal(
        id: d.id.hashCode & 0x7fffffff,
        title: 'Time for ${d.medName} soon',
        body: '${d.dosage.isEmpty ? '' : '${d.dosage} · '}due at ${_shortTime(d.scheduledTime)}. You can take it now.',
        channel: 'dose_reminders',
        payload: 'meds',
      );
    }
  }

  /// Client-side fallback for the server sweep:
  ///  * a dose still pending 1 hour after its time is recorded as missed;
  ///  * caregivers are told about a missed dose only once that hour has
  ///    passed (even if it was marked "missed" earlier), so they get one
  ///    clear message per dose.
  void _autoMissOverdue() {
    if (!isElderly) return;
    final now = DateTime.now();
    final cutoff = now.subtract(kDoseMissAfter);
    final oldest = now.subtract(const Duration(hours: 12));
    for (final d in doseLogs) {
      if (d.scheduledTime.isAfter(cutoff) || d.scheduledTime.isBefore(oldest)) continue;
      if (d.status == DoseStatus.pending && _autoMissing.add(d.id)) {
        updateDoseStatus(d.id, DoseStatus.missed, auto: true);
      } else if (d.status == DoseStatus.missed) {
        _alertMissed(d);
      }
    }
  }

  Future<void> _alertMissed(DoseLog log) async {
    if (!_missAlerted.add(log.id)) return;
    try {
      await _createAlert(
        id: 'missed_${log.id}',
        onlyIfAbsent: true,
        type: AlertType.missedDose,
        severity: AlertSeverity.warning,
        title: 'Missed dose',
        message: '$_who has not taken ${log.medName} (${log.dosage.isEmpty ? 'due' : log.dosage}) scheduled for ${_shortTime(log.scheduledTime)} — it is now over an hour late.',
      );
    } catch (e) {
      _missAlerted.remove(log.id);
      _err('missedAlert', e);
    }
  }

  List<DoseLog> todayLogs() {
    final now = DateTime.now();
    final list = doseLogs
        .where((d) => d.scheduledTime.year == now.year && d.scheduledTime.month == now.month && d.scheduledTime.day == now.day)
        .toList();
    list.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return list;
  }

  DoseLog? get nextDose {
    final pending = todayLogs().where((d) => d.status == DoseStatus.pending).toList();
    return pending.isEmpty ? null : pending.first;
  }

  /// Records a dose. Manual actions are only allowed inside the dose window
  /// (from 15 minutes before the scheduled time) — medicine can't be marked
  /// as taken early.
  Future<void> updateDoseStatus(String id, DoseStatus status, {bool auto = false}) async {
    DoseLog? log;
    for (final d in doseLogs) {
      if (d.id == id) log = d;
    }
    if (log == null) return;
    if (!auto && !log.isOpen) {
      throw Exception('This dose opens at ${_shortTime(log.opensAt)} — 15 minutes before it is due.');
    }

    await _col('doseLogs').doc(id).update({
      'status': status.name,
      'actionTime': auto ? null : Timestamp.now(),
    });

    if (status == DoseStatus.taken) {
      final med = medicationById(log.medicationId);
      if (med != null && med.stock > 0) {
        await _col('medications').doc(med.id).update({'stock': FieldValue.increment(-1)});
      }
    }

    // Caregivers hear about a missed dose once it is an hour overdue.
    if (status == DoseStatus.missed && !DateTime.now().isBefore(log.scheduledTime.add(kDoseMissAfter))) {
      await _alertMissed(log);
    }
  }

  String _shortTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ── AI risk ────────────────────────────────────────────────────────
  RiskResult? _apiRisk;
  String? _apiRiskKey;
  String? _apiRiskInFlight;

  Timer? _riskRetry;

  /// Risk comes from the trained logistic-regression model on the cloud API
  /// only — there is no on-device formula. While the API is answering the
  /// gauge shows "calculating"; if it cannot be reached it shows
  /// "unavailable" and retries automatically.
  void _recomputeRisk() {
    final payload = RiskPredictor.apiPayload(
      logs: doseLogs,
      medicationCount: medications.length,
      age: elderly.age,
      conditionCount: elderly.conditions.length,
      vitals: vitals,
      alerts: alerts,
      symptoms: symptoms,
    );
    if (payload == null) {
      risk = RiskResult.empty(); // fewer than 3 recorded doses
      _apiRisk = null;
      _apiRiskKey = null;
      return;
    }
    if (!RiskApiService.enabled) {
      risk = RiskResult.unavailable();
      return;
    }

    final key = jsonEncode(payload);
    if (key == _apiRiskKey && _apiRisk != null) {
      risk = _apiRisk!; // nothing changed since the last API answer
      return;
    }
    if (_apiRisk != null) {
      risk = _apiRisk!; // keep showing the last answer while the new one loads
    } else if (!risk.hasData && risk.factors.first != RiskResult.unavailable().factors.first) {
      risk = RiskResult.loading();
    }
    if (key == _apiRiskInFlight) return;
    _apiRiskInFlight = key;
    RiskApiService.predict(payload).then((r) {
      if (_apiRiskInFlight != key) return; // a newer request superseded this one
      _apiRiskInFlight = null;
      if (r == null) {
        if (_apiRisk == null) risk = RiskResult.unavailable();
        notifyListeners();
        _riskRetry?.cancel();
        _riskRetry = Timer(const Duration(seconds: 45), _recomputeRisk);
        return;
      }
      _apiRisk = r;
      _apiRiskKey = key;
      risk = r;
      notifyListeners();
      _maybeRiskAlert();
    });
  }

  void _maybeRiskAlert() {
    if (!isElderly || !_doseLoaded || !_alertsLoaded) return;
    if (risk.level != RiskLevel.high) return;
    final n = DateTime.now();
    final id = 'risk_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
    if (alerts.any((a) => a.id == id)) return;
    _createAlert(
      id: id,
      type: AlertType.missedDose,
      severity: AlertSeverity.critical,
      title: 'Rising missed-dose risk',
      message: 'The risk model estimates a ${risk.percent}% chance $_who misses the next dose.',
    );
  }

  /// Share of recorded doses that were taken, or null when nothing has been
  /// recorded yet (the UI shows "—" rather than a fake 100 %).
  double? adherenceRate({int days = 14}) {
    final now = DateTime.now();
    final window = doseLogs.where((d) =>
        d.scheduledTime.isAfter(now.subtract(Duration(days: days))) &&
        d.scheduledTime.isBefore(now) &&
        d.status != DoseStatus.pending);
    if (window.isEmpty) return null;
    final taken = window.where((d) => d.status == DoseStatus.taken).length;
    return taken / window.length;
  }

  // ════════════════════════════════════════════════════════════════════
  // Appointments / symptoms / vitals
  // ════════════════════════════════════════════════════════════════════

  Future<void> addAppointment(Appointment a) => _col('appointments').doc(a.id).set(a.toMap());

  Future<void> deleteAppointment(String id) => _col('appointments').doc(id).delete();

  List<Appointment> get upcomingAppointments =>
      appointments.where((a) => a.dateTime.isAfter(DateTime.now())).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  Future<void> addSymptom(SymptomLog s) async {
    await _col('symptoms').doc(s.id).set(s.toMap());
    if (s.severity >= 4) {
      await _createAlert(
        type: AlertType.symptom,
        severity: s.severity >= 5 ? AlertSeverity.critical : AlertSeverity.warning,
        title: 'Symptom reported: ${s.symptom}',
        message: '$_who logged "${s.symptom}" at severity ${s.severity}/5.',
      );
    }
  }

  Future<void> addVital({
    required int heartRate,
    required int oxygen,
    required int steps,
    DateTime? time,
    String source = 'manual',
    String sourceApp = '',
  }) async {
    final reading = VitalReading(id: newId(), time: time ?? DateTime.now(), heartRate: heartRate, oxygenLevel: oxygen, steps: steps, source: source, sourceApp: sourceApp);
    await _col('vitals').doc(reading.id).set(reading.toMap());
    // Only alert caregivers about readings that are fresh — an automatic sync can
    // pick up an old out-of-range reading and must not raise a false alarm.
    final fresh = DateTime.now().difference(reading.time) < const Duration(minutes: 30);
    if (reading.isAbnormal && fresh) {
      final what = reading.problems.join(' and ');
      await _createAlert(
        type: AlertType.abnormalVital,
        severity: reading.isCritical ? AlertSeverity.critical : AlertSeverity.warning,
        title: reading.oxygenLow && !reading.heartAbnormal ? 'Low oxygen level' : (reading.heartAbnormal && !reading.oxygenLow ? 'Abnormal heart rate' : 'Abnormal vital signs'),
        message: '$_who recorded $what. Heart rate ${reading.heartRate} bpm, SpO2 ${reading.oxygenLevel}%.',
      );
    }
  }

  /// Latest reading if it was taken in the last 24 h and is out of range —
  /// used for the caregiver's status banner.
  VitalReading? get recentAbnormalVital {
    final v = latestVital;
    if (v == null || !v.isAbnormal) return null;
    return DateTime.now().difference(v.time) > const Duration(hours: 24) ? null : v;
  }

  /// Pending doses that are already past their time today.
  List<DoseLog> get overdueToday {
    final now = DateTime.now();
    return todayLogs().where((d) => d.status == DoseStatus.pending && d.scheduledTime.isBefore(now)).toList();
  }

  /// Newest reading that is still valid — a manual reading older than an hour
  /// no longer counts (caregivers and the home screen ignore it).
  VitalReading? get latestVital {
    for (final v in vitals) {
      if (!v.isManualStale) return v;
    }
    return null;
  }

  /// True when the newest reading was typed in and is now over an hour old.
  bool get manualReadingExpired => vitals.isNotEmpty && vitals.first.isManualStale;

  /// Id of the out-of-range reading whose warning banner the user dismissed.
  String? dismissedWarningVitalId;
  void dismissVitalWarning(String id) {
    dismissedWarningVitalId = id;
    notifyListeners();
  }

  Future<void> deleteVital(String id) async {
    // Remove it from the screen straight away (a swiped row must leave the tree at once).
    vitals.removeWhere((v) => v.id == id);
    notifyListeners();
    await _col('vitals').doc(id).delete();
  }

  /// Deletes every saved reading (and remembers when, so an automatic sync does
  /// not bring the old device readings straight back).
  Future<void> clearVitals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kVitalsClearedAtPref, DateTime.now().millisecondsSinceEpoch);
    while (true) {
      final qs = await _col('vitals').limit(400).get();
      if (qs.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Alerts
  // ════════════════════════════════════════════════════════════════════

  /// Only the elderly user's device creates alerts; the onCreate Cloud
  /// Function then fans them out to linked caregivers via FCM.
  Future<void> _createAlert({
    String? id,
    bool onlyIfAbsent = false,
    required AlertType type,
    required AlertSeverity severity,
    required String title,
    required String message,
    LocationSnapshot? location,
  }) async {
    if (!isElderly || _uid == null) return;
    var fullMessage = message;
    if (location != null) {
      final detail = await location.describe();
      if (detail.isNotEmpty) fullMessage = '$message\n$detail';
    }
    final ref = _db.collection('users').doc(_uid).collection('alerts');
    final doc = id == null ? ref.doc() : ref.doc(id);
    final item = AlertItem(
      id: doc.id,
      time: DateTime.now(),
      type: type,
      severity: severity,
      title: title,
      message: fullMessage,
      lat: location?.lat,
      lng: location?.lng,
    ).toMap();
    // onlyIfAbsent: never reset an alert a caregiver already acknowledged.
    if (onlyIfAbsent) {
      await _createIfAbsent(doc, item);
    } else {
      await doc.set(item);
    }
  }

  Future<void> acknowledgeAlert(String id) => _col('alerts').doc(id).update({'acknowledged': true});

  int get unacknowledgedCount => alerts.where((a) => !a.acknowledged).length;

  /// [location] is best-effort: SOS/fall still send instantly even if a GPS
  /// fix can't be obtained in time — the alert just omits the location line.
  Future<void> triggerSOS({LocationSnapshot? location}) => _createAlert(
        type: AlertType.sos,
        severity: AlertSeverity.critical,
        title: 'SOS emergency alert',
        message: '$_who pressed the emergency SOS button and needs immediate help.',
        location: location,
      );

  Future<void> triggerFall({LocationSnapshot? location}) => _createAlert(
        type: AlertType.fallDetected,
        severity: AlertSeverity.critical,
        title: 'Possible fall detected',
        message: '$_who\'s phone detected a fall and they did not respond in time.',
        location: location,
      );

  Future<void> triggerGeofenceAlert(bool leaving, {LocationSnapshot? location}) => _createAlert(
        type: AlertType.geofence,
        severity: leaving ? AlertSeverity.warning : AlertSeverity.info,
        title: leaving ? 'Left the safe zone' : 'Returned to the safe zone',
        message: leaving ? '$_who has moved outside the home safe zone.' : '$_who is back inside the home safe zone.',
        location: location,
      );

  // ════════════════════════════════════════════════════════════════════
  // Location
  // ════════════════════════════════════════════════════════════════════

  /// Called by LocationService on the elderly user's device.
  Future<void> publishLocation({required double lat, required double lng, required double accuracy, bool? inside, String? address}) async {
    if (!isElderly || _uid == null) return;
    final now = DateTime.now();
    final data = {
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'inside': inside,
      'address': address,
      'time': Timestamp.fromDate(now),
    };
    final user = _db.collection('users').doc(_uid);
    await user.collection('location').doc('current').set(data);
    if (_lastHistoryWrite == null || now.difference(_lastHistoryWrite!) > const Duration(minutes: 5)) {
      _lastHistoryWrite = now;
      await user.collection('locationHistory').add(data);
    }
  }

  /// Set the "home" safe zone centre. Allowed for the elderly user and any
  /// linked caregiver (see firestore.rules).
  Future<void> setHome(double lat, double lng, {double? radiusM, String? address}) {
    return _userDoc.update({
      'homeLat': lat,
      'homeLng': lng,
      if (radiusM != null) 'safeRadiusM': radiusM,
      if (address != null && address.isNotEmpty) 'homeAddress': address,
    });
  }

  // ── Emergency contacts (phone-only, non-app people) ──────────────────

  Future<void> setEmergencyContacts(List<EmergencyContact> contacts) {
    return _userDoc.update({'emergencyContacts': contacts.map((c) => c.toMap()).toList()});
  }

  // ── Profile photo ──────────────────────────────────────────────────

  /// Uploads to Cloud Storage at `avatars/{uid}.jpg` and saves the download
  /// URL on the user doc. Returns the URL, or throws on failure.
  Future<String> uploadProfilePhoto(Uint8List bytes) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in.');
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).set({'photoUrl': url}, SetOptions(merge: true));
    return url;
  }

  Future<void> removeProfilePhoto() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseStorage.instance.ref('avatars/$uid.jpg').delete();
    } catch (_) {
      // Already gone — fine.
    }
    await _db.collection('users').doc(uid).set({'photoUrl': ''}, SetOptions(merge: true));
  }

  // ════════════════════════════════════════════════════════════════════
  // Profile & settings
  // ════════════════════════════════════════════════════════════════════

  Future<void> updateProfile({String? name, DateTime? birthDate, List<String>? conditions, String? homeAddress, String? phone}) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      if (name != null) 'name': name,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(DateTime(birthDate.year, birthDate.month, birthDate.day)),
      if (birthDate != null) 'age': ageFromBirthDate(birthDate),
      if (conditions != null) 'conditions': conditions,
      if (homeAddress != null) 'homeAddress': homeAddress,
      if (phone != null) 'phone': phone,
    });
  }

  Future<void> setSharing({bool? shareLocation, bool? fallDetection}) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      if (shareLocation != null) 'shareLocation': shareLocation,
      if (fallDetection != null) 'fallDetection': fallDetection,
    });
  }

  Future<void> setNotifyPref(String key, bool value) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'notifyPrefs': {key: value},
    }, SetOptions(merge: true));
  }

  bool notifyPref(String key) => me?.notifyPrefs[key] ?? true;
}
