import 'dart:math';

class MonthUsage {
  final String label;
  final int units;

  const MonthUsage(this.label, this.units);

  Map<String, dynamic> toJson() => {'label': label, 'units': units};

  factory MonthUsage.fromJson(Map<String, dynamic> j) =>
      MonthUsage(j['label'] as String? ?? '', (j['units'] as num?)?.toInt() ?? 0);
}

class Reading {
  final DateTime date;
  final int value;

  /// 'photo' or 'manual'
  final String source;

  const Reading({required this.date, required this.value, required this.source});

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'value': value, 'source': source};

  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
        date: DateTime.parse(j['date'] as String),
        value: (j['value'] as num).toInt(),
        source: j['source'] as String? ?? 'photo',
      );
}

enum SlabStatus { ok, near, over, unknown }

/// Numbers for the current billing cycle.
class CycleStats {
  final int units;
  final double dailyAvg;
  final int projected;
  final int daysRemaining;
  final DateTime nextReading;

  const CycleStats({
    required this.units,
    required this.dailyAvg,
    required this.projected,
    required this.daysRemaining,
    required this.nextReading,
  });

  SlabStatus get status {
    if (projected > 200) return SlabStatus.over;
    if (projected >= 180) return SlabStatus.near;
    return SlabStatus.ok;
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A date in [year]/[month] with [day] clamped to the month length.
DateTime dateWithDay(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(day, lastDay));
}

/// The most recent date (on or before [from]) that falls on [day].
DateTime lastOccurrence(int day, DateTime from) {
  final f = dateOnly(from);
  var c = dateWithDay(f.year, f.month, day);
  if (c.isAfter(f)) c = dateWithDay(f.year, f.month - 1, day);
  return c;
}

class Meter {
  final String id;
  String name;
  String ref;
  String? company;
  int readingDay;

  /// The PRESENT reading printed on the latest bill (start of this cycle).
  int? billReading;
  DateTime? billDate;
  int? billUnits;
  List<MonthUsage> history;
  List<Reading> readings;
  DateTime? lastSynced;

  Meter({
    required this.id,
    required this.name,
    required this.ref,
    this.company,
    this.readingDay = 1,
    this.billReading,
    this.billDate,
    this.billUnits,
    List<MonthUsage>? history,
    List<Reading>? readings,
    this.lastSynced,
  })  : history = history ?? [],
        readings = readings ?? [];

  String get maskedRef =>
      ref.length > 4 ? '•••${ref.substring(ref.length - 4)}' : ref;

  String get prettyRef => ref.length == 14
      ? '${ref.substring(0, 2)} ${ref.substring(2, 7)} ${ref.substring(7)}'
      : ref;

  DateTime get cycleStart => billDate ?? lastOccurrence(readingDay, DateTime.now());

  DateTime nextReadingDate({DateTime? from}) {
    final f = dateOnly(from ?? DateTime.now());
    var c = dateWithDay(f.year, f.month, readingDay);
    if (!c.isAfter(f)) c = dateWithDay(f.year, f.month + 1, readingDay);
    return c;
  }

  int get daysLeft =>
      nextReadingDate().difference(dateOnly(DateTime.now())).inDays;

  /// Readings taken in the current cycle, oldest first.
  List<Reading> get cycleReadings {
    final start = dateOnly(cycleStart);
    final list = readings.where((r) => !dateOnly(r.date).isBefore(start)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Reading? get latestReading {
    final c = cycleReadings;
    return c.isEmpty ? null : c.last;
  }

  CycleStats? statsFor(int value, DateTime date) {
    final base = billReading;
    if (base == null) return null;
    final units = value - base;
    if (units < 0) return null;
    var days = date.difference(cycleStart).inMinutes / 1440.0;
    if (days < 1) days = 1;
    final avg = units / days;
    final next = nextReadingDate(from: date);
    final remaining = next.difference(dateOnly(date)).inDays;
    return CycleStats(
      units: units,
      dailyAvg: avg,
      projected: (units + avg * remaining).round(),
      daysRemaining: remaining,
      nextReading: next,
    );
  }

  CycleStats? get stats {
    final l = latestReading;
    return l == null ? null : statsFor(l.value, l.date);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ref': ref,
        'company': company,
        'readingDay': readingDay,
        'billReading': billReading,
        'billDate': billDate?.toIso8601String(),
        'billUnits': billUnits,
        'history': history.map((h) => h.toJson()).toList(),
        'readings': readings.map((r) => r.toJson()).toList(),
        'lastSynced': lastSynced?.toIso8601String(),
      };

  factory Meter.fromJson(Map<String, dynamic> j) => Meter(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Meter',
        ref: j['ref'] as String? ?? '',
        company: j['company'] as String?,
        readingDay: (j['readingDay'] as num?)?.toInt() ?? 1,
        billReading: (j['billReading'] as num?)?.toInt(),
        billDate: j['billDate'] == null ? null : DateTime.tryParse(j['billDate'] as String),
        billUnits: (j['billUnits'] as num?)?.toInt(),
        history: ((j['history'] as List?) ?? [])
            .map((e) => MonthUsage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        readings: ((j['readings'] as List?) ?? [])
            .map((e) => Reading.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        lastSynced: j['lastSynced'] == null ? null : DateTime.tryParse(j['lastSynced'] as String),
      );
}
