import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/meter.dart';

class BillData {
  final String company;
  final int presentReading;
  final int? previousReading;
  final int? units;
  final DateTime? readingDate;
  final List<MonthUsage> history;

  const BillData({
    required this.company,
    required this.presentReading,
    this.previousReading,
    this.units,
    this.readingDate,
    this.history = const [],
  });
}

class BillException implements Exception {
  final String message;
  const BillException(this.message);
  @override
  String toString() => message;
}

/// Fetches the latest bill from the PITC portal (bill.pitc.com.pk), which
/// serves all WAPDA DISCOs. The company is detected from the reference number;
/// if that guess fails, every company is tried in turn.
class BillService {
  BillService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const companies = <String, String>{
    'lesco': 'LESCO',
    'mepco': 'MEPCO',
    'iesco': 'IESCO',
    'gepco': 'GEPCO',
    'fesco': 'FESCO',
    'pesco': 'PESCO',
    'hesco': 'HESCO',
    'sepco': 'SEPCO',
    'qesco': 'QESCO',
    'tesco': 'TESCO',
  };

  /// Digits 3-4 of the reference number (start of the subdivision code)
  /// identify the company. Unknown codes fall back to trying all companies.
  static const _prefix = <String, String>{
    '11': 'lesco',
    '12': 'gepco',
    '13': 'fesco',
    '14': 'iesco',
    '15': 'mepco',
    '26': 'pesco',
    '37': 'hesco',
    '38': 'sepco',
    '48': 'qesco',
    '59': 'tesco',
  };

  static String companyName(String? code) =>
      code == null ? 'Unknown' : (companies[code] ?? code.toUpperCase());

  static String cleanRef(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static String? guessCompany(String ref) =>
      ref.length >= 4 ? _prefix[ref.substring(2, 4)] : null;

  Future<BillData> fetch(String rawRef, {String? knownCompany}) async {
    final ref = cleanRef(rawRef);
    if (ref.length != 14) {
      throw const BillException('Reference number must be 14 digits.');
    }
    final order = <String>[];
    void push(String? c) {
      if (c != null && !order.contains(c)) order.add(c);
    }

    push(knownCompany);
    push(guessCompany(ref));
    companies.keys.forEach(push);

    var networkErrors = 0;
    for (final c in order) {
      try {
        final data = await _fetchFrom(c, ref);
        if (data != null) return data;
        networkErrors = 0;
      } catch (_) {
        networkErrors++;
        if (networkErrors >= 2) {
          throw const BillException(
              'Could not reach the bill website. Check your internet and try again.');
        }
      }
    }
    throw const BillException(
        'Bill not found for this reference number. Check the number, or enter the last reading yourself.');
  }

  Future<BillData?> _fetchFrom(String company, String ref) async {
    final uri = Uri.https('bill.pitc.com.pk', '/${company}bill/general', {'refno': ref});
    final res = await _client.get(uri, headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml',
    }).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return parseBill(res.body, company);
  }

  // ---------------------------------------------------------------- parsing

  static BillData? parseBill(String html, String company) {
    final doc = html_parser.parse(html);
    final grid = <List<String>>[];
    for (final tr in doc.querySelectorAll('tr')) {
      final cells = tr.children
          .where((e) => e.localName == 'td' || e.localName == 'th')
          .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .toList();
      if (cells.isNotEmpty) grid.add(cells);
    }

    var present = _numUnder(grid, ['PRESENT READING', 'PRESENT']);
    var previous = _numUnder(grid, ['PREVIOUS READING', 'PREVIOUS']);

    final bodyText = (doc.body?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    present ??= _numAfter(bodyText, 'PRESENT');
    previous ??= _numAfter(bodyText, 'PREVIOUS');
    if (present == null) return null;

    var units = _numUnder(grid, ['UNITS CONSUMED', 'UNITS']);
    if (previous != null && present >= previous) {
      final diff = present - previous;
      // Prefer the computed value when the parsed one looks wrong (e.g. MF != 1 is rare).
      if (units == null || units > diff * 1000 + 1000) units = diff;
    }

    final dateText = _valueUnder(grid, ['READING DATE']);
    final readingDate = dateText == null ? null : parseBillDate(dateText);

    return BillData(
      company: company,
      presentReading: present,
      previousReading: previous,
      units: units,
      readingDate: readingDate,
      history: _history(grid),
    );
  }

  static String? _valueUnder(List<List<String>> grid, List<String> keys) {
    for (final key in keys) {
      for (var i = 0; i < grid.length; i++) {
        final row = grid[i];
        for (var j = 0; j < row.length; j++) {
          final cell = row[j];
          if (cell.length > 40) continue;
          final upper = cell.toUpperCase();
          if (!upper.contains(key)) continue;
          // Value in the same cell, e.g. "PRESENT READING 08564".
          final rest = upper.replaceFirst(key, '').trim();
          if (RegExp(r'\d').hasMatch(rest) && rest.length <= 30) return rest;
          // Value in the same column of one of the next rows.
          for (var k = i + 1; k < grid.length && k <= i + 3; k++) {
            if (grid[k].length > j) {
              final v = grid[k][j];
              if (v.isNotEmpty && v.length <= 30 && RegExp(r'\d').hasMatch(v)) return v;
            }
          }
        }
      }
    }
    return null;
  }

  static int? _numUnder(List<List<String>> grid, List<String> keys) {
    final v = _valueUnder(grid, keys);
    if (v == null) return null;
    final m = RegExp(r'\d+').firstMatch(v.replaceAll(',', ''));
    return m == null ? null : int.tryParse(m.group(0)!);
  }

  static int? _numAfter(String text, String key) {
    final m = RegExp('$key(?: READING)?\\D{0,25}(\\d{2,8})').firstMatch(text);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static List<MonthUsage> _history(List<List<String>> grid) {
    for (var i = 0; i < grid.length; i++) {
      final row = grid[i];
      final mIdx = row.indexWhere((c) => c.length <= 20 && c.toUpperCase().contains('MONTH'));
      final uIdx = row.indexWhere((c) => c.length <= 20 && c.toUpperCase().contains('UNITS'));
      if (mIdx < 0 || uIdx < 0) continue;
      final out = <MonthUsage>[];
      var misses = 0;
      for (var k = i + 1; k < grid.length && out.length < 12 && misses < 3; k++) {
        final r = grid[k];
        if (r.length <= mIdx || r.length <= uIdx) {
          misses++;
          continue;
        }
        final label = r[mIdx];
        final u = int.tryParse(r[uIdx].replaceAll(RegExp(r'[^0-9]'), ''));
        if (u != null && RegExp(r'[A-Za-z]{3}').hasMatch(label) && label.length <= 12) {
          out.add(MonthUsage(label.toUpperCase(), u));
          misses = 0;
        } else {
          misses++;
        }
      }
      if (out.length >= 2) return out.reversed.toList(); // oldest first
    }
    return [];
  }

  static const _months = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  /// Parses "27 OCT 25", "27-Oct-2025" or "27/10/2025".
  static DateTime? parseBillDate(String s) {
    final t = s.toUpperCase();
    final a = RegExp(r'(\d{1,2})[\s\-/]*([A-Z]{3})[A-Z]*[\s\-/,]*(\d{2,4})').firstMatch(t);
    if (a != null) {
      final month = _months[a.group(2)];
      if (month != null) {
        return DateTime(_year(a.group(3)!), month, int.parse(a.group(1)!));
      }
    }
    final b = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(t);
    if (b != null) {
      final month = int.parse(b.group(2)!);
      if (month >= 1 && month <= 12) {
        return DateTime(_year(b.group(3)!), month, int.parse(b.group(1)!));
      }
    }
    return null;
  }

  static int _year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
}
