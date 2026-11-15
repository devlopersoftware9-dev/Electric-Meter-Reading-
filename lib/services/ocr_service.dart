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

  void dispose() => _recognizer.close();
}
