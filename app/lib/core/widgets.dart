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

/// App mark: a bill with a lightning bolt.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.receipt_long_rounded, color: Colors.white, size: size * 0.56),
        PositionedDirectional(
          end: size * 0.12,
          bottom: size * 0.1,
          child: Icon(Icons.bolt_rounded, color: AppColors.amber, size: size * 0.36),
        ),
      ]),
    );
  }
}

/// White rounded card with a hairline border; optionally tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.page),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(color: borderColor),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg + Gap.xs, bottom: Gap.sm + 2),
      child: Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ]),
    );
  }
}

/// Rounded square with a tinted background and an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, required this.color, required this.background, this.size = 40});

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
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
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.sm, Gap.xs, Gap.md, Gap.xs),
        decoration: BoxDecoration(color: tone.soft, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(tone.icon, color: tone.color, size: 18),
          const SizedBox(width: Gap.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone.ink)),
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
      minimumSize: const Size.fromHeight(52),
    );
    final iconWidget = busy
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : icon == null
            ? null
            : Icon(icon, size: 22);
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

/// Round play/stop button for one piece of text (FR-10).
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.id, required this.text, this.tone = Tone.info});

  final String id;
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    final s = context.s;
    return ValueListenableBuilder<String?>(
      valueListenable: tts.playing,
      builder: (context, playing, _) {
        final isPlaying = playing == id;
        return IconButton.filledTonal(
          tooltip: isPlaying ? s.t('stop') : s.t('listen'),
          style: IconButton.styleFrom(backgroundColor: tone.soft, foregroundColor: tone.ink),
          iconSize: 22,
          icon: Icon(isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded),
          onPressed: () => tts.toggle(id, text),
        );
      },
    );
  }
}

/// Large "listen" action with an animated sound wave while speaking.
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.id, required this.text, required this.label});

  final String id;
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    final s = context.s;
    final theme = Theme.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: tts.playing,
      builder: (context, playing, _) {
        final isPlaying = playing == id;
        return Semantics(
          button: true,
          label: isPlaying ? s.t('stop') : label,
          excludeSemantics: true,
          child: AppCard(
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
            onTap: () {
              HapticFeedback.selectionClick();
              tts.toggle(id, text);
            },
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Icon(isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Text(
                  isPlaying ? s.t('stop') : label,
                  style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primaryDark),
                ),
              ),
              if (isPlaying) const _SoundWave(),
            ]),
          ),
        );
      },
    );
  }
}

class _SoundWave extends StatefulWidget {
  const _SoundWave();

  @override
  State<_SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<_SoundWave> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: 8 + 16 * (0.5 + 0.5 * _wave(_c.value + i * 0.22)),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
          ),
      ]),
    );
  }

  static double _wave(double t) {
    final x = (t % 1) * 2 - 1; // -1..1
    return 1 - 2 * x.abs(); // triangle wave -1..1
  }
}

/// Units used against the protected limit (FR-11).
class UnitMeter extends StatelessWidget {
  const UnitMeter({
    super.key,
    required this.units,
    required this.limit,
    required this.nearLimit,
    this.height = 12,
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
          Container(color: AppColors.surfaceAlt),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction,
            child: Container(color: tone.color),
          ),
          // Marker where "near the limit" starts.
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: (nearLimit / limit).clamp(0.0, 1.0),
            child: const Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(width: 2, child: ColoredBox(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
    if (!showScale) return bar;
    final scaleStyle = numberStyle(13, color: AppColors.inkMuted, weight: FontWeight.w500);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      bar,
      const SizedBox(height: Gap.xs),
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
    this.tone = Tone.info,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? body;
  final Tone tone;
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: tone.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: tone.color),
            ),
            const SizedBox(height: Gap.xl),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Gap.sm),
              Text(body!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            const SizedBox(height: Gap.xxl),
            for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: Gap.md), child: a),
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
      color: AppColors.amberSoft,
      padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: Gap.sm),
      child: Row(children: [
        const Icon(Icons.science_rounded, color: AppColors.amberInk, size: 18),
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
      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 36),
      content: Text(question, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('keep'))),
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

/// Illustration: a bill with a tick and a speaker, used on intro and empty home.
class BillIllustration extends StatelessWidget {
  const BillIllustration({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    final line = BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4));
    // Fixed left-to-right so the decoration is identical in both languages.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _illustration(line),
    );
  }

  Widget _illustration(BoxDecoration line) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primarySoft, Color(0xFFF7FAFE)],
        ),
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Center(
        child: SizedBox(
          width: 180,
          height: height * 0.78,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.amber, size: 18),
                      const SizedBox(width: 6),
                      Container(width: 60, height: 8, decoration: line),
                    ]),
                    const SizedBox(height: Gap.sm),
                    Container(width: 120, height: 7, decoration: line),
                    const SizedBox(height: Gap.sm),
                    Container(width: 90, height: 7, decoration: line),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Rs 5,867', style: numberStyle(18, color: AppColors.primaryDark)),
                    ),
                  ]),
                ),
              ),
            ),
            const Positioned(
              top: -14,
              right: -18,
              child: _Bubble(icon: Icons.check_rounded, color: AppColors.green),
            ),
            const Positioned(
              bottom: -10,
              left: -20,
              child: _Bubble(icon: Icons.volume_up_rounded, color: AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      );
}

/// Numbered step row used to explain the flow.
class StepRow extends StatelessWidget {
  const StepRow({super.key, required this.number, required this.icon, required this.text});

  final int number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs + 2),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          IconBadge(icon, color: AppColors.primary, background: AppColors.primarySoft, size: 40),
          PositionedDirectional(
            top: -5,
            start: -5,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text('$number', style: numberStyle(11, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(width: Gap.lg),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
      ]),
    );
  }
}
