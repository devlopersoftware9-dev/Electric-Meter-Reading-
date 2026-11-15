import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meter.dart';
import '../services/bill_service.dart';
import '../services/meter_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  final _name = TextEditingController();
  final _ref = TextEditingController();
  final _manualReading = TextEditingController();
  int _day = DateTime.now().day;
  BillData? _bill;
  bool _loading = false;
  String? _error;
  bool _manual = false;

  @override
  void dispose() {
    _name.dispose();
    _ref.dispose();
    _manualReading.dispose();
    super.dispose();
  }

  String get _cleanRef => BillService.cleanRef(_ref.text);

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    if (_cleanRef.length != 14) {
      setState(() => _error = 'Reference number must be 14 digits.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _bill = null;
    });
    try {
      final bill = await BillService().fetch(_cleanRef);
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _manual = false;
        if (bill.readingDate != null) _day = bill.readingDate!.day;
      });
    } on BillException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _manual = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSave =>
      _cleanRef.length == 14 && (_bill != null || (_manual && int.tryParse(_manualReading.text) != null));

  Future<void> _save() async {
    final store = MeterStore.instance;
    final name = _name.text.trim().isEmpty ? 'Meter ${store.meters.length + 1}' : _name.text.trim();
    final m = Meter(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      ref: _cleanRef,
      company: BillService.guessCompany(_cleanRef),
      readingDay: _day,
    );
    if (_bill != null) {
      await store.add(m);
      await store.applyBill(m, _bill!);
    } else {
      m.billReading = int.tryParse(_manualReading.text);
      m.billDate = lastOccurrence(_day, DateTime.now());
      await store.add(m);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add meter', style: titleStyle(20))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('Meter name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Ground Floor, Shop'),
          ),
          const SizedBox(height: 16),
          const Text('Reference number (14 digits)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _ref,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
            style: numStyle(20, weight: FontWeight.w600),
            decoration: const InputDecoration(hintText: '07 11234 1234567'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          const Text('Printed at the top of your electricity bill.',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _find,
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Find my bill'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Checking the bill website… this can take a few seconds.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          const SizedBox(height: 16),
          if (_bill != null) _BillFound(bill: _bill!),
          if (_error != null) ...[
            WarningBox(_error!),
            const SizedBox(height: 16),
          ],
          if (_manual) ...[
            Text('Enter it yourself', style: titleStyle(16)),
            const SizedBox(height: 8),
            const Text('Last reading on your bill (PRESENT reading)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _manualReading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: numStyle(20, weight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('Reading day of the month', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _day,
              items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: _canSave ? _save : null, child: const Text('Save meter')),
        ],
      ),
    );
  }
}

class _BillFound extends StatelessWidget {
  const _BillFound({required this.bill});
  final BillData bill;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Bill found · ${BillService.companyName(bill.company)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: StatBlock('Last reading', fmtReading(bill.presentReading), valueSize: 18)),
                Expanded(
                    child: StatBlock('Reading date',
                        bill.readingDate == null ? '–' : fmtDate(bill.readingDate!), valueSize: 18)),
                Expanded(child: StatBlock('Bill units', bill.units?.toString() ?? '–', valueSize: 18)),
              ]),
              if (bill.history.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('${bill.history.length} months of history loaded',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      );
}
