import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final int? best;
  final List<int> candidates;
  const OcrResult(this.best, this.candidates);
}

/// Reads the meter digits from a photo with on-device ML Kit.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> read(String imagePath, {int? lastReading}) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final candidates = <int>{};
    for (final block in result.blocks) {
      for (final line in block.lines) {
        // Common OCR mix-ups on 7-segment displays.
        final t = line.text
            .replaceAll(RegExp(r'[oOD]'), '0')
            .replaceAll(RegExp(r'[lI|]'), '1')
            .replaceAll(RegExp(r'[sS]'), '5')
            .replaceAll(' ', '');
        for (final m in RegExp(r'\d{4,7}').allMatches(t)) {
          candidates.add(int.parse(m.group(0)!));
        }
      }
    }
    final list = candidates.toList();
    return OcrResult(pickBest(list, lastReading), list);
  }

  /// The best guess is the smallest number that is at or above the last bill
  /// reading (a meter only goes up). Without a last reading, the longest number.
  static int? pickBest(List<int> c, int? lastReading) {
    if (c.isEmpty) return null;
    if (lastReading != null) {
      final valid = c.where((v) => v >= lastReading && v - lastReading <= 5000).toList()..sort();
      if (valid.isNotEmpty) return valid.first;
    }
    final sorted = [...c]..sort((a, b) => b.toString().length.compareTo(a.toString().length));
    return sorted.first;
  }

  /// Finds the 14-digit reference number on a photo of an electricity bill.
  /// Returns it formatted as "07 11234 1234567" (plus " U"/" R" if printed),
  /// or null when no 14-digit number is found.
  Future<String?> readReference(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final lines = <String>[
      for (final block in result.blocks)
        for (final line in block.lines) line.text,
    ];
    return pickReference(lines);
  }

  /// Picks the reference number from OCR text lines. A number on (or just
  /// after) a line that says "REFERENCE"/"REF" wins; then one whose company
  /// code is known; then the first 14-digit number.
  static String? pickReference(List<String> lines) {
    final found = <({String digits, String? suffix, int line})>[];
    final span = RegExp(r'[0-9OoIl][0-9OoIl \-]{11,26}[0-9OoIl](\s*[URur]\b)?');
    for (var i = 0; i < lines.length; i++) {
      for (final m in span.allMatches(lines[i])) {
        final raw = m.group(0)!;
        final digits = raw
            .replaceAll(RegExp(r'[Oo]'), '0')
            .replaceAll(RegExp(r'[Il]'), '1')
            .replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length != 14) continue;
        final suffix = m.group(1)?.trim().toUpperCase();
        found.add((digits: digits, suffix: suffix, line: i));
      }
    }
    if (found.isEmpty) return null;

    bool nearRefLabel(int line) {
      for (var k = line; k >= 0 && k >= line - 1; k--) {
        if (RegExp(r'REF', caseSensitive: false).hasMatch(lines[k])) return true;
      }
      return false;
    }

    final best = found.firstWhere(
      (f) => nearRefLabel(f.line),
      orElse: () => found.firstWhere(
        (f) => _knownCompanyCodes.contains(f.digits.substring(2, 4)),
        orElse: () => found.first,
      ),
    );
    final b = StringBuffer()
      ..write('${best.digits.substring(0, 2)} ${best.digits.substring(2, 7)} ${best.digits.substring(7)}');
    if (best.suffix != null) b.write(' ${best.suffix}');
    return b.toString();
  }

  static const _knownCompanyCodes = {'11', '12', '13', '14', '15', '26', '37', '38', '48', '59'};

  void dispose() => _recognizer.close();
}
