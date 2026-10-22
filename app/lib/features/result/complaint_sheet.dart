import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';

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
          const SizedBox(height: Gap.lg),
          Row(children: [
            Expanded(child: _ActionTile(icon: Icons.copy_rounded, label: s.t('copy'), onTap: _copy)),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: _ActionTile(
                icon: Icons.share_rounded,
                label: s.t('share'),
                onTap: () => SharePlus.instance.share(ShareParams(text: _text.text)),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: _ActionTile(
                icon: Icons.call_rounded,
                label: s.t('call'),
                color: AppColors.green,
                background: AppColors.greenSoft,
                onTap: () => launchUrl(Uri(scheme: 'tel', path: AppConstants.helplineNumber)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
    this.background = AppColors.primarySoft,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.lg, horizontal: Gap.xs),
          child: Column(children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: Gap.sm),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
          ]),
        ),
      ),
    );
  }
}
