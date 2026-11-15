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

/// Main call-to-action button with the brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = AppColors.hero,
    this.height = 52,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: radius,
            boxShadow: onPressed == null
                ? null
                : [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: SizedBox(
                height: height,
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded square with a gradient and a white bolt icon.
class AccentIcon extends StatelessWidget {
  const AccentIcon(this.accent, {super.key, this.size = 44, this.icon = Icons.bolt_rounded});
  final MeterAccent accent;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: accent.gradient, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      );
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
  const HistoryChart({super.key, required this.history, this.forecast, this.accent});
  final List<MonthUsage> history;
  final int? forecast;
  final MeterAccent? accent;

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
    final barA = accent?.a ?? AppColors.primary;
    final barB = accent?.b ?? const Color(0xFF7C3AED);
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
                            gradient: e.isForecast
                                ? const LinearGradient(
                                    colors: [AppColors.amber, AppColors.highlight],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter)
                                : LinearGradient(
                                    colors: [barA, barB],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter),
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
        Row(children: [
          _Legend(barA, 'Billed units'),
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
