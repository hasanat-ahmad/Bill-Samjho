import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../data/bill_repository.dart';

/// S3: choose which meter the bill is for, or add one (FR-02).
/// Returns the connection ID, or null if dismissed.
Future<String?> showPickConnectionSheet(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => RepositoryProvider.value(
        value: context.read<BillRepository>(),
        child: const _PickConnectionSheet(),
      ),
    );

class _PickConnectionSheet extends StatefulWidget {
  const _PickConnectionSheet();

  @override
  State<_PickConnectionSheet> createState() => _PickConnectionSheetState();
}

class _PickConnectionSheetState extends State<_PickConnectionSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(String nickname) async {
    if (nickname.trim().isEmpty) return;
    final c = await context.read<BillRepository>().addConnection(nickname);
    if (mounted) Navigator.pop(context, c.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connections = context.read<BillRepository>().connections();
    final used = connections.map((c) => c.nickname).toSet();
    final presets = AppConstants.connectionPresets.where((p) => !used.contains(p));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (connections.isNotEmpty) ...[
            Text(Labels.pickConnection, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            for (final c in connections)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                  icon: const Icon(Icons.home, size: 28),
                  label: Text(c.nickname, style: const TextStyle(fontSize: 22)),
                  onPressed: () => Navigator.pop(context, c.id),
                ),
              ),
            const Divider(height: 32),
          ],
          Text(Labels.newConnection, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in presets)
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(p),
                  onPressed: () => _create(p),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _name,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(hintText: Labels.nicknameHint),
                textInputAction: TextInputAction.done,
                onSubmitted: _create,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: () => _create(_name.text), child: const Text(Labels.add)),
          ]),
        ]),
      ),
    );
  }
}
