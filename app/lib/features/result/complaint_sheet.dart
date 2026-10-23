import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// S7: pre-filled complaint text with Copy, Share and Call 118 (FR-14).
Future<void> showComplaintSheet(BuildContext context, String text) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RepositoryProvider.value(
        value: context.read<AppStrings>(),
        child: _ComplaintSheet(text),
      ),
    );

class _ComplaintSheet extends StatefulWidget {
  const _ComplaintSheet(this.initialText);

  final String initialText;

  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  late final _text = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final message = context.read<AppStrings>().t('copied');
    await Clipboard.setData(ClipboardData(text: _text.text));
    HapticFeedback.lightImpact();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('complaint_title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.xs),
          Text(s.t('complaint_hint'), style: theme.textTheme.bodySmall),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 10,
            maxLength: 1000,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: Gap.md),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(s.t('copy')),
                onPressed: _copy,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(s.t('share')),
                onPressed: () => SharePlus.instance.share(ShareParams(text: _text.text)),
              ),
            ),
          ]),
          const SizedBox(height: Gap.sm),
          PrimaryButton(
            label: s.t('call'),
            icon: Icons.call_outlined,
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: AppConstants.helplineNumber)),
          ),
          const SizedBox(height: Gap.lg),
          NoteRow(icon: Icons.gavel_rounded, text: s.t('complaint_escalate')),
        ]),
      ),
    );
  }
}
