import 'package:bijli_meter/models/meter.dart';
import 'package:bijli_meter/services/bill_service.dart';
import 'package:bijli_meter/services/ocr_service.dart';
import 'package:bijli_meter/widgets/ref_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleBill = '''
<html><body>
<table>
  <tr><td>BILL MONTH</td><td>READING DATE</td><td>ISSUE DATE</td><td>DUE DATE</td></tr>
  <tr><td>OCT 25</td><td>27 OCT 25</td><td>29 OCT 25</td><td>08 NOV 25</td></tr>
</table>
<table>
  <tr><td>METER NO</td><td>PREVIOUS</td><td>PRESENT</td><td>MF</td><td>UNITS</td><td>STATUS</td></tr>
  <tr><td>123456</td><td>08182</td><td>08412</td><td>1</td><td>230</td><td>OK</td></tr>
</table>
<table>
  <tr><td>MONTH</td><td>UNITS</td><td>BILL</td><td>PAYMENT</td></tr>
  <tr><td>SEP25</td><td>280</td><td>9800</td><td>9800</td></tr>
  <tr><td>AUG25</td><td>330</td><td>12000</td><td>12000</td></tr>
  <tr><td>JUL25</td><td>360</td><td>13100</td><td>13100</td></tr>
</table>
</body></html>
''';

void main() {
  test('parses PITC-style bill', () {
    final b = BillService.parseBill(_sampleBill, 'lesco')!;
    expect(b.presentReading, 8412);
    expect(b.previousReading, 8182);
    expect(b.units, 230);
    expect(b.readingDate, DateTime(2025, 10, 27));
    expect(b.history.map((h) => h.units).toList(), [360, 330, 280]);
  });

  test('guesses company from reference', () {
    expect(BillService.guessCompany('07112341234567'), 'lesco');
    expect(BillService.guessCompany('08262140100430'), 'pesco');
    expect(BillService.guessCompany('02126240045901'), 'gepco');
  });

  test('OCR picks reading just above last bill', () {
    expect(OcrService.pickBest([1600, 8564, 2024], 8412), 8564);
  });

  test('forecast math', () {
    final m = Meter(id: '1', name: 'x', ref: '07112341234567', readingDay: 27,
        billReading: 8412, billDate: DateTime(2025, 10, 27));
    final s = m.statsFor(8564, DateTime(2025, 11, 15, 12))!;
    expect(s.units, 152);
    expect(s.daysRemaining, 12);
    expect(s.projected, greaterThan(200));
  });

  test('reference number gets spaces automatically', () {
    final f = RefNumberFormatter();
    TextEditingValue type(String old, String text) => f.formatEditUpdate(
        TextEditingValue(text: old, selection: TextSelection.collapsed(offset: old.length)),
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
    expect(type('', '07112341234567').text, '07 11234 1234567');
    expect(type('07 1123', '07 11234').text, '07 11234');
    expect(type('07 11234', '07 112341').text, '07 11234 1');
    expect(type('07 11234 1234567', '07 11234 12345678').text, '07 11234 1234567');
    // Backspace right after a space removes the digit before it.
    expect(type('07 1', '07 ').text, '07');
  });

  test('letters are allowed only as U/R at the end', () {
    final f = RefNumberFormatter();
    TextEditingValue type(String old, String text) => f.formatEditUpdate(
        TextEditingValue(text: old, selection: TextSelection.collapsed(offset: old.length)),
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
    expect(type('07 11234 1234567', '07 11234 1234567u').text, '07 11234 1234567 U');
    expect(type('07 11234 1234567 U', '07 11234 1234567 ').text, '07 11234 1234567');
    expect(type('07 1', '07 1a').text, '07 1');
  });

  test('finds reference number in bill OCR text', () {
    expect(
        OcrService.pickReference([
          'LAHORE ELECTRIC SUPPLY COMPANY',
          'CONNECTION DATE 12 MAR 2010',
          'REFERENCE NO',
          '07 11234 1234567 U',
          'UNITS 230 AMOUNT 9800',
        ]),
        '07 11234 1234567 U');
    expect(OcrService.pickReference(['Ref No: 07-11234-1234567']), '07 11234 1234567');
    expect(OcrService.pickReference(['nothing here 1234']), isNull);
  });
}
