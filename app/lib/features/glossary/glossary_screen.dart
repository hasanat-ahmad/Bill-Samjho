import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
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
    final s = context.s;
    final theme = Theme.of(context);
    final items = s.glossary;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('glossary'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, bottomPadding(context)),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) const PanelDivider(),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.md, Gap.xs, Gap.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(item.title, style: theme.textTheme.titleSmall),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Gap.xs + 2, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderStrong),
                              borderRadius: BorderRadius.circular(Radii.xs),
                            ),
                            child: Text(item.code, style: numberStyle(11.5, color: AppColors.inkMuted, weight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: Gap.xs),
                        Text(item.meaning, style: theme.textTheme.bodyMedium),
                      ]),
                    ),
                    PlayButton(id: 'glossary_${item.code}', text: '${item.title}. ${item.meaning}'),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
