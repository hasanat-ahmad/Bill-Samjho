import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

/// S7: pre-filled complaint text with Copy, Share and Call 118 (FR-14).
Future<void> showComplaintSheet(BuildContext context, String text) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ComplaintSheet(text),
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
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Labels.copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(Labels.complaintTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 10,
            style: const TextStyle(fontSize: 18, height: 1.6),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(icon: const Icon(Icons.copy), label: const Text(Labels.copy), onPressed: _copy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.share),
                label: const Text(Labels.share),
                onPressed: () => SharePlus.instance.share(ShareParams(text: _text.text)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green, minimumSize: const Size.fromHeight(60)),
            icon: const Icon(Icons.call, size: 28),
            label: const Text(Labels.call118),
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: AppConstants.helplineNumber)),
          ),
        ]),
      ),
    );
  }
}
