import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/finding.dart';
import '../../domain/explanation_builder.dart';
import '../../domain/format.dart';
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
    if (!_tts.voiceAvailable && !settings.ttsTipShown) {
      _showTtsTip = true;
      settings.markTtsTipShown();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bill = context.read<ResultCubit>().state.bill;
      if (widget.autoPlay && bill != null && _tts.voiceAvailable) {
        _tts.speak('all', ExplanationBuilder(context.read<AppStrings>()).build(bill.verdict, bill.findings));
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return BlocBuilder<ResultCubit, ResultState>(
      builder: (context, state) {
        final bill = state.bill;
        if (bill == null) {
          return Scaffold(
            appBar: AppBar(),
            body: state.loaded ? MessageView(icon: Icons.search_off_rounded, title: s.t('not_found')) : null,
          );
        }
        final builder = ExplanationBuilder(s);
        final findings = ExplanationBuilder.ordered(bill.findings);

        return Scaffold(
          appBar: AppBar(title: Text(state.connection?.nickname ?? s.t('app_name'))),
          body: ListView(
            padding: EdgeInsets.only(bottom: bottomPadding(context)),
            children: [
              const DemoBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_showTtsTip) ...[
                    _TtsTip(onClose: () => setState(() => _showTtsTip = false)),
                    const SizedBox(height: Gap.lg),
                  ],
                  _VerdictHero(bill: bill),
                  const SizedBox(height: Gap.lg),
                  _AmountCard(bill: bill),
                  const SizedBox(height: Gap.lg),
                  ListenButton(id: 'all', text: builder.build(bill.verdict, bill.findings), label: s.t('listen_all')),
                  _MeterSection(units: bill.data.units),
                  SectionTitle(s.t('findings_title')),
                  for (final f in findings) ...[
                    _FindingCard(finding: f, text: builder.findingText(f)),
                    const SizedBox(height: Gap.md),
                  ],
                  if (bill.verdict != Verdict.normal) ...[
                    const SizedBox(height: Gap.sm),
                    _ComplaintCard(
                      onPressed: () => showComplaintSheet(
                        context,
                        builder.complaint(bill, referenceNo: state.connection?.referenceNo),
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.xl),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.inkMuted, size: 18),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: Text(s.t('advice_only'), style: Theme.of(context).textTheme.bodySmall)),
                  ]),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VerdictHero extends StatelessWidget {
  const _VerdictHero({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final tone = Tone.ofVerdict(bill.verdict);
    final builder = ExplanationBuilder(s);
    return Semantics(
      container: true,
      label: '${builder.verdictLabel(bill.verdict)}. ${builder.verdictSentence(bill.verdict)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: tone.soft,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: tone.color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: tone.color, shape: BoxShape.circle),
            child: Icon(tone.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(builder.verdictLabel(bill.verdict), style: theme.textTheme.headlineSmall?.copyWith(color: tone.ink)),
              const SizedBox(height: Gap.xs),
              Text(builder.verdictSentence(bill.verdict), style: theme.textTheme.bodyLarge?.copyWith(color: tone.ink)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t(bill.data.isCredit ? 'credit_due' : 'amount_due'), style: theme.textTheme.bodySmall),
        const SizedBox(height: Gap.xs),
        Text(
          formatAmount(bill.data.totalDue, s),
          style: numberStyle(30, weight: FontWeight.w800, color: bill.data.isCredit ? AppColors.greenInk : AppColors.ink),
        ),
        const SizedBox(height: Gap.md),
        Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
          _Chip(icon: Icons.calendar_month_rounded, text: formatMonth(bill.data.billMonth, s)),
          _Chip(icon: Icons.bolt_rounded, text: '${formatNumber(bill.data.units)} ${s.t('units')}'),
          if (bill.data.dueDate != null)
            _Chip(icon: Icons.event_rounded, text: s.t('due_by', {'date': formatDate(bill.data.dueDate!, s)})),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs + 2),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: Gap.xs),
          Flexible(child: Text(text, style: Theme.of(context).textTheme.labelMedium)),
        ]),
      );
}

class _MeterSection extends StatelessWidget {
  const _MeterSection({required this.units});

  final int units;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final config = context.read<BillRepository>().tariffConfig;
    final limit = config.protectedLimitUnits;
    final text = ExplanationBuilder(s).meterText(units, limit);
    final meter = UnitMeter(units: units, limit: limit, nearLimit: config.nearLimitUnits, height: 12, showScale: true);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(s.t('meter_title', {'limit': formatNumber(limit)})),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(meter.tone.icon, color: meter.tone.color, size: 22),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                s.t('units_of_limit', {'units': formatNumber(units), 'limit': formatNumber(limit)}),
                style: theme.textTheme.titleMedium,
              ),
            ),
            PlayButton(id: 'meter', text: text, tone: meter.tone),
          ]),
          const SizedBox(height: Gap.md),
          meter,
          const SizedBox(height: Gap.md),
          Text(text, style: theme.textTheme.bodyMedium),
        ]),
      ),
    ]);
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding, required this.text});

  final Finding finding;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = finding.isSummary ? Tone.info : Tone.ofSeverity(finding.severity);
    final icon = finding.isSummary ? Icons.receipt_long_rounded : tone.icon;
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.lg, Gap.sm, Gap.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, color: tone.color, background: tone.soft, size: 36),
        const SizedBox(width: Gap.md),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        PlayButton(id: finding.ruleId, text: text, tone: tone),
      ]),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return AppCard(
      color: AppColors.redSoft,
      borderColor: AppColors.red.withValues(alpha: 0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IconBadge(Icons.campaign_rounded, color: AppColors.red, background: Colors.white),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(s.t('complain_title'), style: theme.textTheme.titleMedium?.copyWith(color: AppColors.redInk))),
        ]),
        const SizedBox(height: Gap.sm),
        Text(s.t('complain_body'), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.redInk)),
        const SizedBox(height: Gap.lg),
        PrimaryButton(label: s.t('complain'), icon: Icons.edit_note_rounded, color: AppColors.red, onPressed: onPressed),
      ]),
    );
  }
}

/// One-time tip when the phone has no voice for the language (SDA §10.4).
class _TtsTip extends StatelessWidget {
  const _TtsTip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AppCard(
      color: AppColors.primarySoft,
      borderColor: AppColors.primarySoft,
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.sm, Gap.xs, Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.record_voice_over_rounded, color: AppColors.primaryDark, size: 22),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(s.t('tts_tip'), style: Theme.of(context).textTheme.bodyLarge)),
          IconButton(tooltip: s.t('cancel'), icon: const Icon(Icons.close_rounded), onPressed: onClose),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.md),
          child: FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: Text(s.t('install')),
            onPressed: () => launchUrl(Uri.parse(AppConstants.googleTtsPlayStoreUrl), mode: LaunchMode.externalApplication),
          ),
        ),
      ]),
    );
  }
}
