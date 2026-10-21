import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/finding.dart';
import '../../data/models/urdu_strings.dart';
import '../../domain/explanation_builder.dart';
import '../../domain/urdu_format.dart';
import '../../services/tts_service.dart';
import '../settings/settings_cubit.dart';
import 'complaint_sheet.dart';
import 'result_cubit.dart';

/// S6: verdict, total, voice explanation, 200-unit meter, findings (FR-09..11).
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.autoPlay});

  /// True right after a scan: the explanation plays once (UC-1 step 6).
  final bool autoPlay;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final TtsService _tts;
  bool _showTtsTip = false;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsService>();
    final settings = context.read<SettingsCubit>();
    if (!_tts.urduAvailable && !settings.ttsTipShown) {
      _showTtsTip = true;
      settings.markTtsTipShown();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bill = context.read<ResultCubit>().state.bill;
      if (widget.autoPlay && bill != null && _tts.urduAvailable) {
        _tts.speak('all', _explanation(bill));
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String _explanation(Bill bill) => context.read<ExplanationBuilder>().build(bill.verdict, bill.findings);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultCubit, ResultState>(
      builder: (context, state) {
        final bill = state.bill;
        if (bill == null) {
          return Scaffold(
            appBar: AppBar(),
            body: state.loaded ? const MessageView(icon: Icons.search_off, message: Labels.noBillYet) : null,
          );
        }
        final strings = context.read<UrduStrings>();
        final title = [
          if (state.connection != null) state.connection!.nickname,
          formatMonth(bill.data.billMonth, strings),
        ].join(' · ');

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_showTtsTip) _TtsTip(onClose: () => setState(() => _showTtsTip = false)),
              _VerdictBanner(bill.verdict),
              const SizedBox(height: 16),
              _Totals(bill),
              const SizedBox(height: 16),
              SpeakButton(id: 'all', text: _explanation(bill), label: Labels.listenAll),
              const SizedBox(height: 16),
              _MeterCard(bill.data.units),
              const SizedBox(height: 8),
              for (final f in bill.findings) _FindingCard(f),
              if (bill.verdict != Verdict.normal) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                    icon: const Icon(Icons.campaign, size: 32),
                    label: const Text(Labels.complain, style: TextStyle(fontSize: 22)),
                    onPressed: () => showComplaintSheet(
                      context,
                      context.read<ExplanationBuilder>().complaint(bill, referenceNo: state.connection?.referenceNo),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner(this.verdict);

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final s = VerdictStyle.of(verdict);
    final sentence = context.read<ExplanationBuilder>().verdictSentence(verdict);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(s.icon, color: s.onColor, size: 64),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.label, style: TextStyle(color: s.onColor, fontSize: 30, fontWeight: FontWeight.bold)),
            Text(sentence, style: TextStyle(color: s.onColor, fontSize: 18)),
          ]),
        ),
      ]),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals(this.bill);

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.read<UrduStrings>();
    return Column(children: [
      Text(Labels.totalAmount, style: theme.textTheme.titleMedium),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(formatNumber(bill.data.totalDue), style: numberStyle.copyWith(fontSize: 48)),
          Text(Labels.rupees, style: theme.textTheme.titleLarge),
        ],
      ),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(formatNumber(bill.data.units), style: numberStyle.copyWith(fontSize: 24)),
          Text(Labels.units, style: theme.textTheme.titleMedium),
        ],
      ),
      if (bill.data.dueDate != null)
        Text(
          '${Labels.dueDate}: ${formatDate(bill.data.dueDate!, strings)}',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
    ]);
  }
}

class _MeterCard extends StatelessWidget {
  const _MeterCard(this.units);

  final int units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = context.read<BillRepository>().tariffConfig;
    final text = context.read<ExplanationBuilder>().meterText(units, config.protectedLimitUnits);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.speed, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(Labels.meterTitle, style: theme.textTheme.titleMedium)),
            PlayButton(id: 'meter', text: text),
          ]),
          const SizedBox(height: 8),
          UnitMeter(units: units, limit: config.protectedLimitUnits, nearLimit: config.nearLimitUnits),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodyLarge),
        ]),
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard(this.finding);

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = finding.isSummary
        ? (AppColors.primary, Icons.receipt_long)
        : VerdictStyle.ofSeverity(finding.severity);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(finding.urduText, style: Theme.of(context).textTheme.bodyLarge)),
          PlayButton(id: finding.ruleId, text: finding.urduText),
        ]),
      ),
    );
  }
}

/// One-time tip when the phone has no Urdu voice (SDA §10.4).
class _TtsTip extends StatelessWidget {
  const _TtsTip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.record_voice_over, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text(Labels.ttsTip, style: Theme.of(context).textTheme.bodyLarge)),
            IconButton(icon: const Icon(Icons.close), onPressed: onClose),
          ]),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text(Labels.install),
            onPressed: () => launchUrl(
              Uri.parse(AppConstants.googleTtsPlayStoreUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ]),
      ),
    );
  }
}
