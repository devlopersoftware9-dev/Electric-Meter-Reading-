import 'package:flutter/services.dart';

/// Formats a bill reference number as "07 11234 1234567" (batch · subdivision
/// · account) while the user types, with an optional Urban/Rural letter at the
/// end ("07 11234 1234567 U"). Spaces are added automatically; any other
/// characters are dropped. Works with the normal (alphabet) keyboard.
class RefNumberFormatter extends TextInputFormatter {
  static const maxDigits = 14;

  static String digitsOf(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// The U/R letter typed after all 14 digits, if any.
  static String? suffixOf(String s, int digitCount) {
    if (digitCount < maxDigits) return null;
    final m = RegExp(r'[0-9][^0-9]*([URur])[^0-9]*$').firstMatch(s);
    return m?.group(1)!.toUpperCase();
  }

  static String format(String digits, [String? suffix]) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 7) b.write(' ');
      b.write(digits[i]);
    }
    if (suffix != null && digits.length == maxDigits) b.write(' $suffix');
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = digitsOf(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);

    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    var before = digitsOf(newValue.text.substring(0, cursor)).length;

    // Backspace on a space: remove the digit in front of it instead.
    final oldDigits = digitsOf(oldValue.text);
    final shrank = newValue.text.length < oldValue.text.length;
    final suffix = suffixOf(newValue.text, digits.length);
    final oldSuffix = suffixOf(oldValue.text, oldDigits.length);
    if (shrank && digits == oldDigits && suffix == oldSuffix && before > 0) {
      digits = digits.substring(0, before - 1) + digits.substring(before);
      before -= 1;
    }
    if (before > digits.length) before = digits.length;

    final text = format(digits, suffix);
    var offset = before + (before > 2 ? 1 : 0) + (before > 7 ? 1 : 0);
    if (suffix != null && before == digits.length) offset = text.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}
