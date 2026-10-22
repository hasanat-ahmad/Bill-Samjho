import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../domain/format.dart';
import 'history_cubit.dart';

/// S8: units chart with the 200 line, and the list of saved bills.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _deleteConnection(BuildContext context) async {
    final s = context.read<AppStrings>();
    if (!await confirmDialog(context, s.t('delete_meter_q'), confirmLabel: s.t('delete'))) return;
    if (!context.mounted) return;
    await context.read<HistoryCubit>().deleteConnection();
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        final connection = state.connection;
        final details = [?connection?.disco, ?connection?.referenceNo].join(' · ');
        return Scaffold(
          appBar: AppBar(
            title: Text(connection?.nickname ?? s.t('history_title')),
            actions: [
              PopupMenuButton<void>(
                tooltip: s.t('more_options'),
                icon: const Icon(Icons.more_vert_rounded),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => _deleteConnection(context),
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                      const SizedBox(width: Gap.md),
                      Text(s.t('delete_meter'), style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          body: state.bills.isEmpty
              ? MessageView(icon: Icons.receipt_long_rounded, title: s.t('no_bill_yet'))
              : ListView(
                  padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, bottomPadding(context)),
                  children: [
                    if (details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.sm),
                        child: Row(children: [
                          const Icon(Icons.electric_meter_rounded, color: AppColors.inkMuted, size: 22),
                          const SizedBox(width: Gap.sm),
                          Expanded(child: Text(details, style: theme.textTheme.bodySmall, textDirection: TextDirection.ltr)),
                        ]),
                      ),
                    if (state.chart.isNotEmpty) ...[
                      SectionTitle(s.t('chart_title')),
                      AppCard(
                        padding: const EdgeInsetsDirectional.fromSTEB(Gap.sm, Gap.lg, Gap.lg, Gap.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SizedBox(height: 220, child: _UnitsChart(state.chart)),
                          const SizedBox(height: Gap.sm),
                          _Legend(limit: context.read<BillRepository>().tariffConfig.protectedLimitUnits),
                        ]),
                      ),
                    ],
                    SectionTitle(s.t('history_title')),
                    for (final b in state.bills) ...[
                      _BillTile(b),
                      const SizedBox(height: Gap.md),
                    ],
                    Text(s.t('long_press_hint'), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                  ],
                ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.limit});

  final int limit;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Gap.lg),
      child: Wrap(spacing: Gap.lg, runSpacing: Gap.xs, children: [
        _LegendItem(color: AppColors.primary, label: s.t('units_legend')),
        _LegendItem(color: AppColors.red, label: s.t('limit_legend', {'limit': formatNumber(limit)}), dashed: true),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        dashed
            ? Row(children: [
                for (var i = 0; i < 3; i++)
                  Container(width: 6, height: 3, margin: const EdgeInsets.only(right: 2), color: color),
              ])
            : Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: Gap.sm),
        Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      ]);
}

class _BillTile extends StatelessWidget {
  const _BillTile(this.bill);

  final Bill bill;

  Future<void> _delete(BuildContext context) async {
    final s = context.read<AppStrings>();
    final cubit = context.read<HistoryCubit>();
    if (await confirmDialog(context, s.t('delete_bill_q'), confirmLabel: s.t('delete'))) {
      await cubit.deleteBill(bill.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.md, Gap.xs, Gap.md),
      onTap: () => context.push('/result/${bill.id}'),
      onLongPress: () => _delete(context),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatMonth(bill.data.billMonth, s), style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              '${formatNumber(bill.data.units)} ${s.t('units')}  ·  ${formatAmount(bill.data.totalDue, s)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            VerdictPill(bill.verdict),
          ]),
        ),
        PopupMenuButton<void>(
          tooltip: s.t('more_options'),
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkMuted),
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: () => _delete(context),
              child: Row(children: [
                const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                const SizedBox(width: Gap.md),
                Text(s.t('delete'), style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.red)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}

class _UnitsChart extends StatelessWidget {
  const _UnitsChart(this.data);

  final List<(String, int)> data;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final limit = context.read<BillRepository>().tariffConfig.protectedLimitUnits;
    final maxUnits = data.map((e) => e.$2).fold(limit, math.max);
    final interval = math.max(50, (maxUnits / 4 / 50).ceil() * 50).toDouble();
    // Label every bar when few, otherwise every other one so names fit.
    final labelEvery = data.length > 6 ? 2 : 1;
    final axisStyle = Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 13, height: 1.2);

    // Time runs left to right in both languages, like the printed bill table.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: BarChart(
        BarChartData(
          maxY: (maxUnits * 1.2).ceilToDouble(),
          minY: 0,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (final (i, (_, units)) in data.indexed)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: units.toDouble(),
                  width: data.length > 8 ? 14 : 22,
                  color: units > limit ? AppColors.red : AppColors.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ]),
          ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: limit.toDouble(), color: AppColors.red, strokeWidth: 2, dashArray: [8, 5]),
          ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                // fl_chart always labels the max; skip it unless it is on
                // the grid, so it cannot overlap the label below it.
                getTitlesWidget: (value, meta) => value % interval != 0
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(meta.formattedValue, style: numberStyle(13, color: AppColors.inkMuted, weight: FontWeight.w500)),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: s.language.isRtl ? 44 : 30,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length || (data.length - 1 - i) % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  final name = formatMonthName(data[i].$1, s);
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(s.language.isRtl ? name : name.substring(0, math.min(3, name.length)), style: axisStyle),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem('${rod.toY.round()}', numberStyle(15, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
