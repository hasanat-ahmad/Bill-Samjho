import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../domain/format.dart';
import 'home_cubit.dart';
import 'pick_connection_sheet.dart';

/// S2: meter cards and the main "scan new bill" action (max 2 taps to scan).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newBill(BuildContext context, {bool byReference = false}) async {
    final connectionId = await showPickConnectionSheet(
      context,
      actionIcon: byReference ? Icons.travel_explore_rounded : Icons.photo_camera_rounded,
    );
    if (connectionId == null || !context.mounted) return;
    context.push(byReference ? '/lookup/$connectionId' : '/scan/$connectionId');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.page,
        title: Row(children: [
          const AppLogo(size: 28),
          const SizedBox(width: Gap.sm + 2),
          Flexible(child: Text(s.t('app_name'), overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: s.t('glossary'),
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/glossary'),
          ),
          IconButton(
            tooltip: s.t('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: Column(children: [
        const DemoBanner(),
        Expanded(
          child: BlocBuilder<HomeCubit, List<ConnectionSummary>>(
            builder: (context, connections) => connections.isEmpty
                ? const _EmptyHome()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
                    itemCount: connections.length + 1,
                    separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : Gap.sm + 2),
                    itemBuilder: (context, i) =>
                        i == 0 ? SectionTitle(s.t('your_meters')) : _ConnectionCard(connections[i - 1]),
                  ),
          ),
        ),
      ]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PrimaryButton(
                label: s.t('scan_bill'),
                icon: Icons.photo_camera_outlined,
                onPressed: () => _newBill(context),
              ),
              const SizedBox(height: Gap.sm),
              SecondaryButton(
                label: s.t('lookup_entry'),
                icon: Icons.search_rounded,
                onPressed: () => _newBill(context, byReference: true),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.xl),
      children: [
        Text(s.t('empty_title'), style: theme.textTheme.headlineMedium),
        const SizedBox(height: Gap.xs),
        Text(s.t('empty_body'), style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: Gap.xl),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            StepRow(number: 1, text: s.t('step_photo')),
            const PanelDivider(indent: 56),
            StepRow(number: 2, text: s.t('step_check')),
            const PanelDivider(indent: 56),
            StepRow(number: 3, text: s.t('step_listen')),
          ]),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard(this.summary);

  final ConnectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final bill = summary.latestBill;
    final connection = summary.connection;
    final config = context.read<BillRepository>().tariffConfig;
    final subtitle = [
      ?connection.disco,
      if (bill != null) formatMonth(bill.data.billMonth, s),
    ].join(' · ');

    return AppCard(
      onTap: () => context.push('/history/${connection.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(connection.nickname, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (bill != null) VerdictPill(bill.verdict) else const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
        ]),
        if (bill == null) ...[
          const SizedBox(height: Gap.md),
          Text(s.t('no_bill_yet'), style: theme.textTheme.bodyMedium),
        ] else ...[
          const SizedBox(height: Gap.lg),
          Text(formatAmount(bill.data.totalDue, s), style: numberStyle(26, weight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: Gap.md),
          UnitMeter(units: bill.data.units, limit: config.protectedLimitUnits, nearLimit: config.nearLimitUnits),
          const SizedBox(height: Gap.sm),
          Text(
            s.t('units_of_limit', {
              'units': formatNumber(bill.data.units),
              'limit': formatNumber(config.protectedLimitUnits),
            }),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ]),
    );
  }
}
