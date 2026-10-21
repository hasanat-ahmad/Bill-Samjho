import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/finding.dart';
import '../services/tts_service.dart';
import 'constants.dart';
import 'theme.dart';

/// Verdict as colour + icon + word (NFR-03).
class VerdictBadge extends StatelessWidget {
  const VerdictBadge(this.verdict, {super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final s = VerdictStyle.of(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, color: s.onColor, size: 22),
        const SizedBox(width: 6),
        Text(s.label, style: TextStyle(color: s.onColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// Small play/stop button for one piece of text (FR-10).
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.id, required this.text, this.color});

  final String id;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    return ValueListenableBuilder<String?>(
      valueListenable: tts.playing,
      builder: (context, playing, _) {
        final isPlaying = playing == id;
        return IconButton(
          tooltip: isPlaying ? Labels.stop : Labels.listen,
          iconSize: 32,
          color: color ?? AppColors.primary,
          icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill),
          onPressed: () => tts.toggle(id, text),
        );
      },
    );
  }
}

/// Large labelled play/stop button, e.g. "listen to the whole bill".
class SpeakButton extends StatelessWidget {
  const SpeakButton({super.key, required this.id, required this.text, this.label = Labels.listen});

  final String id;
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    return ValueListenableBuilder<String?>(
      valueListenable: tts.playing,
      builder: (context, playing, _) {
        final isPlaying = playing == id;
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          icon: Icon(isPlaying ? Icons.stop : Icons.volume_up, size: 36),
          label: Text(isPlaying ? Labels.stop : label, style: const TextStyle(fontSize: 22)),
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
    this.height = 24,
  });

  final int units;
  final int limit;
  final int nearLimit;
  final double height;

  Color get _color => units > limit
      ? AppColors.red
      : units >= nearLimit
          ? AppColors.amber
          : AppColors.green;

  @override
  Widget build(BuildContext context) {
    final fraction = (units / limit).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Container(color: Colors.grey.shade300),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction,
            child: Container(color: _color),
          ),
        ]),
      ),
    );
  }
}

/// Icon + message + actions, used for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
    this.iconColor,
    this.actions = const [],
  });

  final IconData icon;
  final String message;
  final String? detail;
  final Color? iconColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 96, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 12), child: SizedBox(width: double.infinity, child: a)),
        ]),
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String question, {String confirmLabel = Labels.delete}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question, style: Theme.of(context).textTheme.titleMedium),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(Labels.no)),
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
