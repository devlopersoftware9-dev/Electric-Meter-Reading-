import 'package:flutter/services.dart';

/// Formats a 14-digit bill reference number as "07 11234 1234567"
/// (batch · subdivision · account) while the user types. Spaces are added
/// automatically; only digits are accepted.
class RefNumberFormatter extends TextInputFormatter {
  static const maxDigits = 14;

  static String format(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 7) b.write(' ');
      b.write(digits[i]);
    }
    return b.toString();
  }

  static String digitsOf(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = digitsOf(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);

    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    var before = digitsOf(newValue.text.substring(0, cursor)).length;

    // Backspace on a space: remove the digit in front of it instead.
    final oldDigits = digitsOf(oldValue.text);
    if (newValue.text.length < oldValue.text.length && digits == oldDigits && before > 0) {
      digits = digits.substring(0, before - 1) + digits.substring(before);
      before -= 1;
    }
    if (before > digits.length) before = digits.length;

    final text = format(digits);
    final offset = before + (before > 2 ? 1 : 0) + (before > 7 ? 1 : 0);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}
