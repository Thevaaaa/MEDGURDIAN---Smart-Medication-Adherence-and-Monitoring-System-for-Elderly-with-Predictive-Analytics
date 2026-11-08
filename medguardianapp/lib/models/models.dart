import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


enum UserRole { elderly, caregiver }

enum DoseStatus { pending, taken, missed, skipped }

enum RiskLevel { low, moderate, high }

enum AlertType { missedDose, fallDetected, sos, abnormalVital, symptom, geofence, appointment, test }

enum AlertSeverity { info, warning, critical }

T _enumByName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime _dt(dynamic v, [DateTime? fallback]) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return fallback ?? DateTime.now();
}

DateTime? _dtOrNull(dynamic v) => v is Timestamp ? v.toDate() : null;

/// Whole years between [birth] and today — so a stored birth date keeps the
/// displayed age correct every year without anyone editing it.
int ageFromBirthDate(DateTime birth, [DateTime? now]) {
  final n = now ?? DateTime.now();
  var years = n.year - birth.year;
  if (n.month < birth.month || (n.month == birth.month && n.day < birth.day)) years--;
  return years < 0 ? 0 : years;
}

/// How early a dose may be marked as taken (and when the reminder fires).
const Duration kDoseEarlyWindow = Duration(minutes: 15);

/// A dose still not taken this long after its time counts as missed and the
/// caregiver is notified.
const Duration kDoseMissAfter = Duration(hours: 1);

/// How long a manually-entered vital reading stays valid.
const Duration kManualReadingLife = Duration(hours: 1);

const _avatarPalette = [
  Color(0xFF1F6F6B),
  Color(0xFFE0824A),
  Color(0xFF3E7CB1),
  Color(0xFF9B6BC7),
  Color(0xFF3FA772),
  Color(0xFFD1587A),
];

/// Stable colour for an id (String.hashCode is not stable across runs).
Color colorForId(String id) {
  var sum = 0;
  for (final c in id.codeUnits) {
    sum += c;
  }
  return _avatarPalette[sum % _avatarPalette.length];
}

/// ── Medication & adherence ────────────────────────────────────────────

class MedTime {
  final int hour;
  final int minute;
  const MedTime(this.hour, this.minute);

  TimeOfDay get asTimeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get label {
    final tod = asTimeOfDay;
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final p = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Map<String, dynamic> toMap() => {'h': hour, 'm': minute};

  factory MedTime.fromMap(Map<String, dynamic> m) => MedTime((m['h'] ?? 8) as int, (m['m'] ?? 0) as int);
}

/// Icons are stored by key (never by code point) so release builds can
/// still tree-shake the icon font.
class MedIcons {
  MedIcons._();
  static const Map<String, IconData> all = {
    'pill': Icons.medication_rounded,
    'heart': Icons.favorite_rounded,
    'drop': Icons.bloodtype_rounded,
    'moon': Icons.nightlight_round,
    'pharmacy': Icons.local_pharmacy_rounded,
    'heal': Icons.healing_rounded,
  };
  static IconData byKey(String key) => all[key] ?? Icons.medication_rounded;
}

class Medication {
  final String id;
  String name;
  String dosage;
  String instructions;
  List<MedTime> times;
  Color color;
  String iconKey;
  int stock;

  /// Cloud Storage download URL of a photo of the pack / pill ('' if none).
  String photoUrl;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.instructions,
    required this.times,
    required this.color,
    this.iconKey = 'pill',
    this.stock = 30,
    this.photoUrl = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get icon => MedIcons.byKey(iconKey);
  bool get hasPhoto => photoUrl.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'dosage': dosage,
        'instructions': instructions,
        'times': times.map((t) => t.toMap()).toList(),
        'color': color.value,
        'icon': iconKey,
        'stock': stock,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Medication.fromMap(String id, Map<String, dynamic> m) => Medication(
        id: id,
        name: (m['name'] ?? '') as String,
        dosage: (m['dosage'] ?? '') as String,
        instructions: (m['instructions'] ?? '') as String,
        times: ((m['times'] ?? []) as List).map((e) => MedTime.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
        color: Color((m['color'] ?? 0xFF1F6F6B) as int),
        iconKey: (m['icon'] ?? 'pill') as String,
        stock: (m['stock'] ?? 0) as int,
        photoUrl: (m['photoUrl'] ?? '') as String,
        createdAt: _dt(m['createdAt']),
      );
}

class DoseLog {
  final String id;
  final String medicationId;
  final String medName;
  final String dosage;
  final DateTime scheduledTime;
  DateTime? actionTime;
  DoseStatus status;

  DoseLog({
    required this.id,
    required this.medicationId,
    required this.medName,
    required this.dosage,
    required this.scheduledTime,
    this.actionTime,
    this.status = DoseStatus.pending,
  });

  /// First moment the dose can be recorded (15 minutes before its time).
  DateTime get opensAt => scheduledTime.subtract(kDoseEarlyWindow);

  /// Pending doses are locked until [opensAt] — no taking medicine early.
  bool get isOpen => !DateTime.now().isBefore(opensAt);

  /// `advanceSentAt` / `exactSentAt` are stamped by the Cloud Function that
  /// sends the FCM dose reminders.
  Map<String, dynamic> toMap() => {
        'medicationId': medicationId,
        'medName': medName,
        'dosage': dosage,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'actionTime': actionTime == null ? null : Timestamp.fromDate(actionTime!),
        'status': status.name,
        'advanceSentAt': null,
        'exactSentAt': null,
      };

  factory DoseLog.fromMap(String id, Map<String, dynamic> m) => DoseLog(
        id: id,
        medicationId: (m['medicationId'] ?? '') as String,
        medName: (m['medName'] ?? 'Medication') as String,
        dosage: (m['dosage'] ?? '') as String,
        scheduledTime: _dt(m['scheduledTime']),
        actionTime: _dtOrNull(m['actionTime']),
        status: _enumByName(DoseStatus.values, m['status'], DoseStatus.pending),
      );
}

/// ── Appointments ───────────────────────────────────────────────────────

class Appointment {
  final String id;
  String title;
  String location;
  DateTime dateTime;
  String notes;

  Appointment({
    required this.id,
    required this.title,
    required this.location,
    required this.dateTime,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'location': location,
        'dateTime': Timestamp.fromDate(dateTime),
        'notes': notes,
        'remind24hSentAt': null,
        'remind1hSentAt': null,
      };

  factory Appointment.fromMap(String id, Map<String, dynamic> m) => Appointment(
        id: id,
        title: (m['title'] ?? '') as String,
        location: (m['location'] ?? '') as String,
        dateTime: _dt(m['dateTime']),
        notes: (m['notes'] ?? '') as String,
      );
}

/// ── Symptoms & vitals ──────────────────────────────────────────────────

class SymptomLog {
  final String id;
  final DateTime time;
  final String symptom;
  final int severity; // 1 (mild) .. 5 (severe)
  final String note;

  SymptomLog({
    required this.id,
    required this.time,
    required this.symptom,
    required this.severity,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'time': Timestamp.fromDate(time),
        'symptom': symptom,
        'severity': severity,
        'note': note,
      };

  factory SymptomLog.fromMap(String id, Map<String, dynamic> m) => SymptomLog(
        id: id,
        time: _dt(m['time']),
        symptom: (m['symptom'] ?? '') as String,
        severity: (m['severity'] ?? 1) as int,
        note: (m['note'] ?? '') as String,
      );
}

class VitalReading {
  final String id;
  final DateTime time;
  final int heartRate; // bpm
  final int oxygenLevel; // %
  final int steps;

  /// Where the reading came from: 'manual' (typed in) or 'health_connect'
  /// (a watch / phone via Health Connect or Apple Health).
  final String source;

  /// Which app on the phone supplied a device reading (e.g. "Samsung Health").
  final String sourceApp;

  VitalReading({
    required this.id,
    required this.time,
    required this.heartRate,
    required this.oxygenLevel,
    required this.steps,
    this.source = 'manual',
    this.sourceApp = '',
  });

  bool get fromDevice => source == 'health_connect';

  /// A reading typed in by hand is only trusted for [kManualReadingLife]; after
  /// that the person has to measure and enter it again.
  bool get isManualStale => !fromDevice && DateTime.now().difference(time) > kManualReadingLife;

  /// Minutes left before a manual reading expires (0 when expired / from a device).
  int get manualMinutesLeft => fromDevice ? 0 : (kManualReadingLife - DateTime.now().difference(time)).inMinutes.clamp(0, 999);

  /// Human-readable origin, e.g. "Samsung Health · Health Connect" or "Entered manually".
  String get sourceLabel => fromDevice ? (sourceApp.isEmpty ? 'Health Connect' : '$sourceApp · Health Connect') : 'Entered manually';

  /// Resting heart rate outside 50–120 bpm.
  bool get heartAbnormal => heartRate > 0 && (heartRate < 50 || heartRate > 120);

  /// SpO2 below 95 % is low; below 92 % needs urgent attention.
  bool get oxygenLow => oxygenLevel > 0 && oxygenLevel < 95;
  bool get oxygenCritical => oxygenLevel > 0 && oxygenLevel < 92;

  /// Either metric out of range — heart rate OR oxygen.
  bool get isAbnormal => heartAbnormal || oxygenLow;

  /// Severe enough to raise a critical alert.
  bool get isCritical => (heartRate > 0 && (heartRate < 40 || heartRate > 140)) || oxygenCritical;

  /// Plain-language list of what is out of range, e.g. "low oxygen (90%)".
  List<String> get problems => [
        if (heartRate > 0 && heartRate < 50) 'low heart rate ($heartRate bpm)',
        if (heartRate > 120) 'high heart rate ($heartRate bpm)',
        if (oxygenLow) 'low oxygen ($oxygenLevel%)',
      ];

  Map<String, dynamic> toMap() => {
        'time': Timestamp.fromDate(time),
        'heartRate': heartRate,
        'oxygenLevel': oxygenLevel,
        'steps': steps,
        'source': source,
        'sourceApp': sourceApp,
      };

  factory VitalReading.fromMap(String id, Map<String, dynamic> m) => VitalReading(
        id: id,
        time: _dt(m['time']),
        heartRate: (m['heartRate'] ?? 0) as int,
        oxygenLevel: (m['oxygenLevel'] ?? 0) as int,
        steps: (m['steps'] ?? 0) as int,
        source: (m['source'] ?? 'manual') as String,
        sourceApp: (m['sourceApp'] ?? '') as String,
      );
}

/// ── Alerts ─────────────────────────────────────────────────────────────

class AlertItem {
  final String id;
  final DateTime time;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  bool acknowledged;
  final double? lat;
  final double? lng;

  AlertItem({
    required this.id,
    required this.time,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.acknowledged = false,
    this.lat,
    this.lng,
  });

  bool get hasLocation => lat != null && lng != null;
  String get mapsUrl => hasLocation ? 'https://maps.google.com/?q=$lat,$lng' : '';

  IconData get icon {
    switch (type) {
      case AlertType.missedDose:
        return Icons.medication_liquid_rounded;
      case AlertType.fallDetected:
        return Icons.personal_injury_rounded;
      case AlertType.sos:
        return Icons.sos_rounded;
      case AlertType.abnormalVital:
        return Icons.monitor_heart_rounded;
      case AlertType.symptom:
        return Icons.sick_rounded;
      case AlertType.geofence:
        return Icons.location_off_rounded;
      case AlertType.appointment:
        return Icons.event_rounded;
      case AlertType.test:
        return Icons.notifications_active_rounded;
    }
  }

  Map<String, dynamic> toMap() => {
        'time': Timestamp.fromDate(time),
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'message': message,
        'acknowledged': acknowledged,
        'lat': lat,
        'lng': lng,
      };

  factory AlertItem.fromMap(String id, Map<String, dynamic> m) => AlertItem(
        id: id,
        time: _dt(m['time']),
        type: _enumByName(AlertType.values, m['type'], AlertType.symptom),
        severity: _enumByName(AlertSeverity.values, m['severity'], AlertSeverity.info),
        title: (m['title'] ?? '') as String,
        message: (m['message'] ?? '') as String,
        acknowledged: (m['acknowledged'] ?? false) as bool,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}

/// ── People ─────────────────────────────────────────────────────────────

/// The signed-in user (either role).
class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String phone;
  final String photoUrl;

  /// Caregiver push preferences (keys: missedDose, health, geofence).
  final Map<String, bool> notifyPrefs;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.photoUrl = '',
    this.notifyPrefs = const {},
  });

  Color get color => colorForId(uid);

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: (m['name'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        photoUrl: (m['photoUrl'] ?? '') as String,
        role: _enumByName(UserRole.values, m['role'], UserRole.elderly),
        phone: (m['phone'] ?? '') as String,
        notifyPrefs: {
          for (final e in ((m['notifyPrefs'] ?? {}) as Map).entries) e.key as String: e.value == true,
        },
      );
}

/// An elderly person being cared for (the signed-in user for the elderly
/// role, or the currently selected dependent for a caregiver).
class ElderlyProfile {
  final String uid;
  String name;
  int age;
  DateTime? birthDate;
  List<String> conditions;
  String homeAddress;
  String phone;
  String photoUrl;
  String linkCode;
  double? homeLat;
  double? homeLng;
  double safeRadiusM;
  bool shareLocation;
  bool fallDetection;
  List<EmergencyContact> emergencyContacts;

  ElderlyProfile({
    this.uid = '',
    this.name = '',
    this.age = 0,
    this.birthDate,
    this.conditions = const [],
    this.homeAddress = '',
    this.phone = '',
    this.photoUrl = '',
    this.linkCode = '',
    this.homeLat,
    this.homeLng,
    this.safeRadiusM = 200,
    this.shareLocation = true,
    this.emergencyContacts = const [],
    this.fallDetection = true,
  });

  Color get color => uid.isEmpty ? const Color(0xFF1F6F6B) : colorForId(uid);
  bool get hasHome => homeLat != null && homeLng != null;

  factory ElderlyProfile.fromMap(String uid, Map<String, dynamic> m) {
    final birth = _dtOrNull(m['birthDate']);
    return ElderlyProfile(
        uid: uid,
        name: (m['name'] ?? '') as String,
        // Age is derived from the birth date so it rolls over every birthday;
        // older accounts without a birth date fall back to the stored age.
        age: birth != null ? ageFromBirthDate(birth) : ((m['age'] ?? 0) as num).toInt(),
        birthDate: birth,
        conditions: ((m['conditions'] ?? []) as List).map((e) => e.toString()).toList(),
        homeAddress: (m['homeAddress'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        photoUrl: (m['photoUrl'] ?? '') as String,
        linkCode: (m['linkCode'] ?? '') as String,
        homeLat: (m['homeLat'] as num?)?.toDouble(),
        homeLng: (m['homeLng'] as num?)?.toDouble(),
        safeRadiusM: ((m['safeRadiusM'] ?? 200) as num).toDouble(),
        shareLocation: (m['shareLocation'] ?? true) as bool,
        fallDetection: (m['fallDetection'] ?? true) as bool,
        emergencyContacts: ((m['emergencyContacts'] ?? []) as List)
            .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
  }
}

/// A phone-only contact (not necessarily a MedGuardian user) notified by SMS
/// on SOS / fall alerts if the server's SMS gateway is configured — see
/// SETUP.md. Stored as an array field directly on the elderly user's doc.
class EmergencyContact {
  String name;
  String phone;
  String relation;

  EmergencyContact({required this.name, required this.phone, this.relation = ''});

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'relation': relation};

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        relation: (m['relation'] ?? '') as String,
      );
}

/// A caregiver linked to an elderly user (denormalised on the link doc).
class Caregiver {
  final String linkId;
  final String uid;
  final String name;
  final String relation;
  final String phone;
  final String photoUrl;

  const Caregiver({required this.linkId, required this.uid, required this.name, required this.relation, required this.phone, this.photoUrl = ''});

  Color get color => colorForId(uid);

  factory Caregiver.fromLink(String linkId, Map<String, dynamic> m) => Caregiver(
        linkId: linkId,
        uid: (m['caregiverId'] ?? '') as String,
        name: (m['caregiverName'] ?? 'Caregiver') as String,
        relation: (m['relation'] ?? '') as String,
        phone: (m['caregiverPhone'] ?? '') as String,
        photoUrl: (m['caregiverPhotoUrl'] ?? '') as String,
      );
}

/// ── Location ───────────────────────────────────────────────────────────

class LocationPoint {
  final double lat;
  final double lng;
  final DateTime time;
  final bool? inside; // null when no home is configured
  final double accuracy;
  final String? address; // reverse-geocoded, when available

  const LocationPoint({required this.lat, required this.lng, required this.time, this.inside, this.accuracy = 0, this.address});

  String get label => address ?? (inside == null ? 'Location update' : (inside! ? 'Near home' : 'Away from home'));

  String get mapsUrl => 'https://maps.google.com/?q=$lat,$lng';

  factory LocationPoint.fromMap(Map<String, dynamic> m) => LocationPoint(
        lat: ((m['lat'] ?? 0) as num).toDouble(),
        lng: ((m['lng'] ?? 0) as num).toDouble(),
        time: _dt(m['time']),
        inside: m['inside'] as bool?,
        accuracy: ((m['accuracy'] ?? 0) as num).toDouble(),
        address: m['address'] as String?,
      );
}
