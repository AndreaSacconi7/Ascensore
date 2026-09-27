import 'package:ascensore_client/app_screen_state.dart';
import 'package:ascensore_client/authentication_state.dart';
import 'package:ascensore_client/message/player_info_response.dart';
import 'package:ascensore_client/model/card_game.dart';
import 'package:ascensore_client/model/player_state.dart';
import 'package:ascensore_client/model/seed.dart';
import 'package:ascensore_client/model/set_result_animation_state.dart';
import 'package:ascensore_client/network/server_link.dart';
import 'package:ascensore_client/state/app_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const displayTime = Duration(seconds: 3);

Map<String, dynamic> card(String seed, int value) => {'seed': seed, 'value': value};

void main() {
  late FakeAuthService auth;
  late FakeConnector connector;
  late AppController app;

  // Everything runs in fake time so result pauses and reconnection backoff are deterministic
  void run(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      auth = FakeAuthService(token: 'token');
      connector = FakeConnector();
      app = AppController(
        auth: auth,
        connector: connector.call,
        resultDisplayTime: displayTime,
        reconnectBackoff: const [Duration(seconds: 1)],
      );
      body(async);
    });
  }

  void server(FakeAsync async, String type, [Map<String, dynamic> executable = const {}]) {
    connector.last.receive(type, executable);
    async.flushMicrotasks();
  }

  void loggedIn(FakeAsync async, String nickname, {bool inMatch = false}) {
    server(async, 'PLAYER_INFO_RESPONSE',
        {'nickname': nickname, 'isLogged': true, 'needsNickname': false, 'inMatch': inMatch});
  }

  // Alice (this client) and Bob in a started match, Alice betting first
  void startMatch(FakeAsync async) {
    app.session.checkLoginStatus();
    async.flushMicrotasks();
    loggedIn(async, 'alice');
    app.match.joinGame();
    server(async, 'STARTING_GAME', {
      'connectedPlayers': ['alice', 'bob']
    });
    server(async, 'HAND_UPDATE', {
      'cards': [card('CUPS', 1), card('SWORDS', 5)]
    });
    server(async, 'BRISCOLA_UPDATE', {'briscolaCard': card('COINS', 7)});
  }

  group('login', () {
    test(
        'a saved session connects and identifies the player',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();

              expect(connector.last.sent.single['commandType'], 'PLAYER_INFO_REQUEST');
              expect(connector.last.sent.single['executable']['token'], 'token');
              loggedIn(async, 'alice');
              expect(app.screen, AppScreenState.mainMenu);
              expect(app.session.nickname, 'alice');
            }));

    test(
        'a new account chooses a nickname until the server accepts one',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();
              server(async, 'PLAYER_INFO_RESPONSE',
                  {'nickname': '', 'isLogged': false, 'needsNickname': true, 'error': 'NICKNAME_MISSING'});
              expect(app.screen, AppScreenState.chooseNickname);
              expect(app.session.nicknameError, isNull);

              app.session.submitNickname('alice');
              async.flushMicrotasks();
              expect(connector.last.sent.last['executable']['nickname'], 'alice');
              server(async, 'PLAYER_INFO_RESPONSE',
                  {'nickname': '', 'isLogged': false, 'needsNickname': true, 'error': 'NICKNAME_TAKEN'});
              expect(app.session.nicknameError, PlayerInfoResponse.nicknameTaken);

              app.session.submitNickname('alice_2');
              async.flushMicrotasks();
              loggedIn(async, 'alice_2');
              expect(app.screen, AppScreenState.mainMenu);
              expect(app.session.nicknameError, isNull);
            }));

    test(
        'a refused token signs the player out',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();
              server(async, 'PLAYER_INFO_RESPONSE', {'nickname': '', 'isLogged': false, 'error': 'INVALID_TOKEN'});
              async.flushMicrotasks();

              expect(auth.signedOut, isTrue);
              expect(app.screen, AppScreenState.login);
              expect(app.session.authState, AuthenticationState.unauthenticated);
              expect(app.session.authError, isNotNull);
            }));
  });

  group('match', () {
    test(
        'commands carry no player name: the server knows who is on the socket',
        () => run((async) {
              startMatch(async);
              app.match.setBet(1);
              app.match.putCard(const CardGame(Seed.CUPS, 1));

              expect(connector.last.sent[connector.last.sent.length - 2], {
                'commandType': 'SET_BET',
                'executable': {'bet': 1},
              });
              expect(connector.last.sent.last, {
                'commandType': 'PUT_CARD',
                'executable': {'seed': 'CUPS', 'value': 1},
              });
            }));

    test(
        'playing a card replaces the hand instead of mutating it',
        () => run((async) {
              startMatch(async);
              final before = app.match.me!.handCards;

              server(async, 'PLAYED_CARD', {'nickname': 'alice', 'playedCard': card('CUPS', 1)});

              expect(identical(before, app.match.me!.handCards), isFalse);
              expect(app.match.me!.handCards, [const CardGame(Seed.SWORDS, 5)]);
            }));

    test(
        'the finished trick stays on the table and later messages wait their turn',
        () => run((async) {
              startMatch(async);
              server(async, 'PLAYED_CARD', {'nickname': 'alice', 'playedCard': card('CUPS', 1)});
              server(async, 'PLAYED_CARD', {'nickname': 'bob', 'playedCard': card('CUPS', 2)});
              server(async, 'END_ROUND', {
                'nextRoundNumber': 1,
                'nextPlayerOrderAndTaken': {'alice': 1, 'bob': 0}
              });
              server(async, 'PLAYER_STATE_UPDATE', {'nickname': 'alice', 'playerState': 'PUT'});

              final alice = app.match.game!.playerNamed('alice')!;
              expect(alice.roundsWon, 1);
              expect(alice.playedCard, isNotNull, reason: 'trick still shown');
              expect(alice.playerState, isNot(PlayerState.PUT), reason: 'queued behind the pause');

              async.elapse(displayTime);
              expect(alice.playedCard, isNull);
              expect(alice.playerState, PlayerState.PUT);
              expect(app.match.game!.round, 1);
              expect(app.match.game!.set, 1, reason: 'a trick does not change the hand size');
            }));

    test(
        'end of set shows the result, then clears bets for the next deal',
        () => run((async) {
              startMatch(async);
              server(async, 'SETTED_BET', {'nickname': 'alice', 'bet': 1});
              server(async, 'END_SET', {
                'nextSetNumber': 2,
                'nextPlayerOrderAndScore': {'bob': -10, 'alice': 20}
              });

              expect(app.match.lastSetResult, SetResultAnimationState.win);
              expect(app.match.game!.playerOrder.map((p) => p.nickname), ['bob', 'alice']);
              expect(app.match.game!.set, 2);

              async.elapse(displayTime);
              expect(app.match.lastSetResult, SetResultAnimationState.none);
              expect(app.match.game!.playerNamed('alice')!.bet, 0);
              expect(app.match.game!.playerNamed('alice')!.score, 20);
            }));

    test(
        'the match knows where it is in the 1..10..1 sequence',
        () => run((async) {
              startMatch(async);
              expect(app.match.game!.maxHandSize, 10);
              expect(app.match.game!.setNumber, 1);
              expect(app.match.game!.totalSets, 19);

              server(async, 'END_SET', {
                'nextSetNumber': 9,
                'setsPlayed': 10,
                'nextPlayerOrderAndScore': {'alice': 0, 'bob': 0}
              });
              expect(app.match.game!.set, 9);
              expect(app.match.game!.setNumber, 11);
              expect(app.match.game!.goingUp, isFalse);
            }));

    test(
        'the winner of a complete trick is highlighted until the table is cleared',
        () => run((async) {
              startMatch(async);
              server(async, 'PLAYED_CARD', {'nickname': 'alice', 'playedCard': card('CUPS', 1)});
              expect(app.match.game!.trickWinner, isNull, reason: 'trick not complete yet');
              server(async, 'PLAYED_CARD', {'nickname': 'bob', 'playedCard': card('COINS', 2)});
              expect(app.match.game!.trickWinner, 'bob',
                  reason: 'coins is briscola (coins 7), so any coin beats the ace of cups');
              server(async, 'END_ROUND', {
                'nextRoundNumber': 1,
                'nextPlayerOrderAndTaken': {'bob': 1, 'alice': 0}
              });

              async.elapse(displayTime);
              expect(app.match.game!.trickWinner, isNull);
            }));

    test(
        'joining asks for the chosen match size and shows the waiting room',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();
              loggedIn(async, 'alice');

              app.match.joinGame(players: 3);
              expect(connector.last.sent.last, {
                'commandType': 'JOIN_GAME_REQUEST',
                'executable': {'players': 3},
              });
              expect(app.match.waitingRoom!.missing, 2);

              server(async, 'WAITING_ROOM_UPDATE', {
                'playersPerMatch': 3,
                'players': ['bob', 'alice']
              });
              expect(app.match.waitingRoom!.players, ['bob', 'alice']);
              expect(app.match.waitingRoom!.missing, 1);

              server(async, 'STARTING_GAME', {
                'connectedPlayers': ['bob', 'alice', 'carol'],
                'maxHandSize': 10
              });
              expect(app.match.waitingRoom, isNull);
              expect(app.match.game!.players, hasLength(3));
            }));

    test(
        'leaving the queue tells the server and goes back to the menu',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();
              loggedIn(async, 'alice');
              app.match.joinGame(players: 4);

              app.match.leaveGame();

              expect(connector.last.sentTypes.last, 'LEAVE_GAME_REQUEST');
              expect(app.screen, AppScreenState.mainMenu);
              expect(app.match.waitingRoom, isNull);
              expect(app.match.matchSize, 4, reason: 'remembered for the next match');
            }));

    test(
        'logging out during a pause cancels it',
        () => run((async) {
              startMatch(async);
              server(async, 'END_ROUND', {
                'nextRoundNumber': 1,
                'nextPlayerOrderAndTaken': {'alice': 1, 'bob': 0}
              });

              app.session.logOut();
              async.flushMicrotasks();
              async.elapse(displayTime * 2);

              expect(app.match.game, isNull);
              expect(app.screen, AppScreenState.login);
              expect(connector.connections, hasLength(1), reason: 'no reconnection after logout');
            }));

    test(
        'a server rejection is shown to the player',
        () => run((async) {
              startMatch(async);
              server(async, 'TEXT_MESSAGE', {'text': 'It is not your turn to play'});

              expect(app.match.consumeNotice(), 'It is not your turn to play');
              expect(app.match.consumeNotice(), isNull);
            }));
  });

  group('leaving', () {
    test(
        'leaving a match tells the server and goes back to the menu',
        () => run((async) {
              startMatch(async);

              app.match.leaveGame();

              expect(connector.last.sentTypes.last, 'LEAVE_GAME_REQUEST');
              expect(app.screen, AppScreenState.mainMenu);
              expect(app.match.game, isNull);
              expect(app.match.consumeNotice(), isNotNull);
            }));

    test(
        'an opponent leaving is taken off the table and out of the turn order',
        () => run((async) {
              startMatch(async);
              server(async, 'PLAYED_CARD', {'nickname': 'bob', 'playedCard': card('CUPS', 4)});

              server(async, 'PLAYER_EXIT_GAME', {'nickname': 'bob'});

              final bob = app.match.game!.playerNamed('bob')!;
              expect(bob.playerState, PlayerState.EXIT);
              expect(bob.playedCard, isNull);
              expect(app.match.game!.playerOrder.map((p) => p.nickname), ['alice']);
              expect(app.match.consumeNotice(), contains('bob'));
            }));
  });

  group('turns and sessions', () {
    test(
        'a turn with a time limit gets a deadline',
        () => run((async) {
              startMatch(async);
              server(async, 'PLAYER_STATE_UPDATE',
                  {'nickname': 'alice', 'playerState': 'BET', 'turnMillisLeft': 30000, 'turnMillis': 30000});

              final alice = app.match.game!.playerNamed('alice')!;
              expect(alice.turnDeadline, isNotNull);
              expect(alice.turnLength, const Duration(seconds: 30));

              server(async, 'PLAYER_STATE_UPDATE', {'nickname': 'alice', 'playerState': 'WAIT'});
              expect(alice.turnDeadline, isNull);
            }));

    test(
        'being taken out of the match for inactivity returns to the menu',
        () => run((async) {
              startMatch(async);
              server(async, 'PLAYER_EXIT_GAME', {'nickname': 'alice'});

              expect(app.screen, AppScreenState.mainMenu);
              expect(app.match.game, isNull);
              expect(app.match.consumeNotice(), isNotNull);
            }));

    test(
        'a session replaced by another device stays closed until the player plays here',
        () => run((async) {
              startMatch(async);
              server(async, 'SESSION_REPLACED');
              connector.last.drop();
              async.flushMicrotasks();

              expect(app.screen, AppScreenState.sessionReplaced);
              async.elapse(const Duration(seconds: 30));
              expect(connector.connections, hasLength(1), reason: 'no automatic reconnection');

              app.session.playHere();
              async.flushMicrotasks();
              expect(connector.connections, hasLength(2));
              expect(connector.last.sentTypes, ['PLAYER_INFO_REQUEST']);
            }));

    test(
        'the heartbeat pings the server while connected',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();
              loggedIn(async, 'alice');

              async.elapse(const Duration(seconds: 10));
              expect(connector.last.sentTypes.last, 'PING');
            }));

    test(
        'a server that stops answering is treated as a dropped connection',
        () => run((async) {
              app.session.checkLoginStatus();
              async.flushMicrotasks();
              loggedIn(async, 'alice');

              // Pings go unanswered: after two silent intervals the link reconnects
              async.elapse(const Duration(seconds: 31));

              expect(connector.connections.length, greaterThan(1));
            }));
  });

  group('state split', () {
    test(
        'updates at the table do not wake up what only watches the session',
        () => run((async) {
              startMatch(async);
              var sessionChanges = 0;
              var screenChanges = 0;
              app.session.addListener(() => sessionChanges++);
              app.addListener(() => screenChanges++);

              server(async, 'SETTED_BET', {'nickname': 'alice', 'bet': 1});
              server(async, 'PLAYED_CARD', {'nickname': 'alice', 'playedCard': card('CUPS', 1)});

              expect(sessionChanges, 0);
              expect(screenChanges, 0, reason: 'still the same screen');
            }));

    test(
        'reconnecting on the final standing keeps it on screen',
        () => run((async) {
              startMatch(async);
              server(async, 'END_GAME', {
                'gameResult': {'alice': 20, 'bob': -10}
              });
              expect(app.screen, AppScreenState.gameOver);

              connector.last.drop();
              async.flushMicrotasks();
              async.elapse(const Duration(seconds: 1));
              loggedIn(async, 'alice');

              expect(app.screen, AppScreenState.gameOver);
              expect(app.match.game!.playerNamed('alice')!.score, 20);
            }));
  });

  group('connection loss', () {
    test(
        'a dropped connection reconnects and resumes the match',
        () => run((async) {
              startMatch(async);
              connector.last.drop();
              async.flushMicrotasks();

              expect(auth.signedOut, isFalse, reason: 'a network drop is not a logout');
              expect(app.session.linkState, LinkState.reconnecting);

              async.elapse(const Duration(seconds: 1));
              expect(connector.connections, hasLength(2));
              expect(connector.last.sentTypes, ['PLAYER_INFO_REQUEST']);

              loggedIn(async, 'alice', inMatch: true);
              expect(app.screen, AppScreenState.inGame);
              server(async, 'STARTING_GAME', {
                'connectedPlayers': ['bob', 'alice']
              });
              server(async, 'HAND_UPDATE', {
                'cards': [card('SWORDS', 5)]
              });
              server(async, 'INFO_AFTER_RECONNECTION', {
                'set': 4,
                'round': 1,
                'scores': {'alice': 30, 'bob': 10},
                'bets': {'alice': 2, 'bob': 1},
                'roundsWon': {'alice': 1, 'bob': 0},
                'playedCards': {'bob': card('CUPS', 9)},
              });
              server(async, 'PLAYER_STATE_UPDATE', {'nickname': 'alice', 'playerState': 'PUT'});

              final game = app.match.game!;
              expect(game.set, 4);
              expect(game.playerNamed('bob')!.playedCard, const CardGame(Seed.CUPS, 9));
              expect(game.playerNamed('alice')!.bet, 2);
              expect(app.match.me!.playerState, PlayerState.PUT);
              expect(app.session.linkState, LinkState.connected);
            }));

    test(
        'retries until the server is back',
        () => run((async) {
              startMatch(async);
              connector.serverDown = true;
              connector.last.drop();
              async.flushMicrotasks();

              async.elapse(const Duration(seconds: 5));
              expect(app.session.linkState, LinkState.reconnecting);

              connector.serverDown = false;
              async.elapse(const Duration(seconds: 1));
              expect(app.session.linkState, LinkState.connected);
            }));

    test(
        'messages queued behind a login response are not lost',
        () => run((async) {
              startMatch(async);
              // A pause is running when the reconnection replay arrives
              server(async, 'END_ROUND', {
                'nextRoundNumber': 1,
                'nextPlayerOrderAndTaken': {'alice': 1, 'bob': 0}
              });
              loggedIn(async, 'alice', inMatch: true);
              server(async, 'STARTING_GAME', {
                'connectedPlayers': ['alice', 'bob']
              });
              server(async, 'INFO_AFTER_RECONNECTION', {
                'set': 2,
                'round': 0,
                'scores': {'alice': 20}
              });

              async.elapse(displayTime);
              expect(app.match.game, isNotNull);
              expect(app.match.game!.set, 2);
              expect(app.match.game!.playerNamed('alice')!.score, 20);
            }));

    test(
        'a match that ended while offline returns to the menu',
        () => run((async) {
              startMatch(async);
              connector.last.drop();
              async.flushMicrotasks();
              async.elapse(const Duration(seconds: 1));

              loggedIn(async, 'alice', inMatch: false);

              expect(app.screen, AppScreenState.mainMenu);
              expect(app.match.game, isNull);
              expect(app.match.consumeNotice(), isNotNull);
            }));
  });
}
