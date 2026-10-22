import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import 'settings_cubit.dart';

/// S10: language, voice speed, text size, delete all data (FR-17).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearAll(BuildContext context) async {
    final s = context.read<AppStrings>();
    if (!await confirmDialog(context, s.t('clear_all_q'), confirmLabel: s.t('delete'))) return;
    if (!context.mounted) return;
    await context.read<SettingsCubit>().clearAllData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('cleared'))));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final tariffVersion = context.read<BillRepository>().tariffConfig.version;
    final version = context.read<AppVersion>().value;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, bottomPadding(context)),
            children: [
              SectionTitle(s.t('language')),
              LanguageSwitch(value: settings.language, onChanged: cubit.setLanguage),
              SectionTitle(s.t('voice_speed')),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(s.t('slow')), icon: const Icon(Icons.slow_motion_video_rounded)),
                  ButtonSegment(value: false, label: Text(s.t('normal')), icon: const Icon(Icons.play_arrow_rounded)),
                ],
                selected: {settings.slowVoice},
                onSelectionChanged: (v) => cubit.setSlowVoice(v.first),
              ),
              SectionTitle(s.t('text_size')),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(s.t('normal')), icon: const Icon(Icons.text_fields_rounded)),
                  ButtonSegment(value: true, label: Text(s.t('large')), icon: const Icon(Icons.format_size_rounded)),
                ],
                selected: {settings.largeText},
                onSelectionChanged: (v) => cubit.setLargeText(v.first),
              ),
              SectionTitle(s.t('privacy_section')),
              AppCard(
                color: AppColors.surfaceAlt,
                borderColor: AppColors.surfaceAlt,
                padding: const EdgeInsets.all(Gap.lg),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconBadge(Icons.shield_rounded, color: AppColors.green, background: AppColors.greenSoft),
                  const SizedBox(width: Gap.md),
                  Expanded(child: Text(s.t('data_on_device'), style: theme.textTheme.bodyMedium)),
                ]),
              ),
              const SizedBox(height: Gap.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(color: AppColors.red.withValues(alpha: 0.5), width: 1.5),
                  minimumSize: const Size.fromHeight(58),
                ),
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(s.t('clear_all')),
                onPressed: () => _clearAll(context),
              ),
              SectionTitle(s.t('about')),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const AppLogo(size: 44),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.t('app_name'), style: theme.textTheme.titleMedium),
                        if (version.isNotEmpty) Text(s.t('version', {'version': version}), style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: Gap.md),
                  Text(s.t('tariff_version', {'version': tariffVersion}), style: theme.textTheme.bodySmall),
                  const SizedBox(height: Gap.sm),
                  Text(s.t('unofficial'), style: theme.textTheme.bodySmall),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
