import 'package:flutter/material.dart';

import '../models/meter.dart';
import '../services/bill_service.dart';
import '../services/meter_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

class MeterDetailScreen extends StatefulWidget {
  const MeterDetailScreen({super.key, required this.meterId});
  final String meterId;

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen> {
  bool _refreshing = false;

  Future<void> _refresh(Meter m) async {
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bill = await BillService().fetch(m.ref, knownCompany: m.company);
      await MeterStore.instance.applyBill(m, bill);
      messenger.showSnackBar(const SnackBar(content: Text('Updated from the bill website')));
    } on BillException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _delete(Meter m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${m.name}?'),
        content: const Text('Its readings and history will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await MeterStore.instance.remove(m.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MeterStore.instance,
      builder: (context, _) {
        final m = MeterStore.instance.byId(widget.meterId);
        if (m == null) return const Scaffold();
        final s = m.stats;
        final latest = m.latestReading;
        final accent = accentFor(MeterStore.instance.meters.indexOf(m));
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            backgroundColor: accent.tint.withValues(alpha: 0.06),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: titleStyle(20)),
                Text('${BillService.companyName(m.company)} · Ref ${m.prettyRef}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh from bill website',
                onPressed: _refreshing ? null : () => _refresh(m),
                icon: _refreshing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
              IconButton(tooltip: 'Delete meter', onPressed: () => _delete(m), icon: const Icon(Icons.delete_outline)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: accent.a,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ScanScreen(meterId: m.id))),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan reading'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              AppCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: _ReadingBox(
                        label: 'Last bill reading · ${fmtDate(m.cycleStart)}',
                        value: m.billReading == null ? '–' : fmtReading(m.billReading!),
                        source: 'From bill website',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReadingBox(
                        label: latest == null ? 'Current' : 'Current · ${fmtDate(latest.date)}',
                        value: latest == null ? '–' : fmtReading(latest.value),
                        source: latest == null ? 'Scan your meter' : 'From your photo',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(gradient: accent.gradient, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          latest == null
                              ? 'Units used'
                              : 'Units used (${latest.date.difference(m.cycleStart).inDays} days)',
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        Text(s == null ? '–' : '${s.units}', style: numStyle(26, color: Colors.white)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              if (s != null) _ForecastCard(stats: s),
              if (s != null) const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Last 12 months', style: titleStyle(16)),
                        const Text('From bill history', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    HistoryChart(history: m.history, forecast: s?.projected, accent: accent),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Your readings', style: titleStyle(16)),
                    ),
                    ..._log(m),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _log(Meter m) {
    final rows = <Widget>[];
    final list = m.cycleReadings.reversed.toList();
    for (var i = 0; i < list.length; i++) {
      final r = list[i];
      final prevValue = i + 1 < list.length ? list[i + 1].value : m.billReading;
      final prevDate = i + 1 < list.length ? list[i + 1].date : m.cycleStart;
      final diff = prevValue == null
          ? ''
          : '+${r.value - prevValue} in ${r.date.difference(prevDate).inDays} days';
      rows.add(_LogRow(fmtDate(r.date), r.source == 'photo' ? 'Photo scan' : 'Typed', fmtReading(r.value), diff));
    }
    if (m.billReading != null) {
      rows.add(_LogRow(fmtDate(m.cycleStart), 'Bill (website)', fmtReading(m.billReading!), 'Cycle start'));
    }
    if (rows.isEmpty) {
      rows.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No readings yet.', style: TextStyle(color: AppColors.muted)),
      ));
    }
    return rows;
  }
}

class _ReadingBox extends StatelessWidget {
  const _ReadingBox({required this.label, required this.value, required this.source});
  final String label, value, source;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(value, style: numStyle(24).copyWith(letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(source,
                style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final over = stats.status != SlabStatus.ok;
    final toSlab = 200 - stats.units;
    String message;
    if (toSlab <= 0) {
      message = 'You have already crossed 200 units this cycle.';
    } else if (over) {
      final safe = stats.daysRemaining > 0 ? toSlab / stats.daysRemaining : toSlab.toDouble();
      message =
          'At ${fmtAvg(stats.dailyAvg)} units/day for the next ${stats.daysRemaining} days you may cross the 200-unit slab. Keep usage under ${fmtAvg(safe)} units/day to stay below 200.';
    } else {
      message = 'At ${fmtAvg(stats.dailyAvg)} units/day you should stay below the 200-unit slab.';
    }
    final fg = over ? AppColors.warnText : AppColors.primaryDark;
    return AppCard(
      color: over ? AppColors.warnBg : const Color(0xFFEEF2FF),
      borderColor: over ? AppColors.warnBorder : const Color(0xFFC7D2FE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 20, color: over ? AppColors.orange : AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Forecast: ≈ ${stats.projected} units by ${fmtDate(stats.nextReading)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: over ? AppColors.orangeText : AppColors.primaryDark)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13, height: 1.5, color: fg)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: StatBlock('Daily avg', '${fmtAvg(stats.dailyAvg)} u', labelColor: fg)),
            Expanded(child: StatBlock('Days left', '${stats.daysRemaining}', labelColor: fg)),
            Expanded(child: StatBlock('Units to 200', toSlab > 0 ? '$toSlab' : '0', labelColor: fg)),
          ]),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow(this.date, this.source, this.value, this.diff);
  final String date, source, value, diff;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(source, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: numStyle(16)),
              if (diff.isNotEmpty) Text(diff, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ],
        ),
      );
}
