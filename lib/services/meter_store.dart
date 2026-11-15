import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meter.dart';
import 'bill_service.dart';

/// Keeps all meters on the phone (shared_preferences, JSON).
class MeterStore extends ChangeNotifier {
  MeterStore._();
  static final MeterStore instance = MeterStore._();

  static const _key = 'meters_v1';
  final List<Meter> _meters = [];

  List<Meter> get meters => List.unmodifiable(_meters);

  Meter? byId(String id) {
    for (final m in _meters) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _meters
          ..clear()
          ..addAll(list.map((e) => Meter.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_meters.map((m) => m.toJson()).toList()));
  }

  Future<void> add(Meter m) async {
    _meters.add(m);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _meters.removeWhere((m) => m.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> addReading(Meter m, Reading r) async {
    m.readings.add(r);
    await _save();
    notifyListeners();
  }

  Future<void> applyBill(Meter m, BillData b) async {
    m.company = b.company;
    m.billReading = b.presentReading;
    m.billUnits = b.units;
    if (b.readingDate != null) {
      m.billDate = b.readingDate;
      m.readingDay = b.readingDate!.day;
    }
    if (b.history.isNotEmpty) m.history = b.history;
    m.lastSynced = DateTime.now();
    await _save();
    notifyListeners();
  }
}
