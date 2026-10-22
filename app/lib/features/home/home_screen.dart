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
          const AppLogo(size: 32),
          const SizedBox(width: Gap.md),
          Flexible(child: Text(s.t('app_name'), overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: s.t('glossary'),
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => context.push('/glossary'),
          ),
          IconButton(
            tooltip: s.t('settings'),
            icon: const Icon(Icons.settings_rounded),
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
                    separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : Gap.md),
                    itemBuilder: (context, i) =>
                        i == 0 ? SectionTitle(s.t('your_meters')) : _ConnectionCard(connections[i - 1]),
                  ),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PrimaryButton(
              label: s.t('scan_bill'),
              icon: Icons.photo_camera_rounded,
              onPressed: () => _newBill(context),
            ),
            const SizedBox(height: Gap.sm),
            SecondaryButton(
              label: s.t('lookup_entry'),
              icon: Icons.travel_explore_rounded,
              onPressed: () => _newBill(context, byReference: true),
            ),
          ]),
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
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xl),
      children: [
        const BillIllustration(height: 140),
        const SizedBox(height: Gap.xl),
        Text(s.t('empty_title'), style: theme.textTheme.headlineSmall),
        const SizedBox(height: Gap.xs),
        Text(s.t('empty_body'), style: theme.textTheme.bodyMedium),
        const SizedBox(height: Gap.lg),
        StepRow(number: 1, icon: Icons.photo_camera_rounded, text: s.t('step_photo')),
        StepRow(number: 2, icon: Icons.edit_note_rounded, text: s.t('step_check')),
        StepRow(number: 3, icon: Icons.record_voice_over_rounded, text: s.t('step_listen')),
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
          const IconBadge(Icons.home_rounded, color: AppColors.primary, background: AppColors.primarySoft),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(connection.nickname, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ]),
        const SizedBox(height: Gap.lg),
        if (bill == null)
          Text(s.t('no_bill_yet'), style: theme.textTheme.bodyMedium)
        else ...[
          Row(children: [
            Expanded(child: Text(formatAmount(bill.data.totalDue, s), style: numberStyle(22))),
            VerdictPill(bill.verdict),
          ]),
          const SizedBox(height: Gap.md),
          UnitMeter(units: bill.data.units, limit: config.protectedLimitUnits, nearLimit: config.nearLimitUnits, height: 8),
          const SizedBox(height: Gap.xs),
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
