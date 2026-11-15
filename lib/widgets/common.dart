import 'package:flutter/material.dart';

import '../models/meter.dart';
import '../theme.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';

String fmtReading(int v) => v.toString().padLeft(5, '0');

String fmtAvg(double v) => v.toStringAsFixed(1);

class StatusStyle {
  final String label;
  final Color bg, fg, bar, proj;
  const StatusStyle(this.label, this.bg, this.fg, this.bar, this.proj);
}

StatusStyle statusStyle(SlabStatus s) {
  switch (s) {
    case SlabStatus.over:
      return const StatusStyle('Over 200', AppColors.orangeTint, AppColors.orangeText,
          AppColors.orange, Color(0xFFEA580C));
    case SlabStatus.near:
      return const StatusStyle('Near 200', AppColors.amberTint, AppColors.amberText,
          AppColors.amberDark, AppColors.amber);
    case SlabStatus.ok:
      return const StatusStyle('On track', AppColors.primaryTint, AppColors.primaryDark,
          AppColors.primary, AppColors.primary);
    case SlabStatus.unknown:
      return const StatusStyle('Scan needed', Color(0xFFF1F5F9), AppColors.muted,
          AppColors.muted, AppColors.muted);
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: child,
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.style, {super.key});
  final StatusStyle style;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(99)),
        child: Text(style.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.fg)),
      );
}

/// Progress toward the 200-unit slab: dark = used, light = forecast.
class SlabBar extends StatelessWidget {
  const SlabBar({super.key, this.now, this.projected, required this.style});
  final int? now;
  final int? projected;
  final StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, box) {
          double w(int? v) => v == null ? 0 : (v / 200).clamp(0.0, 1.0) * box.maxWidth;
          return Container(
            height: 8,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)),
            child: Stack(children: [
              Container(
                width: w(projected),
                decoration: BoxDecoration(
                    color: style.proj.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(99)),
              ),
              Container(
                width: w(now),
                decoration: BoxDecoration(color: style.bar, borderRadius: BorderRadius.circular(99)),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            Text('200-unit slab', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

class StatBlock extends StatelessWidget {
  const StatBlock(this.label, this.value,
      {super.key, this.labelColor = AppColors.muted, this.valueColor = AppColors.ink, this.valueSize = 15});
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      );
}

class WarningBox extends StatelessWidget {
  const WarningBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warnBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warnBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.warnText))),
          ],
        ),
      );
}

/// 12-month usage bars with a dashed-looking 200 line; the last bar can be the forecast.
class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.history, this.forecast});
  final List<MonthUsage> history;
  final int? forecast;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int units, bool isForecast})>[
      for (final h in history) (label: h.label, units: h.units, isForecast: false),
      if (forecast != null) (label: 'NOW', units: forecast!, isForecast: true),
    ];
    final shown = items.length > 13 ? items.sublist(items.length - 13) : items;
    if (shown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No history yet. Refresh from the bill website.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );
    }
    const h = 150.0;
    final maxV = shown.fold<int>(220, (m, e) => e.units > m ? e.units : m).toDouble();
    final slabY = 200 / maxV * h;

    return Column(
      children: [
        SizedBox(
          height: h,
          child: Stack(children: [
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final e in shown)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: e.units / maxV * h,
                          decoration: BoxDecoration(
                            color: e.isForecast ? AppColors.amber : AppColors.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: slabY, child: Container(height: 1, color: AppColors.orange)),
            Positioned(
              right: 0,
              bottom: slabY + 2,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: const Text('200',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.orangeText)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 6),
        Row(children: [
          for (final e in shown)
            Expanded(
              child: Text(
                e.label.length > 3 ? e.label.substring(0, 3) : e.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          _Legend(AppColors.primary, 'Billed units'),
          SizedBox(width: 14),
          _Legend(AppColors.amber, 'This month (forecast)'),
        ]),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]);
}
