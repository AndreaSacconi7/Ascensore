import 'dart:convert';
import 'dart:io';

import 'package:ascensore_client/app_screen_state.dart';
import 'package:ascensore_client/state/app_controller.dart';
import 'package:ascensore_client/message/server_message.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Contract test against the real server: fixtures/real_match.jsonl holds every message the server sent
/// to two scripted players during a full match (max hand size 3), including Bob dropping and reconnecting
/// in the second set. Regenerate it when the protocol changes.
void main() {
  final messages = File('test/fixtures/real_match.jsonl')
      .readAsLinesSync()
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();

  test('every message the server sent decodes', () {
    for (final m in messages) {
      final raw = jsonEncode({'messageType': m['messageType'], 'executable': m['executable']});
      expect(decodeServerMessage(raw), isNotNull, reason: raw);
    }
  });

  for (final player in ['alice', 'bob']) {
    test('$player\'s client follows the whole match to the same final scores', () {
      fakeAsync((async) {
        final connector = FakeConnector();
        // No heartbeat: the recorded server never answers pings
        final manager = AppController(
          auth: FakeAuthService(token: 'token'),
          connector: connector.call,
          heartbeatInterval: const Duration(days: 1),
        );
        manager.session.checkLoginStatus();
        async.flushMicrotasks();

        final received = messages.where((m) => m['to'] == player).toList();
        for (final m in received) {
          if (m['messageType'] == 'JOIN_GAME_RESPONSE') manager.match.joinGame();
          connector.last.receive(m['messageType'] as String, m['executable'] as Map<String, dynamic>? ?? {});
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 10));
        }
        // Let every trick and set pause run out
        async.elapse(const Duration(minutes: 2));

        final result = received.lastWhere((m) => m['messageType'] == 'END_GAME')['executable']['gameResult'] as Map;
        expect(manager.screen, AppScreenState.gameOver);
        result.forEach((nickname, score) {
          expect(manager.match.game!.playerNamed(nickname as String)!.score, score, reason: nickname);
        });
        expect(manager.match.me!.handCards, isEmpty);
      });
    });
  }
}
