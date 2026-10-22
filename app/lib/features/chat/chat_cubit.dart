import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/bill_chat.dart';

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.failed = false});

  final bool fromUser;
  final String text;

  /// The answer to this question failed; offer a retry.
  final bool failed;
}

class ChatState {
  const ChatState({this.messages = const [], this.busy = false, this.unavailable = false, this.atLimit = false});

  final List<ChatMessage> messages;

  /// An answer is being written.
  final bool busy;

  /// AI is not set up for this app.
  final bool unavailable;
  final bool atLimit;

  ChatState copyWith({List<ChatMessage>? messages, bool? busy, bool? unavailable, bool? atLimit}) => ChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        unavailable: unavailable ?? this.unavailable,
        atLimit: atLimit ?? this.atLimit,
      );
}

final _bold = RegExp(r'\*\*|__');
final _heading = RegExp(r'^#{1,6}\s+', multiLine: true);
final _bullet = RegExp(r'^\s*[-*]\s+', multiLine: true);

/// The model sometimes answers in markdown; show (and speak) plain text.
String plainAnswer(String text) =>
    text.replaceAll(_bold, '').replaceAll(_heading, '').replaceAll(_bullet, '• ').trim();

/// One conversation about one bill. Nothing is stored.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._chat) : super(const ChatState());

  final BillChat _chat;
  StreamSubscription<String>? _sub;

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.busy) return;
    if (_chat.atLimit) {
      emit(state.copyWith(atLimit: true));
      return;
    }
    final asked = [...state.messages.where((m) => !m.failed), ChatMessage(fromUser: true, text: q)];
    emit(state.copyWith(messages: asked, busy: true));

    final done = Completer<void>();
    _sub = _chat.ask(q).listen(
      (answer) {
        if (isClosed) return;
        emit(state.copyWith(messages: [...asked, ChatMessage(fromUser: false, text: plainAnswer(answer))]));
      },
      onError: (Object e) {
        if (!isClosed) {
          final setup = e is BillChatException && e.setup;
          emit(state.copyWith(
            messages: [...asked.take(asked.length - 1), ChatMessage(fromUser: true, text: q, failed: true)],
            busy: false,
            unavailable: setup,
          ));
        }
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!isClosed) emit(state.copyWith(busy: false, atLimit: _chat.atLimit));
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    return done.future;
  }

  /// Asks the failed question again.
  Future<void> retry() async {
    final failed = state.messages.lastWhere((m) => m.failed, orElse: () => const ChatMessage(fromUser: true, text: ''));
    if (failed.text.isEmpty) return;
    emit(state.copyWith(messages: state.messages.where((m) => !m.failed).toList()));
    await ask(failed.text);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
