import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_repository.dart';

/// S3: choose which meter the bill is for, or add one (FR-02).
/// Returns the connection ID, or null if dismissed.
/// [actionIcon] shows what happens after picking (camera or web lookup).
Future<String?> showPickConnectionSheet(BuildContext context, {IconData actionIcon = Icons.photo_camera_rounded}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: context.read<BillRepository>()),
          RepositoryProvider.value(value: context.read<AppStrings>()),
        ],
        child: _PickConnectionSheet(actionIcon: actionIcon),
      ),
    );

class _PickConnectionSheet extends StatefulWidget {
  const _PickConnectionSheet({required this.actionIcon});

  final IconData actionIcon;

  @override
  State<_PickConnectionSheet> createState() => _PickConnectionSheetState();
}

class _PickConnectionSheetState extends State<_PickConnectionSheet> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(String nickname) async {
    if (_busy || BillRepository.cleanNickname(nickname).isEmpty) return;
    setState(() => _busy = true);
    final c = await context.read<BillRepository>().addConnection(nickname);
    if (mounted) Navigator.pop(context, c.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final connections = context.read<BillRepository>().connections();
    final used = connections.map((c) => c.nickname).toSet();
    final presets = AppConstants.connectionPresets.map(s.t).where((p) => !used.contains(p));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (connections.isNotEmpty) ...[
            Text(s.t('pick_title'), style: theme.textTheme.titleLarge),
            const SizedBox(height: Gap.lg),
            for (final c in connections)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(Gap.md),
                  onTap: () => Navigator.pop(context, c.id),
                  child: Row(children: [
                    const IconBadge(Icons.home_rounded, color: AppColors.primary, background: AppColors.primarySoft),
                    const SizedBox(width: Gap.md),
                    Expanded(child: Text(c.nickname, style: theme.textTheme.titleMedium)),
                    Icon(widget.actionIcon, color: AppColors.primary),
                  ]),
                ),
              ),
            const SizedBox(height: Gap.md),
          ],
          Text(s.t('add_meter'), style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final p in presets)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, color: AppColors.primary),
                  label: Text(p),
                  onPressed: () => _create(p),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _name,
                maxLength: AppConstants.nicknameMaxLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(hintText: s.t('nickname_hint'), counterText: ''),
                onSubmitted: _create,
              ),
            ),
            const SizedBox(width: Gap.sm),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 58)),
              onPressed: () => _create(_name.text),
              child: Text(s.t('add')),
            ),
          ]),
        ]),
      ),
    );
  }
}
