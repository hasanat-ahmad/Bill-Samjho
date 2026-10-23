import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/extracted_bill.dart';
import '../../domain/format.dart';
import 'scan_cubit.dart';

/// S5: month, units, total, due date; units and total editable (FR-07).
class ConfirmView extends StatefulWidget {
  const ConfirmView({super.key, required this.data, required this.jpeg, required this.saving});

  final ExtractedBill data;
  final Uint8List? jpeg;
  final bool saving;

  @override
  State<ConfirmView> createState() => _ConfirmViewState();
}

class _ConfirmViewState extends State<ConfirmView> {
  late final _units = TextEditingController(text: '${widget.data.units}');
  // Credit bills are edited as a positive amount and stored as negative.
  late final _total = TextEditingController(text: _plain(widget.data.totalDue.abs()));
  final _form = GlobalKey<FormState>();

  static String _plain(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _units.dispose();
    _total.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final total = double.parse(_total.text);
    context.read<ScanCubit>().confirm(
          units: int.parse(_units.text),
          totalDue: widget.data.isCredit ? -total : total,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final data = widget.data;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('confirm_title'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
          children: [
            Text(s.t('confirm_hint'), style: theme.textTheme.bodyMedium),
            if (data.confidence < AppConstants.lowConfidence) ...[
              const SizedBox(height: Gap.md),
              Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(Radii.sm)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.amber, size: 20),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(s.t('confirm_low_confidence'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.amberInk)),
                  ),
                ]),
              ),
            ],
            if (widget.jpeg != null) ...[
              const SizedBox(height: Gap.lg),
              _PhotoPreview(widget.jpeg!),
            ],
            const SizedBox(height: Gap.lg),
            _InfoTile(label: s.t('month'), value: formatMonth(data.billMonth, s)),
            const SizedBox(height: Gap.lg),
            _NumberField(
              controller: _units,
              label: s.t('units_label'),
              allowDecimal: false,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 0 || n > ExtractedBill.maxUnits ? s.t('invalid_number') : null;
              },
            ),
            const SizedBox(height: Gap.md),
            _NumberField(
              controller: _total,
              label: s.t('total_label'),
              allowDecimal: true,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n < 0 || n > ExtractedBill.maxAmount ? s.t('invalid_number') : null;
              },
            ),
            if (data.isCredit) ...[
              const SizedBox(height: Gap.sm),
              Row(children: [
                const Icon(Icons.savings_outlined, color: AppColors.green, size: 20),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(s.t('credit_bill'), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.greenInk))),
              ]),
            ],
            if (data.dueDate != null) ...[
              const SizedBox(height: Gap.lg),
              _InfoTile(label: s.t('due_date'), value: formatDate(data.dueDate!, s)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
            child: PrimaryButton(
              label: s.t('looks_right'),
              busy: widget.saving,
              onPressed: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview(this.jpeg);

  final Uint8List jpeg;

  void _zoom(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 6,
                child: Center(child: Image.memory(jpeg, fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Semantics(
      button: true,
      label: s.t('tap_to_zoom'),
      child: GestureDetector(
        onTap: () => _zoom(context),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Image.memory(jpeg, height: 150, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter),
            PositionedDirectional(
              bottom: Gap.sm,
              end: Gap.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs + 2),
                decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: Gap.xs),
                  Text(s.t('tap_to_zoom'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A value read from the bill that is not edited here.
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md + 2),
      child: Row(children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.titleSmall),
      ]),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.allowDecimal,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool allowDecimal;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: Gap.xs, bottom: Gap.sm),
        child: Text(label, style: theme.textTheme.titleSmall),
      ),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: [WesternDigitsFormatter(allowDecimal: allowDecimal), LengthLimitingTextInputFormatter(10)],
        textDirection: TextDirection.ltr,
        style: numberStyle(22),
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.edit_outlined, color: AppColors.inkSubtle, size: 20),
        ),
      ),
    ]);
  }
}
