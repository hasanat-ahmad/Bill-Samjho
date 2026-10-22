import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_chat.dart';
import '../../domain/format.dart';
import '../../services/tts_service.dart';
import 'chat_cubit.dart';

/// "Ask about your bill": a short conversation with the AI helper, grounded
/// in this bill's data.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.billMonth});

  final String billMonth;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsService>();
  }

  @override
  void dispose() {
    _tts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    context.read<ChatCubit>().ask(q);
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('chat_title'))),
      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (_, _) => _scrollToEnd(),
        builder: (context, state) {
          final cubit = context.read<ChatCubit>();
          final suggestions = [for (var i = 1; i <= 5; i++) s.t('chat_q$i')];
          final lastIsUser = state.messages.isNotEmpty && state.messages.last.fromUser;
          return Column(children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
                children: [
                  _Bubble(
                    fromUser: false,
                    text: s.t('chat_welcome', {'month': formatMonth(widget.billMonth, s)}),
                    playId: 'chat_welcome',
                  ),
                  if (state.messages.isEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                      for (final q in suggestions)
                        ActionChip(
                          avatar: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primary),
                          label: Text(q, style: theme.textTheme.labelMedium),
                          onPressed: state.busy ? null : () => _send(q),
                        ),
                    ]),
                  ],
                  for (final (i, m) in state.messages.indexed) ...[
                    const SizedBox(height: Gap.sm),
                    _Bubble(fromUser: m.fromUser, text: m.text, playId: m.fromUser ? null : 'chat_$i'),
                    if (m.failed)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.xs),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                          const SizedBox(width: Gap.xs),
                          Expanded(
                            child: Text(
                              s.t(state.unavailable ? 'chat_unavailable' : 'chat_error'),
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.redInk),
                            ),
                          ),
                          if (!state.unavailable)
                            TextButton.icon(
                              onPressed: cubit.retry,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(s.t('retry')),
                            ),
                        ]),
                      ),
                  ],
                  if (state.busy && lastIsUser) ...[
                    const SizedBox(height: Gap.sm),
                    const _Typing(),
                  ],
                  if (state.atLimit) ...[
                    const SizedBox(height: Gap.md),
                    Text(s.t('chat_limit'), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: Gap.lg),
                  Text(
                    '${s.t('chat_disclaimer')} ${s.t('chat_privacy')}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !state.unavailable && !state.atLimit,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: BillChat.maxQuestionLength,
                      textInputAction: TextInputAction.send,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(hintText: s.t('chat_hint'), counterText: ''),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  IconButton.filled(
                    tooltip: s.t('chat_send'),
                    onPressed: state.busy || state.unavailable || state.atLimit ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromUser, required this.text, this.playId});

  final bool fromUser;
  final String text;
  final String? playId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm + 2),
      decoration: BoxDecoration(
        color: fromUser ? AppColors.primary : AppColors.surfaceAlt,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(Radii.md),
          topEnd: const Radius.circular(Radii.md),
          bottomStart: Radius.circular(fromUser ? Radii.md : 4),
          bottomEnd: Radius.circular(fromUser ? 4 : Radii.md),
        ),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(color: fromUser ? Colors.white : AppColors.ink),
      ),
    );
    return Row(
      mainAxisAlignment: fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: bubble),
        if (playId != null) PlayButton(id: playId!, text: text),
      ],
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
          child: const SizedBox(width: 36, height: 12, child: LinearProgressIndicator(minHeight: 4)),
        ),
      );
}

/// Shown when the helper cannot be used in this build.
class ChatUnavailableScreen extends StatelessWidget {
  const ChatUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.s.t('chat_title'))),
        body: MessageView(icon: Icons.cloud_off_rounded, tone: Tone.check, title: context.s.t('chat_unavailable')),
      );
}
