import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../domain/appliances.dart';
import '../../domain/forecaster.dart';
import '../../domain/format.dart';

/// "What does it cost to run?": appliances the user plans to use more, the
/// units they add and roughly what the bill becomes, at this bill's own rates.
class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({super.key, required this.bill});

  final Bill bill;

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  final List<ApplianceUse> _uses = [];

  Future<void> _add() async {
    final picked = await showModalBottomSheet<Appliance>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PickSheet(s: context.read<AppStrings>()),
    );
    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _uses.add(ApplianceUse(picked, hoursPerDay: picked.hours)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.desk,
      appBar: AppBar(title: Text(s.t('appliances_title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, bottomPadding(context)),
        children: [
          Text(s.t('appliances_intro'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.lg),
          _Summary(bill: widget.bill, uses: _uses),
          SectionTitle(s.t('appliances_list')),
          for (final (i, use) in _uses.indexed) ...[
            _UseCard(
              use: use,
              onChanged: (u) => setState(() => _uses[i] = u),
              onRemove: () => setState(() => _uses.removeAt(i)),
            ),
            const SizedBox(height: Gap.sm),
          ],
          SecondaryButton(label: s.t('appliances_add'), icon: Icons.add_rounded, onPressed: _add),
          const SizedBox(height: Gap.xl),
          NoteRow(icon: Icons.info_outline_rounded, text: s.t('appliances_note')),
        ],
      ),
    );
  }
}

/// Units added, the bill before and after, and a warning past the limit.
class _Summary extends StatelessWidget {
  const _Summary({required this.bill, required this.uses});

  final Bill bill;
  final List<ApplianceUse> uses;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    if (uses.isEmpty) {
      return AppCard(child: Text(s.t('appliances_empty'), style: theme.textTheme.bodyLarge));
    }
    final repo = context.read<BillRepository>();
    final limit = repo.tariffConfig.protectedLimitUnits;
    final added = uses.fold<int>(0, (sum, u) => sum + u.monthlyUnits);
    final base = bill.data.units;
    final total = base + added;
    final forecaster = Forecaster(repo.tariffConfig);
    final past = repo.billsFor(bill.connectionId).where((b) => b.id != bill.id).toList();
    final before = forecaster.costAt(bill.data, past, base);
    final after = forecaster.costAt(bill.data, past, total);
    final crosses = base <= limit && total > limit;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.t('appliances_adds'), style: theme.textTheme.bodySmall),
        const SizedBox(height: Gap.xs),
        Text(s.t('appliances_units', {'units': formatNumber(added)}), style: numberStyle(28, letterSpacing: -0.8)),
        if (before != null && after != null) ...[
          const SizedBox(height: Gap.md),
          const Divider(),
          const SizedBox(height: Gap.md),
          Text(
            s.t('appliances_cost', {'old': formatNumber(before.round()), 'new': formatNumber(after.round())}),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            s.t('appliances_more', {'diff': formatNumber((after - before).round())}),
            style: theme.textTheme.titleMedium,
          ),
        ],
        if (crosses) ...[
          const SizedBox(height: Gap.md),
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(color: Tone.wrong.soft, borderRadius: BorderRadius.circular(Radii.sm)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Tone.wrong.icon, color: Tone.wrong.color, size: 18)),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  s.t('appliances_over', {'units': formatNumber(total), 'limit': formatNumber(limit)}),
                  style: theme.textTheme.bodyMedium?.copyWith(color: Tone.wrong.ink),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// One appliance: how many, hours a day, and the units it adds.
class _UseCard extends StatelessWidget {
  const _UseCard({required this.use, required this.onChanged, required this.onRemove});

  final ApplianceUse use;
  final ValueChanged<ApplianceUse> onChanged;
  final VoidCallback onRemove;

  /// Half-hour steps below 2 hours, whole hours above.
  static double _step(double h, int dir) => (dir > 0 ? h < 2 : h <= 2) ? 0.5 : 1;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final a = use.appliance;
    final h = use.hoursPerDay;
    String hours(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.xs, Gap.xs, Gap.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('appliance_${a.key}'), style: theme.textTheme.titleSmall),
              Text(s.t('appliances_watts', {'watts': formatNumber(a.watts)}), style: theme.textTheme.bodySmall),
            ]),
          ),
          Text(s.t('appliances_per_month', {'units': formatNumber(use.monthlyUnits)}), style: numberStyle(14, mono: true)),
          IconButton(
            tooltip: s.t('appliances_remove'),
            color: AppColors.inkSubtle,
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onRemove,
          ),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.md),
          child: Row(children: [
            Expanded(
              child: _Stepper(
                label: s.t('appliances_count'),
                value: '${use.count}',
                onMinus: use.count > 1 ? () => onChanged(use.copyWith(count: use.count - 1)) : null,
                onPlus: use.count < 10 ? () => onChanged(use.copyWith(count: use.count + 1)) : null,
                s: s,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: _Stepper(
                label: s.t('appliances_hours'),
                value: hours(h),
                onMinus: h > 0.5 ? () => onChanged(use.copyWith(hoursPerDay: h - _step(h, -1))) : null,
                onPlus: h < 24 ? () => onChanged(use.copyWith(hoursPerDay: h + _step(h, 1))) : null,
                s: s,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus, required this.s});

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final AppStrings s;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Row(children: [
            IconButton(tooltip: s.t('less'), icon: const Icon(Icons.remove_rounded, size: 20), onPressed: onMinus),
            Expanded(child: Text(value, textAlign: TextAlign.center, style: numberStyle(16, mono: true))),
            IconButton(tooltip: s.t('more'), icon: const Icon(Icons.add_rounded, size: 20), onPressed: onPlus),
          ]),
        ),
      ]);
}

/// The list of appliances to choose from.
class _PickSheet extends StatelessWidget {
  const _PickSheet({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
        child: Text(s.t('appliances_pick'), style: theme.textTheme.titleLarge),
      ),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: bottomPadding(context, Gap.lg)),
          children: [
            for (final (i, a) in Appliance.all.indexed) ...[
              if (i > 0) const PanelDivider(),
              PanelTile(
                title: s.t('appliance_${a.key}'),
                trailing: Text(s.t('appliances_watts', {'watts': formatNumber(a.watts)}), style: theme.textTheme.bodySmall),
                onTap: () => Navigator.pop(context, a),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}
