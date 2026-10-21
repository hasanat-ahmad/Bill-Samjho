import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../data/models/urdu_strings.dart';
import '../../services/tts_service.dart';

/// S9: what each bill line means (FR-15). Works offline.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsService>();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = context.read<UrduStrings>().glossary;
    return Scaffold(
      appBar: AppBar(title: const Text(Labels.glossary)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(item.title, style: theme.textTheme.titleLarge),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(item.code, style: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.meaning, style: theme.textTheme.bodyLarge),
                    ]),
                  ),
                  PlayButton(id: 'glossary_${item.code}', text: '${item.title}۔ ${item.meaning}'),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
