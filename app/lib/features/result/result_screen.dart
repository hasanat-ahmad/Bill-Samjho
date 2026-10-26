import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_chat.dart';
import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/extracted_bill.dart';
import '../../data/models/finding.dart';
import '../../domain/explanation_builder.dart';
import '../../domain/forecaster.dart';
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

  /// Next-bill estimate input: the bill (with the reading the user typed if
  /// the bill had none) and today's meter reading. Null until asked.
  MeterInput? _meter;

  Future<void> _estimate(Bill bill) async {
    final result = await showMeterSheet(
      context,
      bill: _meter?.bill ?? bill.data,
      forecaster: Forecaster(context.read<BillRepository>().tariffConfig),
    );
    if (result != null && mounted) setState(() => _meter = result);
  }

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
            backgroundColor: AppColors.desk,
            appBar: AppBar(),
            body: state.loaded ? MessageView(icon: Icons.search_off_rounded, title: s.t('not_found')) : null,
          );
        }
        final builder = ExplanationBuilder(s);
        final repo = context.read<BillRepository>();
        // Estimate only from a meter's latest bill.
        final isLatest = repo.latestBill(bill.connectionId)?.id == bill.id;
        final canChat = context.read<ChatAvailability>().enabled;
        final canComplain = bill.verdict != Verdict.normal;
        final meter = _meter;
        final forecast = meter == null || !isLatest
            ? null
            : Forecaster(repo.tariffConfig).forecast(
                meter.bill,
                repo.billsFor(bill.connectionId).where((b) => b.id != bill.id).toList(),
                meterReading: meter.reading,
              );

        return Scaffold(
          backgroundColor: AppColors.desk,
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
                    const SizedBox(height: Gap.md),
                  ],
                  _Statement(bill: bill),
                  const SizedBox(height: Gap.lg),
                  _ListenAll(text: builder.build(bill.verdict, bill.findings)),
                  SectionTitle(s.t('meter_title', {'limit': formatNumber(repo.tariffConfig.protectedLimitUnits)})),
                  _LimitCard(units: bill.data.units),
                  SectionTitle(s.t('findings_title')),
                  _Findings(findings: ExplanationBuilder.ordered(bill.findings), builder: builder),
                  if (forecast != null) ...[
                    SectionTitle(s.t('forecast_title')),
                    _ForecastResult(forecast: forecast, onChange: () => _estimate(bill)),
                  ],
                  SectionTitle(s.t('next_steps')),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (i, tile) in [
                        if (isLatest && forecast == null)
                          PanelTile(
                            icon: Icons.speed_outlined,
                            iconColor: AppColors.primary,
                            title: s.t('forecast_cta'),
                            subtitle: s.t('forecast_intro'),
                            onTap: () => _estimate(bill),
                          ),
                        PanelTile(
                          icon: Icons.electrical_services_outlined,
                          iconColor: AppColors.primary,
                          title: s.t('appliances_entry_title'),
                          subtitle: s.t('appliances_entry_body'),
                          onTap: () => context.push('/appliances/${bill.id}'),
                        ),
                        if (canChat)
                          PanelTile(
                            icon: Icons.forum_outlined,
                            iconColor: AppColors.primary,
                            title: s.t('chat_entry_title'),
                            subtitle: s.t('chat_entry_body'),
                            onTap: () => context.push('/chat/${bill.id}'),
                          ),
                        if (canComplain)
                          PanelTile(
                            icon: Icons.campaign_outlined,
                            iconColor: AppColors.red,
                            title: s.t('complain'),
                            titleColor: AppColors.redInk,
                            subtitle: s.t('complain_body'),
                            onTap: () => showComplaintSheet(
                              context,
                              builder.complaint(bill, referenceNo: state.connection?.referenceNo),
                            ),
                          ),
                      ].indexed) ...[
                        if (i > 0) const PanelDivider(indent: 54),
                        tile,
                      ],
                    ]),
                  ),
                  const SizedBox(height: Gap.xl),
                  NoteRow(icon: Icons.info_outline_rounded, text: s.t('advice_only')),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The bill as a paper statement: who and when with the verdict stamped
/// beside it, the amount, the verdict in words, units and due date, then the
/// charges the bill lists, ruled like a ledger down to the total.
class _Statement extends StatelessWidget {
  const _Statement({required this.bill});

  final Bill bill;

  /// Worth listing only with the cost of electricity and at least one other
  /// line; a credit bill has no breakdown to explain.
  static bool hasBreakdown(ExtractedBill d) =>
      !d.isCredit && d.energyCharges != null && _lines(d).length > 1;

  /// (label key, amount, glossary code) for each line the bill shows.
  static List<(String, double, String?)> _lines(ExtractedBill d) => [
        for (final (key, amount, code) in [
          ('charge_energy', d.energyCharges, null),
          ('charge_fixed', d.fixedCharges, 'Fixed'),
          ('charge_fpa', d.fpa, 'FPA'),
          ('charge_qtr', d.qtrAdjustment, 'QTR'),
          ('charge_gst', d.gst, 'GST'),
          ('charge_income_tax', d.incomeTax, null),
          ('charge_ed', d.electricityDuty, 'ED'),
          ('charge_tv', d.tvFee, 'PTV Fee'),
          ('charge_arrears', d.arrears, 'Arrears'),
        ])
          if (amount != null && amount != 0) (key, amount, code),
      ];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final builder = ExplanationBuilder(s);
    final data = bill.data;
    final month = formatMonth(data.billMonth, s);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // On a narrow phone the stamp drops under the heading instead of
        // covering it.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(data.disco ?? month, style: theme.textTheme.titleMedium),
              if (data.disco != null) Text(s.t('bill_for', {'month': month}), style: theme.textTheme.bodySmall),
            ]),
            VerdictPill(bill.verdict),
          ],
        ),
        const SizedBox(height: Gap.xl),
        Text(s.t(data.isCredit ? 'credit_due' : 'amount_due'), style: theme.textTheme.bodySmall),
        const SizedBox(height: Gap.xs),
        Text(
          formatAmount(data.totalDue, s),
          style: numberStyle(42, letterSpacing: -1.6, color: data.isCredit ? AppColors.greenInk : AppColors.ink),
        ),
        const SizedBox(height: Gap.md),
        Semantics(
          label: '${builder.verdictLabel(bill.verdict)}. ${builder.verdictSentence(bill.verdict)}',
          excludeSemantics: true,
          child: Text(builder.verdictSentence(bill.verdict), style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: Gap.lg),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Fact(label: s.t('units_label'), value: formatNumber(data.units))),
            if (data.dueDate != null) Expanded(child: _Fact(label: s.t('due_date'), value: formatDate(data.dueDate!, s))),
          ]),
        ),
        if (hasBreakdown(data)) _charges(context, s, theme) else const SizedBox(height: Gap.sm),
      ]),
    );
  }

  Widget _charges(BuildContext context, AppStrings s, ThemeData theme) {
    final data = bill.data;
    final lines = _lines(data);
    // Whatever the listed lines do not explain (rounding, other surcharges).
    final other = data.totalDue - lines.fold<double>(0, (sum, l) => sum + l.$2);
    final rows = [
      for (final (key, amount, code) in lines) (s.t(key, {'units': formatNumber(data.units)}), amount, code),
      if (other.abs() >= 1) (s.t('charge_other'), other, null),
    ];
    final rule = BorderSide(color: AppColors.ink.withValues(alpha: 0.85), width: 1.5);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 0, decoration: BoxDecoration(border: Border(top: rule))),
      for (final (i, (label, amount, code)) in rows.indexed) ...[
        if (i > 0) const Divider(),
        // Same height with or without the info button, so amounts line up.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            Expanded(
              child: Row(children: [
                Flexible(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink))),
                if (code != null)
                  IconButton(
                    tooltip: s.t('what_is_this'),
                    iconSize: 17,
                    color: AppColors.inkSubtle,
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () => _explain(context, code),
                  ),
              ]),
            ),
            const SizedBox(width: Gap.md),
            Text(formatAmount(amount, s), style: numberStyle(14, mono: true)),
          ]),
        ),
      ],
      Container(
        decoration: BoxDecoration(border: Border(top: rule)),
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Row(children: [
          Expanded(child: Text(s.t('charge_total'), style: theme.textTheme.titleMedium)),
          Text(formatAmount(data.totalDue, s), style: numberStyle(16, mono: true)),
        ]),
      ),
    ]);
  }

  void _explain(BuildContext context, String code) {
    final s = context.read<AppStrings>();
    final item = s.glossary.where((g) => g.code == code).firstOrNull;
    if (item == null) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.xs, Gap.xl),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: Gap.sm),
              Text(item.meaning, style: Theme.of(sheetContext).textTheme.bodyLarge),
            ]),
          ),
          PlayButton(id: 'glossary_${item.code}', text: '${item.title}. ${item.meaning}'),
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Gap.xs),
          Text(value, style: numberStyle(14, mono: true)),
        ],
      );
}

/// "Listen to explanation" as the ink button right under the statement, so
/// people who prefer listening find it first.
class _ListenAll extends StatelessWidget {
  const _ListenAll({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    final s = context.s;
    return ValueListenableBuilder<String?>(
      valueListenable: tts.playing,
      builder: (context, playing, _) {
        final isPlaying = playing == 'all';
        return PrimaryButton(
          icon: isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          label: isPlaying ? s.t('stop') : s.t('listen_all'),
          onPressed: () => tts.toggle('all', text),
        );
      },
    );
  }
}

/// Units used against the protected limit, as a groove, with the sentence
/// that explains it.
class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.units});

  final int units;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final config = context.read<BillRepository>().tariffConfig;
    final limit = config.protectedLimitUnits;
    final text = ExplanationBuilder(s).meterText(units, limit);
    final left = limit - units;
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.xs, Gap.xs, Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              s.t('units_of_limit', {'units': formatNumber(units), 'limit': formatNumber(limit)}),
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (left > 0) Text(s.t('units_left', {'left': formatNumber(left)}), style: theme.textTheme.bodySmall),
          PlayButton(id: 'meter', text: text),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.md),
          child: UnitMeter(units: units, limit: limit, nearLimit: config.nearLimitUnits, height: 14, showScale: true),
        ),
      ]),
    );
  }
}

/// Findings as short titles that open to the full sentence. The most serious
/// one starts open.
class _Findings extends StatefulWidget {
  const _Findings({required this.findings, required this.builder});

  final List<Finding> findings;
  final ExplanationBuilder builder;

  @override
  State<_Findings> createState() => _FindingsState();
}

class _FindingsState extends State<_Findings> {
  late final Set<Finding> _open = {
    widget.findings.where((f) => !f.isSummary).firstOrNull ?? widget.findings.first,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builder = widget.builder;
    return Column(children: [
      for (final (i, f) in widget.findings.indexed) ...[
        if (i > 0) const SizedBox(height: Gap.sm),
        AppCard(padding: EdgeInsets.zero, child: _finding(f, theme, builder)),
      ],
    ]);
  }

  Widget _finding(Finding f, ThemeData theme, ExplanationBuilder builder) {
    final open = _open.contains(f);
    final text = builder.findingText(f);
    final icon = f.isSummary
        ? const Icon(Icons.receipt_long_outlined, color: AppColors.inkMuted, size: 20)
        : Icon(Tone.ofSeverity(f.severity).icon, color: Tone.ofSeverity(f.severity).color, size: 20);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        expanded: open,
        child: InkWell(
          onTap: () => setState(() => open ? _open.remove(f) : _open.add(f)),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.md + 2, Gap.md, Gap.md + 2),
            child: Row(children: [
              icon,
              const SizedBox(width: Gap.md + 2),
              Expanded(child: Text(builder.findingTitle(f), style: theme.textTheme.titleSmall)),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.inkMuted),
            ]),
          ),
        ),
      ),
      if (open)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(50, 0, Gap.xs, Gap.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink)),
              ),
            ),
            PlayButton(id: f.ruleId, text: text),
          ]),
        ),
    ]);
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
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.xs, Gap.xs, Gap.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.record_voice_over_outlined, color: AppColors.inkMuted, size: 20),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(s.t('tts_tip'), style: Theme.of(context).textTheme.bodyLarge)),
          IconButton(
            tooltip: s.t('cancel'),
            color: AppColors.inkSubtle,
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onClose,
          ),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: Gap.xxl - 2),
          child: TextButton(
            onPressed: () => launchUrl(Uri.parse(AppConstants.googleTtsPlayStoreUrl), mode: LaunchMode.externalApplication),
            child: Text(s.t('install')),
          ),
        ),
      ]),
    );
  }
}

class _ForecastResult extends StatelessWidget {
  const _ForecastResult({required this.forecast, required this.onChange});

  final BillForecast forecast;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final builder = ExplanationBuilder(s);
    final tone = forecast.overLimit ? Tone.wrong : forecast.mayCrossLimit ? Tone.check : Tone.normal;
    final hasAmount = forecast.amountLow != null && forecast.amountHigh != null;

    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.sm, Gap.xs, Gap.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatMonth(forecast.month, s), style: theme.textTheme.bodySmall),
              Text(s.t('forecast_units', {'units': formatNumber(forecast.units)}), style: theme.textTheme.titleMedium),
            ]),
          ),
          PlayButton(id: 'forecast', text: builder.forecastText(forecast)),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (hasAmount) ...[
              const SizedBox(height: Gap.sm),
              Text(
                '${formatAmount(forecast.amountLow!, s)} – ${formatAmount(forecast.amountHigh!, s)}',
                style: numberStyle(24, letterSpacing: -0.3),
              ),
            ],
            const SizedBox(height: Gap.xs),
            Text(builder.forecastBasis(forecast), style: theme.textTheme.bodySmall),
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(color: tone.soft, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: Icon(tone.icon, color: tone.color, size: 18)),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(builder.forecastAdvice(forecast), style: theme.textTheme.bodyMedium?.copyWith(color: tone.ink))),
              ]),
            ),
            const SizedBox(height: Gap.sm),
            Text(s.t('forecast_disclaimer'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSubtle)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Gap.xs)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(s.t('forecast_change')),
                onPressed: onChange,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The meter reading the user typed, and the bill to estimate from (with the
/// bill's own reading filled in if the bill did not show one).
typedef MeterInput = ({ExtractedBill bill, int reading});

/// Asks for today's meter reading (and the bill's, if the bill had none).
/// Returns null if dismissed.
Future<MeterInput?> showMeterSheet(BuildContext context, {required ExtractedBill bill, required Forecaster forecaster}) =>
    showModalBottomSheet<MeterInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MeterSheet(bill: bill, forecaster: forecaster, s: context.read<AppStrings>()),
    );

class _MeterSheet extends StatefulWidget {
  const _MeterSheet({required this.bill, required this.forecaster, required this.s});

  final ExtractedBill bill;
  final Forecaster forecaster;
  final AppStrings s;

  @override
  State<_MeterSheet> createState() => _MeterSheetState();
}

class _MeterSheetState extends State<_MeterSheet> {
  final _today = TextEditingController();
  final _onBill = TextEditingController();
  String? _todayError, _billError;

  /// Largest believable use since the bill (about 2 months of a big house).
  static const _maxJump = 5000;

  bool get _billHasReading => widget.bill.presentReading != null;

  @override
  void dispose() {
    _today.dispose();
    _onBill.dispose();
    super.dispose();
  }

  void _submit() {
    final s = widget.s;
    final onBill = _billHasReading ? widget.bill.presentReading : int.tryParse(_onBill.text);
    final today = int.tryParse(_today.text);
    setState(() {
      _billError = onBill == null ? s.t('forecast_enter_number') : null;
      _todayError = today == null ? s.t('forecast_enter_number') : null;
    });
    if (onBill == null || today == null) return;

    final bill = _billHasReading ? widget.bill : widget.bill.copyWith(presentReading: onBill);
    final problem = widget.forecaster.meterProblem(bill, today);
    final error = switch (problem) {
      MeterProblem.belowBill => s.t('forecast_meter_invalid', {'reading': '$onBill'}),
      MeterProblem.tooSoon => s.t('forecast_too_soon'),
      MeterProblem.tooOld => s.t('forecast_too_old'),
      MeterProblem.noDate => s.t('forecast_no_date'),
      null => today - onBill > _maxJump ? s.t('forecast_too_big') : null,
    };
    if (error != null) {
      setState(() => _todayError = error);
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context, (bill: bill, reading: today));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    Widget field(TextEditingController c, String label, String? error, {bool autofocus = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: c,
              autofocus: autofocus,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              inputFormatters: [WesternDigitsFormatter(), LengthLimitingTextInputFormatter(8)],
              style: numberStyle(22),
              decoration: InputDecoration(hintText: s.t('forecast_meter_hint'), errorText: error),
              onSubmitted: (_) => _submit(),
            ),
          ],
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('forecast_cta'), style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.xs),
          Text(s.t('forecast_reading_note'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.lg),
          if (_billHasReading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Row(children: [
                Expanded(child: Text(s.t('forecast_bill_reading'), style: theme.textTheme.bodyMedium)),
                Text('${widget.bill.presentReading}', style: numberStyle(16)),
              ]),
            )
          else
            field(_onBill, s.t('forecast_bill_reading'), _billError, autofocus: true),
          const SizedBox(height: Gap.lg),
          field(_today, s.t('forecast_meter_title'), _todayError, autofocus: _billHasReading),
          const SizedBox(height: Gap.xl),
          PrimaryButton(label: s.t('forecast_meter_apply'), onPressed: _submit),
        ]),
      ),
    );
  }
}
