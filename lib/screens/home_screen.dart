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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.headerWash),
        child: SafeArea(
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
                          Text('My Home', style: titleStyle(26)),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Add meter',
                      button: true,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.hero,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openAdd(context),
                            child: const SizedBox(
                                width: 48, height: 48, child: Icon(Icons.add, color: Colors.white)),
                          ),
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
                  for (var i = 0; i < meters.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MeterCard(meter: meters[i], accent: accentFor(i))),
                ],
              ],
            );
          },
        ),
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
            AccentIcon(accentFor(0), size: 64),
            const SizedBox(height: 12),
            Text('Add your first meter', style: titleStyle(18)),
            const SizedBox(height: 6),
            const Text(
              'Enter the 14-digit reference number from your bill. We will load the last reading from the bill website.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            GradientButton(onPressed: onAdd, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add), SizedBox(width: 6), Text('Add meter')])),
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9), Color(0xFFBE185D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6D28D9).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
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
                        style: const TextStyle(fontSize: 13, color: Color(0xFFE0E7FF))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(anyStats ? '$total' : '–', style: numStyle(44, color: Colors.white)),
                        const SizedBox(width: 6),
                        const Text('units', style: TextStyle(fontSize: 15, color: Color(0xFFE0E7FF))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text('$daysLeft', style: numStyle(22, color: AppColors.highlight)),
                  const Text('days left', style: TextStyle(fontSize: 11, color: Color(0xFFE0E7FF))),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatBlock('Next reading', fmtDate(next), labelColor: const Color(0xFFC7D2FE), valueColor: Colors.white)),
            Expanded(
                child: StatBlock('Daily avg', anyStats ? '${fmtAvg(avg)} u/day' : '–',
                    labelColor: const Color(0xFFC7D2FE), valueColor: Colors.white)),
            Expanded(
                child: StatBlock('Expected total', anyStats ? '≈ $projected u' : '–',
                    labelColor: const Color(0xFFC7D2FE), valueColor: AppColors.highlight)),
          ]),
        ],
      ),
    );
  }
}

class _MeterCard extends StatelessWidget {
  const _MeterCard({required this.meter, required this.accent});
  final Meter meter;
  final MeterAccent accent;

  @override
  Widget build(BuildContext context) {
    final s = meter.stats;
    final style = statusStyle(s?.status ?? SlabStatus.unknown);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: accent.a.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => MeterDetailScreen(meterId: meter.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Container(height: 6, decoration: BoxDecoration(gradient: accent.gradient)),
          Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                AccentIcon(accent),
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
                        Text(s == null ? '–' : '${s.units}', style: numStyle(32, color: accent.a)),
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
                    backgroundColor: accent.tint,
                    foregroundColor: accent.a,
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
          ],
        ),
      ),
      ),
      ),
    );
  }
}
