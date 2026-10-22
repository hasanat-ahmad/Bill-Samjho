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
                  const AppLogo(size: 40),
                  const SizedBox(width: Gap.md),
                  Expanded(child: Text(s.t('app_name'), style: theme.textTheme.titleLarge)),
                ]),
                const SizedBox(height: Gap.lg),
                LanguageSwitch(value: settings.state.language, onChanged: settings.setLanguage),
                const SizedBox(height: Gap.xl),
                const BillIllustration(),
                const SizedBox(height: Gap.xl),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(s.t('intro_title'), style: theme.textTheme.headlineMedium)),
                  const SizedBox(width: Gap.sm),
                  PlayButton(
                    id: 'intro',
                    text: '${s.t('intro_title')}. ${s.t('intro_subtitle')} ${s.t('privacy')}',
                  ),
                ]),
                const SizedBox(height: Gap.sm),
                Text(s.t('intro_subtitle'), style: theme.textTheme.bodyMedium),
                const SizedBox(height: Gap.lg),
                StepRow(number: 1, icon: Icons.photo_camera_rounded, text: s.t('intro_step_scan')),
                StepRow(number: 2, icon: Icons.record_voice_over_rounded, text: s.t('intro_step_listen')),
                StepRow(number: 3, icon: Icons.fact_check_rounded, text: s.t('intro_step_check')),
                const SizedBox(height: Gap.lg),
                AppCard(
                  color: AppColors.surfaceAlt,
                  borderColor: AppColors.surfaceAlt,
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const IconBadge(Icons.lock_rounded, color: AppColors.green, background: AppColors.greenSoft),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.t('privacy_title'), style: theme.textTheme.titleSmall),
                        const SizedBox(height: Gap.xs),
                        Text(s.t('privacy'), style: theme.textTheme.bodyMedium),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: Gap.lg),
                Text(s.t('unofficial'), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.page),
            child: PrimaryButton(
              label: s.t('get_started'),
              icon: Icons.arrow_forward_rounded,
              onPressed: () => _start(context),
            ),
          ),
        ]),
      ),
    );
  }
}
