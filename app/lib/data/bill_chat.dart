import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_gate.dart';
import 'firebase_ai_api_service.dart';

/// Thrown when the helper cannot answer. [setup] means AI is not set up for
/// this app (retrying will not help).
class BillChatException implements Exception {
  const BillChatException({this.setup = false});
  final bool setup;
}

/// A conversation about one bill.
abstract class BillChat {
  /// Streams the answer as it grows. Throws [BillChatException].
  Stream<String> ask(String question);

  /// Too many questions in this chat (protects the free AI quota).
  bool get atLimit;

  static const maxQuestionLength = 500;
  static const maxTurns = 20;
}

typedef BillChatFactory = BillChat Function(String systemPrompt);

/// Whether the helper is available in this build (needs Firebase).
class ChatAvailability {
  const ChatAvailability(this.create, {this.firebase});
  final BillChatFactory? create;
  final FirebaseGate? firebase;

  bool get enabled => create != null && (firebase?.mayWork ?? true);
}

/// Gemini through Firebase AI Logic (free Spark plan). Keeps the history in
/// memory only, so each question can fall back to another model.
class FirebaseBillChat implements BillChat {
  FirebaseBillChat(this._systemPrompt, this._firebase);

  final String _systemPrompt;
  final FirebaseGate _firebase;
  final List<Content> _history = [];
  int _turns = 0;

  @override
  bool get atLimit => _turns >= BillChat.maxTurns;

  @override
  Stream<String> ask(String question) async* {
    if (!await _firebase.ready) throw const BillChatException(setup: true);
    final q = question.trim();
    final text = q.length > BillChat.maxQuestionLength ? q.substring(0, BillChat.maxQuestionLength) : q;
    for (final name in FirebaseAiApiService.models) {
      var answer = '';
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: name,
          systemInstruction: Content.system(_systemPrompt),
          // Thinking tokens count toward the output limit: keep thinking low
          // and the limit roomy so answers are never cut off. The prompt
          // itself asks for short answers.
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 2048,
            thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
          ),
        );
        final stream = model
            .generateContentStream([..._history, Content.text(text)])
            .timeout(const Duration(seconds: 30));
        await for (final chunk in stream) {
          final part = chunk.text;
          if (part == null || part.isEmpty) continue;
          answer += part;
          yield answer;
        }
        if (answer.trim().isEmpty) continue;
        _history
          ..add(Content.text(text))
          ..add(Content.model([TextPart(answer)]));
        _turns++;
        return;
      } on ServerException catch (e) {
        if (FirebaseAiApiService.isSetupError(e.message)) throw const BillChatException(setup: true);
        if (answer.isNotEmpty) throw const BillChatException();
      } on QuotaExceeded {
        if (answer.isNotEmpty) throw const BillChatException();
      } on FirebaseAIException catch (e) {
        debugPrint('Chat setup error: ${e.runtimeType}');
        throw const BillChatException(setup: true);
      } catch (e) {
        debugPrint('Chat failed on $name: ${e.runtimeType}');
        if (answer.isNotEmpty) throw const BillChatException();
      }
    }
    throw const BillChatException();
  }
}
