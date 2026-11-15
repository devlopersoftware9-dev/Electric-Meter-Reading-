import 'package:flutter/material.dart';

import '../models/meter.dart';
import '../services/bill_service.dart';
import '../services/meter_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_meter_screen.dart';
import 'meter_detail_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openAdd(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMeterScreen()));

  @override
  Widget build(BuildContext context) {
    final store = MeterStore.instance;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final meters = store.meters;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assalam-o-Alaikum',
                              style: TextStyle(fontSize: 13, color: AppColors.muted)),
                          Text('My Home', style: titleStyle(24)),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Add meter',
                      button: true,
                      child: Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openAdd(context),
                          child: const SizedBox(
                              width: 48, height: 48, child: Icon(Icons.add, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (meters.isEmpty)
                  _EmptyState(onAdd: () => _openAdd(context))
                else ...[
                  _SummaryCard(meters: meters),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Meters', style: titleStyle(18)),
                      Text('${meters.length} meter${meters.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final m in meters)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: _MeterCard(meter: m)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.bolt_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Add your first meter', style: titleStyle(18)),
            const SizedBox(height: 6),
            const Text(
              'Enter the 14-digit reference number from your bill. We will load the last reading from the bill website.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add meter')),
          ],
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.meters});
  final List<Meter> meters;

  @override
  Widget build(BuildContext context) {
    var total = 0, projected = 0;
    var avg = 0.0;
    var anyStats = false;
    for (final m in meters) {
      final s = m.stats;
      if (s != null) {
        anyStats = true;
        total += s.units;
        projected += s.projected;
        avg += s.dailyAvg;
      }
    }
    final next = meters.map((m) => m.nextReadingDate()).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysLeft = next.difference(dateOnly(DateTime.now())).inDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total this cycle · ${meters.length} meter${meters.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 13, color: AppColors.mutedOnDark)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(anyStats ? '$total' : '–', style: numStyle(44, color: Colors.white)),
                        const SizedBox(width: 6),
                        const Text('units', style: TextStyle(fontSize: 15, color: AppColors.mutedOnDark)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.navy2, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text('$daysLeft', style: numStyle(22, color: AppColors.highlight)),
                  const Text('days left', style: TextStyle(fontSize: 11, color: AppColors.mutedOnDark)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.navyLine),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatBlock('Next reading', fmtDate(next), labelColor: const Color(0xFF94A3B8), valueColor: Colors.white)),
            Expanded(
                child: StatBlock('Daily avg', anyStats ? '${fmtAvg(avg)} u/day' : '–',
                    labelColor: const Color(0xFF94A3B8), valueColor: Colors.white)),
            Expanded(
                child: StatBlock('Expected total', anyStats ? '≈ $projected u' : '–',
                    labelColor: const Color(0xFF94A3B8), valueColor: AppColors.highlight)),
          ]),
        ],
      ),
    );
  }
}

class _MeterCard extends StatelessWidget {
  const _MeterCard({required this.meter});
  final Meter meter;

  @override
  Widget build(BuildContext context) {
    final s = meter.stats;
    final style = statusStyle(s?.status ?? SlabStatus.unknown);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => MeterDetailScreen(meterId: meter.id))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meter.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('${BillService.companyName(meter.company)} · Ref ${meter.maskedRef}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                StatusChip(style),
              ]),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(s == null ? '–' : '${s.units}', style: numStyle(30)),
                        const SizedBox(width: 4),
                        const Text('units so far', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(s == null ? 'Scan to start' : '${fmtAvg(s.dailyAvg)} u/day',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      if (s != null)
                        Text('≈ ${s.projected} by ${fmtDate(s.nextReading)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SlabBar(now: s?.units, projected: s?.projected, style: style),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ScanScreen(meterId: meter.id))),
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Scan reading'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
