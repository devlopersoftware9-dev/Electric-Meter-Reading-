import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meter.dart';
import '../services/bill_service.dart';
import '../services/meter_store.dart';
import '../services/ocr_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.meterId});
  final String meterId;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _value = TextEditingController();
  String? _imagePath;
  bool _busy = false;
  bool _fromPhoto = false;
  String? _error;

  Meter? get _meter => MeterStore.instance.byId(widget.meterId);

  @override
  void dispose() {
    _ocr.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    final meter = _meter;
    if (meter == null) return;
    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 90);
    } catch (_) {
      setState(() => _error = 'Could not open the camera.');
      return;
    }
    if (file == null) return;
    final path = file.path;
    setState(() {
      _imagePath = path;
      _busy = true;
      _error = null;
    });
    try {
      final r = await _ocr.read(path, lastReading: meter.billReading);
      if (!mounted) return;
      if (r.best != null) {
        _value.text = r.best.toString().padLeft(5, '0');
        _fromPhoto = true;
      } else {
        _error = 'Could not read the digits. Please type the reading.';
      }
    } catch (_) {
      _error = 'Could not read the photo. Please type the reading.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Meter m) async {
    final v = int.tryParse(_value.text);
    if (v == null) {
      setState(() => _error = 'Enter the reading shown on your meter.');
      return;
    }
    if (m.billReading != null && v < m.billReading!) {
      setState(() => _error = 'This is lower than the last bill reading (${fmtReading(m.billReading!)}). Please check the digits.');
      return;
    }
    await MeterStore.instance
        .addReading(m, Reading(date: DateTime.now(), value: v, source: _fromPhoto ? 'photo' : 'manual'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading saved')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = _meter;
    if (m == null) return const Scaffold();
    final v = int.tryParse(_value.text);
    final stats = v == null ? null : m.statsFor(v, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.camera,
      appBar: AppBar(
        backgroundColor: AppColors.camera,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(children: [
          const Text('Scan reading', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          Text('${m.name} · ${BillService.companyName(m.company)}',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedOnDark)),
        ]),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 300,
                color: const Color(0xFF1C2433),
                child: Stack(fit: StackFit.expand, children: [
                  if (_imagePath != null) Image.file(File(_imagePath!), fit: BoxFit.cover),
                  Center(
                    child: Container(
                      width: 232,
                      height: 96,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.highlight, width: 3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (_busy) const Center(child: CircularProgressIndicator(color: AppColors.highlight)),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Text('Fit the digits inside the yellow box',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Pick from gallery',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.navyLine),
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                const SizedBox(width: 40),
                Semantics(
                  label: 'Take photo',
                  button: true,
                  child: GestureDetector(
                    onTap: _busy ? null : () => _capture(ImageSource.camera),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.highlight,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: AppColors.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 88),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fromPhoto ? 'Reading detected' : 'Current reading', style: titleStyle(18)),
                    if (_fromPhoto)
                      const StatusChip(StatusStyle('Check digits', AppColors.primaryTint, AppColors.primaryDark,
                          AppColors.primary, AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Current reading (tap to correct)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                  style: numStyle(30).copyWith(letterSpacing: 3),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(
                        child: StatBlock('Last bill', m.billReading == null ? '–' : fmtReading(m.billReading!),
                            valueSize: 16)),
                    Expanded(child: StatBlock('Now', v == null ? '–' : fmtReading(v), valueSize: 16)),
                    Expanded(
                        child: StatBlock('Units used', stats == null ? '–' : '${stats.units}',
                            valueSize: 16, valueColor: AppColors.primary)),
                  ]),
                ),
                if (stats != null && stats.status != SlabStatus.ok) ...[
                  const SizedBox(height: 14),
                  WarningBox(
                      'Expected ≈ ${stats.projected} units by ${fmtDate(stats.nextReading)}, which is ${stats.projected > 200 ? 'above' : 'close to'} the 200-unit slab.'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  WarningBox(_error!),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _capture(ImageSource.camera),
                      child: Text(_imagePath == null ? 'Take photo' : 'Retake'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      onPressed: _busy || v == null ? null : () => _save(m),
                      child: const Text('Save reading'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
