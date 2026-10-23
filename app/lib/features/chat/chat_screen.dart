import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/bill_chat.dart';
import '../../domain/format.dart';
import '../../services/dictation_service.dart';
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
  late final Dictation? _dictation;
  bool _listening = false;

  /// Microphone loudness 0..1 while listening, for the pulsing ring.
  final _level = ValueNotifier<double>(0);

  /// Text already typed when voice typing started; speech is added after it.
  String _typed = '';

  static final _pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide.none,
  );

  /// Counts listening sessions. The recognizer can deliver a late final
  /// result after the session ended (or after the question was sent); those
  /// carry an old number and are ignored, so the box stays clear.
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsService>();
    _dictation = context.read<Dictation?>();
  }

  @override
  void dispose() {
    _tts.stop();
    if (_listening) _dictation?.cancel();
    _level.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    if (_listening) _dictation?.cancel();
    _session++;
    _endListening();
    _input.clear();
    FocusScope.of(context).unfocus();
    context.read<ChatCubit>().ask(q);
  }

  Future<void> _toggleMic() async {
    final dictation = _dictation;
    if (dictation == null) return;
    if (_listening) return dictation.stop();
    // Don't let the phone hear its own voice.
    unawaited(_tts.stop());
    FocusScope.of(context).unfocus();
    _typed = _input.text.trim();
    _level.value = 0;
    final session = ++_session;
    bool current() => mounted && session == _session && _listening;
    setState(() => _listening = true);
    await dictation.start(
      language: context.read<AppStrings>().language,
      onText: (text, done) {
        if (!current()) return;
        var all = [_typed, text.trim()].where((x) => x.isNotEmpty).join(' ');
        if (all.length > BillChat.maxQuestionLength) all = all.substring(0, BillChat.maxQuestionLength);
        _input.value = TextEditingValue(text: all, selection: TextSelection.collapsed(offset: all.length));
        if (done) _endListening();
      },
      onError: (error) {
        if (!current()) return;
        _endListening();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.read<AppStrings>().t('dictate_${error.name}'))));
      },
      onEnd: () {
        if (current()) _endListening();
      },
      // Android reports roughly -2..10 dB.
      onLevel: (db) => _level.value = ((db + 2) / 12).clamp(0.0, 1.0),
    );
  }

  void _endListening() {
    if (mounted && _listening) setState(() => _listening = false);
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
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: Gap.xs),
                          label: Text(q, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryDark)),
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
                    [
                      s.t('chat_disclaimer'),
                      s.t('chat_privacy'),
                      if (_dictation != null) s.t('chat_voice_privacy'),
                    ].join(' '),
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
                      readOnly: _listening,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: BillChat.maxQuestionLength,
                      textInputAction: TextInputAction.send,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: s.t(_listening ? 'dictate_listening' : 'chat_hint'),
                        counterText: '',
                        fillColor: AppColors.canvas,
                        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
                        border: _pill,
                        enabledBorder: _pill,
                        disabledBorder: _pill,
                        focusedBorder: _pill.copyWith(borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  // WhatsApp-style: the mic until there is text to send.
                  ValueListenableBuilder(
                    valueListenable: _input,
                    builder: (context, value, _) {
                      final off = state.unavailable || state.atLimit;
                      if (_dictation != null && (_listening || value.text.trim().isEmpty)) {
                        return _MicButton(
                          listening: _listening,
                          level: _level,
                          tooltip: s.t(_listening ? 'dictate_stop' : 'dictate'),
                          onPressed: off ? null : _toggleMic,
                        );
                      }
                      return IconButton.filled(
                        tooltip: s.t('chat_send'),
                        onPressed: state.busy || off ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      );
                    },
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
        color: fromUser ? AppColors.primary : AppColors.surface,
        border: fromUser ? null : Border.all(color: AppColors.border),
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

/// Mic for voice typing; while listening it turns into a red stop button
/// with a ring that grows with the speaker's voice.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.level, required this.tooltip, required this.onPressed});

  final bool listening;
  final ValueListenable<double> level;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!listening) {
      return IconButton.filledTonal(tooltip: tooltip, onPressed: onPressed, icon: const Icon(Icons.mic_rounded));
    }
    return ValueListenableBuilder(
      valueListenable: level,
      builder: (context, v, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.25), spreadRadius: 2 + 8 * v)],
        ),
        child: child,
      ),
      child: IconButton.filled(
        tooltip: tooltip,
        style: IconButton.styleFrom(backgroundColor: AppColors.red),
        onPressed: onPressed,
        icon: const Icon(Icons.stop_rounded),
      ),
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
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
