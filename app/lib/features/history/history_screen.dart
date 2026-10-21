import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/urdu_strings.dart';
import '../../domain/urdu_format.dart';
import 'history_cubit.dart';

/// S8: units chart with the 200 line, and the list of saved bills.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _deleteConnection(BuildContext context) async {
    if (!await confirmDialog(context, Labels.deleteConnectionQ)) return;
    if (!context.mounted) return;
    await context.read<HistoryCubit>().deleteConnection();
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(state.connection?.nickname ?? Labels.history),
            actions: [
              IconButton(
                tooltip: Labels.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteConnection(context),
              ),
            ],
          ),
          body: state.bills.isEmpty
              ? const MessageView(icon: Icons.receipt_long, message: Labels.noBillYet)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (state.chart.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                          child: SizedBox(height: 240, child: _UnitsChart(state.chart)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(Labels.history, style: theme.textTheme.titleLarge),
                    Text(Labels.longPressHint, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                    const SizedBox(height: 8),
                    for (final b in state.bills) _BillTile(b),
                  ],
                ),
        );
      },
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile(this.bill);

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.read<UrduStrings>();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/result/${bill.id}'),
        onLongPress: () async {
          final cubit = context.read<HistoryCubit>();
          if (await confirmDialog(context, Labels.deleteBillQ)) await cubit.deleteBill(bill.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatMonth(bill.data.billMonth, strings), style: theme.textTheme.titleMedium),
                Text(
                  '${formatNumber(bill.data.units)} ${Labels.units}  ·  ${formatNumber(bill.data.totalDue)} ${Labels.rupees}',
                  style: theme.textTheme.bodyLarge,
                ),
              ]),
            ),
            VerdictBadge(bill.verdict),
          ]),
        ),
      ),
    );
  }
}

class _UnitsChart extends StatelessWidget {
  const _UnitsChart(this.data);

  final List<(String, int)> data;

  @override
  Widget build(BuildContext context) {
    final strings = context.read<UrduStrings>();
    final limit = context.read<BillRepository>().tariffConfig.protectedLimitUnits;
    final maxUnits = data.map((e) => e.$2).fold(limit, math.max);
    // Label every bar when few, otherwise every other one so names fit.
    final labelEvery = data.length > 6 ? 2 : 1;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: BarChart(
        BarChartData(
          maxY: maxUnits * 1.15,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (final (i, (_, units)) in data.indexed)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: units.toDouble(),
                  width: data.length > 8 ? 14 : 22,
                  color: units > limit ? AppColors.red : AppColors.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: limit.toDouble(),
              color: AppColors.red,
              strokeWidth: 2,
              dashArray: [8, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: numberStyle.copyWith(color: AppColors.red, fontSize: 16),
                labelResolver: (_) => '$limit',
              ),
            ),
          ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(meta.formattedValue, style: const TextStyle(fontFamily: 'Roboto', fontSize: 13)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length || (data.length - 1 - i) % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  final month = monthIndex(data[i].$1);
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(month == null ? '' : strings.months[month % 12], style: const TextStyle(fontSize: 14)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.round()}',
                const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
