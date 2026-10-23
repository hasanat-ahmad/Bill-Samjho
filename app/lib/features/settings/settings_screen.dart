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
                  ButtonSegment(value: true, label: Text(s.t('slow'))),
                  ButtonSegment(value: false, label: Text(s.t('normal'))),
                ],
                selected: {settings.slowVoice},
                onSelectionChanged: (v) => cubit.setSlowVoice(v.first),
              ),
              SectionTitle(s.t('text_size')),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(s.t('normal'))),
                  ButtonSegment(value: true, label: Text(s.t('large'))),
                ],
                selected: {settings.largeText},
                onSelectionChanged: (v) => cubit.setLargeText(v.first),
              ),
              SectionTitle(s.t('privacy_section')),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: NoteRow(icon: Icons.lock_outline_rounded, color: AppColors.green, text: s.t('data_on_device')),
                  ),
                  const PanelDivider(),
                  PanelTile(
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.red,
                    title: s.t('clear_all'),
                    titleColor: AppColors.red,
                    chevron: false,
                    onTap: () => _clearAll(context),
                  ),
                ]),
              ),
              SectionTitle(s.t('about')),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const AppLogo(size: 36),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.t('app_name'), style: theme.textTheme.titleSmall),
                        if (version.isNotEmpty) Text(s.t('version', {'version': version}), style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: Gap.md),
                  Text(s.t('tariff_version', {'version': tariffVersion}), style: theme.textTheme.bodySmall),
                  const SizedBox(height: Gap.xs),
                  Text(s.t('unofficial'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSubtle)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
