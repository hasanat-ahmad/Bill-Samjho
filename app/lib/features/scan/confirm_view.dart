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
  final Uint8List jpeg;
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
              const SizedBox(height: Gap.lg),
              AppCard(
                color: AppColors.amberSoft,
                borderColor: AppColors.amberSoft,
                padding: const EdgeInsets.all(Gap.lg),
                child: Row(children: [
                  const Icon(Icons.error_rounded, color: AppColors.amberInk, size: 28),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(s.t('confirm_low_confidence'),
                        style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.amberInk)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: Gap.lg),
            _PhotoPreview(widget.jpeg),
            const SizedBox(height: Gap.lg),
            _InfoTile(icon: Icons.calendar_month_rounded, label: s.t('month'), value: formatMonth(data.billMonth, s)),
            const SizedBox(height: Gap.md),
            _NumberField(
              controller: _units,
              label: s.t('units_label'),
              icon: Icons.bolt_rounded,
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
              icon: Icons.payments_rounded,
              allowDecimal: true,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n < 0 || n > ExtractedBill.maxAmount ? s.t('invalid_number') : null;
              },
            ),
            if (data.isCredit) ...[
              const SizedBox(height: Gap.sm),
              Row(children: [
                const Icon(Icons.savings_rounded, color: AppColors.green, size: 22),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(s.t('credit_bill'), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.greenInk))),
              ]),
            ],
            if (data.dueDate != null) ...[
              const SizedBox(height: Gap.md),
              _InfoTile(icon: Icons.event_rounded, label: s.t('due_date'), value: formatDate(data.dueDate!, s)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
          child: PrimaryButton(
            label: s.t('looks_right'),
            icon: Icons.check_rounded,
            busy: widget.saving,
            onPressed: _submit,
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
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Image.memory(jpeg, height: 180, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter),
            PositionedDirectional(
              bottom: Gap.sm,
              end: Gap.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs + 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(children: [
        IconBadge(icon, color: AppColors.primary, background: AppColors.primarySoft, size: 44),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(value, style: theme.textTheme.titleMedium),
          ]),
        ),
      ]),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.allowDecimal,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool allowDecimal;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: Gap.xs, bottom: Gap.xs),
        child: Text(label, style: theme.textTheme.titleSmall),
      ),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: [_WesternDigitsFormatter(allowDecimal: allowDecimal), LengthLimitingTextInputFormatter(10)],
        textDirection: TextDirection.ltr,
        style: numberStyle(30),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primary, size: 28),
          suffixIcon: const Icon(Icons.edit_rounded, color: AppColors.inkMuted),
        ),
      ),
    ]);
  }
}

/// Converts Urdu (۰-۹) and Arabic (٠-٩) digits to 0-9 and drops anything else,
/// so users with an Urdu keyboard can still correct numbers.
class _WesternDigitsFormatter extends TextInputFormatter {
  _WesternDigitsFormatter({required this.allowDecimal});

  final bool allowDecimal;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    var hasDot = false;
    for (final r in newValue.text.runes) {
      if (r >= 0x30 && r <= 0x39) {
        buffer.writeCharCode(r);
      } else if (r >= 0x6F0 && r <= 0x6F9) {
        buffer.writeCharCode(r - 0x6F0 + 0x30);
      } else if (r >= 0x660 && r <= 0x669) {
        buffer.writeCharCode(r - 0x660 + 0x30);
      } else if (allowDecimal && !hasDot && (r == 0x2E || r == 0x66B)) {
        buffer.write('.');
        hasDot = true;
      }
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
