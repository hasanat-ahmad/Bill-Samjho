import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/urdu_strings.dart';
import '../../domain/urdu_format.dart';
import 'home_cubit.dart';
import 'pick_connection_sheet.dart';

/// S2: connection cards and the big "new bill" button.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newBill(BuildContext context) async {
    final connectionId = await showPickConnectionSheet(context);
    if (connectionId != null && context.mounted) context.push('/scan/$connectionId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Labels.appName),
        leading: IconButton(
          tooltip: Labels.glossary,
          icon: const Icon(Icons.menu_book),
          onPressed: () => context.push('/glossary'),
        ),
        actions: [
          IconButton(
            tooltip: Labels.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: BlocBuilder<HomeCubit, List<ConnectionSummary>>(
        builder: (context, connections) {
          if (connections.isEmpty) {
            return const MessageView(
              icon: Icons.document_scanner,
              message: Labels.scanFirstBill,
              detail: Labels.scanFirstBillHint,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [for (final c in connections) _ConnectionCard(c)],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newBill(context),
        icon: const Icon(Icons.camera_alt, size: 32),
        label: const Text(Labels.newBill),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard(this.summary);

  final ConnectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = summary.latestBill;
    final config = context.read<BillRepository>().tariffConfig;
    final strings = context.read<UrduStrings>();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/history/${summary.connection.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.home, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(summary.connection.nickname, style: theme.textTheme.titleLarge)),
              if (bill != null) VerdictBadge(bill.verdict),
            ]),
            const SizedBox(height: 8),
            if (bill == null)
              Text(Labels.noBillYet, style: theme.textTheme.bodyLarge)
            else ...[
              Row(children: [
                Expanded(child: Text(formatMonth(bill.data.billMonth, strings), style: theme.textTheme.bodyLarge)),
                Text(formatNumber(bill.data.units), style: numberStyle.copyWith(fontSize: 22)),
                const SizedBox(width: 6),
                Text(Labels.units, style: theme.textTheme.bodyLarge),
              ]),
              const SizedBox(height: 8),
              UnitMeter(
                units: bill.data.units,
                limit: config.protectedLimitUnits,
                nearLimit: config.nearLimitUnits,
                height: 12,
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
