import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/tts_service.dart';
import '../settings/settings_cubit.dart';

/// S1: first launch only (FR-01). Language choice comes first.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final settings = context.read<SettingsCubit>();
    await context.read<TtsService>().stop();
    await settings.completeOnboarding();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsCubit>();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
              children: [
                Row(children: [
                  const AppLogo(size: 30),
                  const SizedBox(width: Gap.sm + 2),
                  Expanded(child: Text(s.t('app_name'), style: theme.textTheme.titleMedium)),
                ]),
                const SizedBox(height: Gap.lg),
                LanguageSwitch(value: settings.state.language, onChanged: settings.setLanguage),
                const SizedBox(height: Gap.xxl),
                Text(s.t('intro_title'), style: theme.textTheme.displaySmall),
                const SizedBox(height: Gap.sm),
                Text(s.t('intro_subtitle'), style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted)),
                const SizedBox(height: Gap.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _ListenText(
                    id: 'intro',
                    text: '${s.t('intro_title')}. ${s.t('intro_subtitle')} ${s.t('privacy')}',
                  ),
                ),
                const SizedBox(height: Gap.lg),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    StepRow(number: 1, text: s.t('intro_step_scan')),
                    const PanelDivider(indent: 56),
                    StepRow(number: 2, text: s.t('intro_step_listen')),
                    const PanelDivider(indent: 56),
                    StepRow(number: 3, text: s.t('intro_step_check')),
                  ]),
                ),
                SectionTitle(s.t('privacy_title')),
                AppCard(
                  child: NoteRow(icon: Icons.lock_outline_rounded, color: AppColors.green, text: s.t('privacy')),
                ),
                const SizedBox(height: Gap.lg),
                Text(s.t('unofficial'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSubtle)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.page),
            child: PrimaryButton(label: s.t('get_started'), onPressed: () => _start(context)),
          ),
        ]),
      ),
    );
  }
}

/// "Listen" as a text button, so the action is named, not just an icon.
class _ListenText extends StatelessWidget {
  const _ListenText({required this.id, required this.text});

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
        return TextButton.icon(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Gap.xs)),
          icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined, size: 20),
          label: Text(isPlaying ? s.t('stop') : s.t('listen')),
          onPressed: () => tts.toggle(id, text),
        );
      },
    );
  }
}
