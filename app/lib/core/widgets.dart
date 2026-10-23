import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/bill_repository.dart';
import '../data/models/finding.dart';
import '../domain/explanation_builder.dart';
import '../services/tts_service.dart';
import 'i18n.dart';
import 'theme.dart';

/// Bottom padding for scrolling pages: [base] plus the system gesture bar,
/// since Android draws apps edge to edge.
double bottomPadding(BuildContext context, [double base = Gap.xxl]) => base + MediaQuery.paddingOf(context).bottom;

/// App mark: the launcher icon (a bill with a lightning bolt).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: const CustomPaint(painter: _LogoPainter()));
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)),
      Paint()..color = AppColors.primary,
    );
    // Same shapes as res/drawable/ic_launcher_foreground.xml (108-unit box,
    // content inside 28..80), with a margin around them.
    canvas.save();
    canvas.scale(s / 72);
    canvas.translate(-19, -18);
    Path poly(List<double> p) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      return path..close();
    }

    canvas.drawPath(poly([36, 28, 64, 28, 74, 38, 74, 80, 36, 80]), Paint()..color = Colors.white);
    canvas.drawPath(poly([64, 28, 64, 38, 74, 38]), Paint()..color = const Color(0xFFBBDEFB));
    canvas.drawPath(poly([58, 36, 44, 57, 53, 57, 49, 72, 64, 50, 55, 50]), Paint()..color = const Color(0xFFF9A825));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}

/// White section on the grey page; optionally tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.color = AppColors.surface,
    this.borderColor,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small muted heading above a section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.xs, Gap.xl, 0, Gap.sm),
      child: Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.labelSmall)),
        ?trailing,
      ]),
    );
  }
}

/// Hairline between rows inside a section, inset from the start edge.
class PanelDivider extends StatelessWidget {
  const PanelDivider({super.key, this.indent = Gap.lg});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(indent: indent, endIndent: 0);
}

/// A row in a section: optional icon, title, subtitle and trailing widget.
class PanelTile extends StatelessWidget {
  const PanelTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor = AppColors.inkMuted,
    this.titleColor,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Shows a chevron when tappable and there is no [trailing].
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.md, Gap.md, Gap.md),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: Gap.lg),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(color: titleColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: Gap.sm), trailing!],
            if (trailing == null && chevron && onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
          ]),
        ),
      ),
    );
  }
}

/// Muted icon + small text, for notes under forms and sections.
class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.icon, required this.text, this.color = AppColors.inkSubtle});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: color, size: 17)),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]);
}

/// Verdict as colour + icon + word (NFR-03).
class VerdictPill extends StatelessWidget {
  const VerdictPill(this.verdict, {super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.ofVerdict(verdict);
    final label = ExplanationBuilder(context.s).verdictLabel(verdict);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.sm, 3, Gap.sm + 2, 3),
        decoration: BoxDecoration(color: tone.soft, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(tone.icon, color: tone.color, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone.ink, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

/// Full-width primary action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false, this.color});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color,
      minimumSize: const Size.fromHeight(50),
    );
    final iconWidget = busy
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
        : icon == null
            ? null
            : Icon(icon, size: 20);
    final onTap = busy || onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };
    return iconWidget == null
        ? FilledButton(style: style, onPressed: onTap, child: Text(label, textAlign: TextAlign.center))
        : FilledButton.icon(style: style, onPressed: onTap, icon: iconWidget, label: Text(label, textAlign: TextAlign.center));
  }
}

/// Full-width secondary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50));
    return icon == null
        ? OutlinedButton(style: style, onPressed: onPressed, child: Text(label, textAlign: TextAlign.center))
        : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label, textAlign: TextAlign.center));
  }
}

/// Quiet play/stop icon for one piece of text (FR-10).
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.id, required this.text});

  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    final s = context.s;
    return ValueListenableBuilder<String?>(
      valueListenable: tts.playing,
      builder: (context, playing, _) {
        final isPlaying = playing == id;
        return IconButton(
          tooltip: isPlaying ? s.t('stop') : s.t('listen'),
          iconSize: 20,
          color: isPlaying ? AppColors.primary : AppColors.inkSubtle,
          icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
          onPressed: () => tts.toggle(id, text),
        );
      },
    );
  }
}

/// Units used against the protected limit (FR-11).
class UnitMeter extends StatelessWidget {
  const UnitMeter({
    super.key,
    required this.units,
    required this.limit,
    required this.nearLimit,
    this.height = 6,
    this.showScale = false,
  });

  final int units;
  final int limit;
  final int nearLimit;
  final double height;
  final bool showScale;

  Tone get tone => units > limit
      ? Tone.wrong
      : units >= nearLimit
          ? Tone.check
          : Tone.normal;

  @override
  Widget build(BuildContext context) {
    final fraction = (units / limit).clamp(0.0, 1.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          // Containers without a child fill the space they are given.
          Container(color: const Color(0xFFE6E9ED)),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction,
            child: Container(color: tone.color),
          ),
          // Tick where "near the limit" starts.
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: (nearLimit / limit).clamp(0.0, 1.0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Container(width: 2, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
    if (!showScale) return bar;
    final scaleStyle = numberStyle(12, color: AppColors.inkSubtle, weight: FontWeight.w500);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      bar,
      const SizedBox(height: Gap.xs + 2),
      Row(children: [
        Text('0', style: scaleStyle),
        const Spacer(),
        Text('$limit', style: scaleStyle),
      ]),
    ]);
  }
}

/// Icon + title + body + actions, for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.tone,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? body;

  /// Colours the icon; neutral when null.
  final Tone? tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - Gap.xl * 2),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tone?.soft ?? AppColors.surface,
                shape: BoxShape.circle,
                border: tone == null ? Border.all(color: AppColors.border) : null,
              ),
              child: Icon(icon, size: 30, color: tone?.color ?? AppColors.inkMuted),
            ),
            const SizedBox(height: Gap.xl),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Gap.sm),
              Text(body!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            const SizedBox(height: Gap.xxl),
            for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: Gap.sm), child: a),
          ]),
        ),
      ),
    );
  }
}

/// Warns that sample data is shown, whenever the mock API is active.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.read<BillRepository>().isDemo) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.amberSoft,
        border: Border(bottom: BorderSide(color: Color(0xFFF0DFB4))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: Gap.sm),
      child: Row(children: [
        const Icon(Icons.science_outlined, color: AppColors.amberInk, size: 16),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(context.s.t('demo_banner'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.amberInk)),
        ),
      ]),
    );
  }
}

/// Destructive action confirmation. Returns true if confirmed.
Future<bool> confirmDialog(BuildContext context, String question, {required String confirmLabel}) async {
  final s = context.read<AppStrings>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question, style: Theme.of(context).textTheme.titleMedium),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('keep')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// English / اردو switch. Each option is written in its own script so it is
/// recognisable whatever the current language.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, required this.value, required this.onChanged});

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: AppLanguage.en,
          label: Text('English', style: TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        ButtonSegment(
          value: AppLanguage.ur,
          label: Text('اردو', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 15)),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) {
        HapticFeedback.selectionClick();
        onChanged(s.first);
      },
    );
  }
}

/// Numbered step, used in a section with dividers between steps.
class StepRow extends StatelessWidget {
  const StepRow({super.key, required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md + 2),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
          child: Text('$number', style: numberStyle(13, color: AppColors.primaryDark, weight: FontWeight.w700)),
        ),
        const SizedBox(width: Gap.md + 2),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ]),
    );
  }
}

/// Converts Urdu (۰-۹) and Arabic (٠-٩) digits to 0-9 and drops anything else,
/// so users with an Urdu keyboard can still correct numbers.
class WesternDigitsFormatter extends TextInputFormatter {
  WesternDigitsFormatter({this.allowDecimal = false});

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
