import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../message/executable_in_client.dart';
import '../message/server_message.dart';

/// Applies server messages one at a time, in arrival order.
///
/// After a trick or a set the match pauses the inbox for [pauseTime] so players can see the cards before
/// the table is cleared; messages that arrive meanwhile wait their turn instead of being applied out of
/// order.
class MessageInbox {
  MessageInbox({required this.pauseTime, required this.apply});

  /// How long a pause lasts.
  final Duration pauseTime;

  /// Applies one message to the client state.
  final void Function(ExecutableInClient message) apply;

  final Queue<ExecutableInClient> _queue = Queue();
  Timer? _pause;

  bool get isPaused => _pause != null;

  /// Decodes a message (as JSON text) and applies it, or queues it behind a pause.
  void add(String raw) {
    final ExecutableInClient? message;
    try {
      message = decodeServerMessage(raw);
    } catch (e) {
      debugPrint('Unreadable server message: $e');
      return;
    }
    if (message == null) {
      debugPrint('Unknown server message: $raw');
      return;
    }
    _queue.add(message);
    _drain();
  }

  /// Holds the queue for [pauseTime], then runs [onResume] and applies what arrived meanwhile.
  void pause(VoidCallback onResume) {
    _pause = Timer(pauseTime, () {
      _pause = null;
      onResume();
      _drain();
    });
  }

  /// Drops queued messages and any pause in progress.
  void clear() {
    _pause?.cancel();
    _pause = null;
    _queue.clear();
  }

  void _drain() {
    while (!isPaused && _queue.isNotEmpty) {
      final message = _queue.removeFirst();
      try {
        apply(message);
      } catch (e, stack) {
        debugPrint('Failed to apply ${message.runtimeType}: $e\n$stack');
      }
    }
  }
}
