import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';
import 'settings_cubit.dart';

/// S10: voice speed, text size, delete all data (FR-17).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearAll(BuildContext context) async {
    if (!await confirmDialog(context, Labels.clearAllQ)) return;
    if (!context.mounted) return;
    await context.read<SettingsCubit>().clearAllData();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tariffVersion = context.read<BillRepository>().tariffConfig.version;

    return Scaffold(
      appBar: AppBar(title: const Text(Labels.settings)),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(Labels.voiceSpeed, style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text(Labels.slow), icon: Icon(Icons.slow_motion_video)),
                  ButtonSegment(value: false, label: Text(Labels.normal), icon: Icon(Icons.play_arrow)),
                ],
                selected: {settings.slowVoice},
                onSelectionChanged: (s) => cubit.setSlowVoice(s.first),
              ),
              const SizedBox(height: 28),
              Text(Labels.textSize, style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text(Labels.normal), icon: Icon(Icons.text_fields)),
                  ButtonSegment(value: true, label: Text(Labels.large), icon: Icon(Icons.format_size)),
                ],
                selected: {settings.largeText},
                onSelectionChanged: (s) => cubit.setLargeText(s.first),
              ),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 1.5),
                  minimumSize: const Size.fromHeight(60),
                ),
                icon: const Icon(Icons.delete_forever, size: 28),
                label: const Text(Labels.clearAll),
                onPressed: () => _clearAll(context),
              ),
              const SizedBox(height: 40),
              Text(Labels.unofficial, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              Text(
                'Tariff $tariffVersion',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 14, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
