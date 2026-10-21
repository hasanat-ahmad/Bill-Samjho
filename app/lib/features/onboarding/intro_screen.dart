import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../services/tts_service.dart';
import '../settings/settings_cubit.dart';

/// S1: first launch only (FR-01).
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Icon(Icons.receipt_long, size: 112, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(Labels.appName, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(Labels.tagline, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                const SpeakButton(id: 'intro', text: '${Labels.tagline} ${Labels.privacy}'),
                const SizedBox(height: 20),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.lock, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Text(Labels.privacy, style: theme.textTheme.bodyLarge)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Text(Labels.unofficial, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: () async {
                  final settings = context.read<SettingsCubit>();
                  await context.read<TtsService>().stop();
                  await settings.completeOnboarding();
                  if (context.mounted) context.go('/');
                },
                child: const Text(Labels.start, style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
