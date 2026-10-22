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

  static const _icons = {
    'fuel': Icons.local_gas_station_rounded,
    'calendar': Icons.calendar_month_rounded,
    'tax': Icons.account_balance_rounded,
    'fixed': Icons.push_pin_rounded,
    'history': Icons.history_rounded,
    'late': Icons.schedule_rounded,
    'tv': Icons.tv_off_rounded,
  };

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
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, bottomPadding(context)),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (context, i) {
          final item = items[i];
          return AppCard(
            padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.lg, Gap.sm, Gap.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(
                _icons[item.icon] ?? Icons.receipt_long_rounded,
                color: AppColors.primary,
                background: AppColors.primarySoft,
                size: 44,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Gap.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                    child: Text(item.code, style: numberStyle(18, color: AppColors.inkMuted, weight: FontWeight.w600)),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(item.meaning, style: theme.textTheme.bodyMedium),
                ]),
              ),
              PlayButton(id: 'glossary_${item.code}', text: '${item.title}. ${item.meaning}'),
            ]),
          );
        },
      ),
    );
  }
}
