import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/extracted_bill.dart';
import '../../data/models/urdu_strings.dart';
import '../../domain/urdu_format.dart';
import 'scan_cubit.dart';

/// S5: show month, units, total, due date; units and total editable (FR-07).
class ConfirmView extends StatefulWidget {
  const ConfirmView({super.key, required this.data, required this.saving});

  final ExtractedBill data;
  final bool saving;

  @override
  State<ConfirmView> createState() => _ConfirmViewState();
}

class _ConfirmViewState extends State<ConfirmView> {
  late final _units = TextEditingController(text: '${widget.data.units}');
  late final _total = TextEditingController(text: _plain(widget.data.totalDue));
  final _form = GlobalKey<FormState>();

  static String _plain(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _units.dispose();
    _total.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    context.read<ScanCubit>().confirm(
          units: int.parse(_units.text),
          totalDue: double.parse(_total.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.read<UrduStrings>();
    final data = widget.data;

    return Scaffold(
      appBar: AppBar(title: const Text(Labels.confirmTitle)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(Labels.confirmHint, style: theme.textTheme.bodyLarge),
                  if (data.confidence < AppConstants.lowConfidence) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: AppColors.amber.withValues(alpha: 0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          const Icon(Icons.error, color: Colors.black87, size: 32),
                          const SizedBox(width: 10),
                          Expanded(child: Text(Labels.confirmLowConfidence, style: theme.textTheme.bodyLarge)),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _InfoRow(label: Labels.month, value: formatMonth(data.billMonth, strings)),
                  const SizedBox(height: 16),
                  _NumberField(
                    controller: _units,
                    label: Labels.units,
                    allowDecimal: false,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 5000 ? Labels.invalidNumber : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _NumberField(
                    controller: _total,
                    label: '${Labels.totalAmount} (${Labels.rupees})',
                    allowDecimal: true,
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || n < 0 ? Labels.invalidNumber : null;
                    },
                  ),
                  if (data.dueDate != null) ...[
                    const SizedBox(height: 16),
                    _InfoRow(label: Labels.dueDate, value: formatDate(data.dueDate!, strings)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton.icon(
                  icon: widget.saving
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Icon(Icons.check, size: 32),
                  label: const Text(Labels.ok, style: TextStyle(fontSize: 24)),
                  onPressed: widget.saving ? null : _submit,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Text('$label:', style: theme.textTheme.titleMedium),
      const SizedBox(width: 12),
      Expanded(child: Text(value, style: theme.textTheme.titleLarge)),
    ]);
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
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [_WesternDigitsFormatter(allowDecimal: allowDecimal)],
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      style: numberStyle.copyWith(fontSize: 32),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 22),
        suffixIcon: const Icon(Icons.edit),
      ),
    );
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
