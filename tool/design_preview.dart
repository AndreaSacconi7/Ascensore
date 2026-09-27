// Design preview: the real app driven by scripted server messages, no server or Supabase account needed.
//
//   flutter build web -t tool/design_preview.dart -o /tmp/preview
//   open <served preview>/?s=play
//
// Scenarios: login, nickname, menu, waiting, bet, bet10, play, left, trick, peak, setresult, gameover, offline, replaced, reconnecting.
import 'dart:async';

import 'package:ascensore_client/app.dart';
import 'package:ascensore_client/state/app_controller.dart';
import 'package:ascensore_client/state/app_providers.dart';
import 'package:flutter/material.dart';

import '../test/support/fakes.dart';

Map<String, dynamic> card(String seed, int value) => {'seed': seed, 'value': value};

Future<void> main() async {
  final scenario = Uri.base.queryParameters['s'] ?? 'play';
  final connector = FakeConnector();
  final auth = FakeAuthService(token: scenario == 'login' ? null : 'preview-token');
  // Pauses never end, so trick and set results stay on screen
  final app = AppController(auth: auth, connector: connector.call, resultDisplayTime: const Duration(hours: 1));
  final match = app.match;
  runApp(AppProviders(app: app, child: const AscensoreApp()));
  if (scenario == 'login') return;

  // The login page resumes the saved session, which opens the (fake) connection
  while (connector.connections.isEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  final server = connector.last;
  Future<void> send(String type, [Map<String, dynamic> executable = const {}]) async {
    server.receive(type, executable);
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  Future<void> login() =>
      send('PLAYER_INFO_RESPONSE', {'nickname': 'andrea', 'isLogged': true, 'needsNickname': false, 'inMatch': false});

  // Joins a match and jumps to a set through the reconnection message, which sets the state without pauses
  Future<void> start(List<String> players,
      {int setsPlayed = 0, int handSize = 1, Map<String, int> points = const {}}) async {
    await login();
    match.joinGame();
    await send('STARTING_GAME', {'connectedPlayers': players, 'maxHandSize': 10});
    await send('INFO_AFTER_RECONNECTION', {
      'set': handSize,
      'round': 0,
      'setsPlayed': setsPlayed,
      'maxHandSize': 10,
      'scores': points,
      'bets': <String, int>{},
      'roundsWon': <String, int>{},
      'playedCards': <String, dynamic>{},
    });
    for (final p in match.game!.players) {
      p.hasBet = false;
    }
  }

  switch (scenario) {
    case 'nickname':
      await send('PLAYER_INFO_RESPONSE',
          {'nickname': '', 'isLogged': false, 'needsNickname': true, 'error': 'NICKNAME_MISSING'});
    case 'menu':
      await login();
    case 'waiting':
      await login();
      match.joinGame(players: 4);
      await send('JOIN_GAME_RESPONSE', {'nickname': 'andrea', 'isJoined': true, 'playersPerMatch': 4});
      await send('WAITING_ROOM_UPDATE', {
        'playersPerMatch': 4,
        'players': ['carol', 'andrea']
      });
    case 'bet':
      // Third set, going up: 3 cards each; Bob and Carol have bet, it is your turn and you bet last
      await start(['bob', 'carol', 'andrea'],
          setsPlayed: 2, handSize: 3, points: {'bob': 30, 'carol': -10, 'andrea': 20});
      await send('HAND_UPDATE', {
        'cards': [card('COINS', 1), card('CUPS', 9), card('SWORDS', 4)]
      });
      await send('BRISCOLA_UPDATE', {'briscolaCard': card('COINS', 7)});
      await send('SETTED_BET', {'nickname': 'bob', 'bet': 1});
      await send('SETTED_BET', {'nickname': 'carol', 'bet': 1});
      await send('PLAYER_STATE_UPDATE',
          {'nickname': 'andrea', 'playerState': 'BET', 'turnMillisLeft': 21000, 'turnMillis': 30000});
    case 'play':
      // Fifth set with four players: Carol and Dave have played, you must follow cups
      await start(['carol', 'dave', 'andrea', 'bob'],
          setsPlayed: 4, handSize: 5, points: {'carol': 40, 'dave': 20, 'andrea': 50, 'bob': -10});
      await send('HAND_UPDATE', {
        'cards': [card('CUPS', 3), card('COINS', 10), card('CUPS', 8), card('SWORDS', 1), card('STICKS', 5)],
      });
      await send('BRISCOLA_UPDATE', {'briscolaCard': card('SWORDS', 6)});
      for (final (p, bet) in [('carol', 2), ('dave', 1), ('andrea', 2), ('bob', 1)]) {
        await send('SETTED_BET', {'nickname': p, 'bet': bet});
      }
      await send('PLAYED_CARD', {'nickname': 'carol', 'playedCard': card('CUPS', 10)});
      await send('PLAYED_CARD', {'nickname': 'dave', 'playedCard': card('CUPS', 2)});
      // Eight seconds left of thirty: the countdown is in its red, final part
      await send('PLAYER_STATE_UPDATE',
          {'nickname': 'andrea', 'playerState': 'PUT', 'turnMillisLeft': 8000, 'turnMillis': 30000});
    case 'trick':
      // Two players: the trick is complete and stays on the table, highlighting the winner
      await start(['bob', 'andrea'], setsPlayed: 3, handSize: 4, points: {'bob': 20, 'andrea': 30});
      await send('HAND_UPDATE', {
        'cards': [card('COINS', 2), card('CUPS', 5), card('STICKS', 7), card('SWORDS', 9)]
      });
      await send('BRISCOLA_UPDATE', {'briscolaCard': card('STICKS', 4)});
      await send('SETTED_BET', {'nickname': 'bob', 'bet': 2});
      await send('SETTED_BET', {'nickname': 'andrea', 'bet': 1});
      await send('PLAYED_CARD', {'nickname': 'bob', 'playedCard': card('COINS', 9)});
      await send('PLAYED_CARD', {'nickname': 'andrea', 'playedCard': card('COINS', 3)});
      await send('END_ROUND', {
        'nextRoundNumber': 1,
        'nextPlayerOrderAndTaken': {'andrea': 1, 'bob': 0}
      });
    case 'peak':
      // Tenth set: 10 cards each and no briscola until someone leads
      await start(['andrea', 'bob'], setsPlayed: 9, handSize: 10, points: {'bob': 110, 'andrea': 90});
      await send('HAND_UPDATE', {
        'cards': [
          card('COINS', 1),
          card('COINS', 8),
          card('CUPS', 3),
          card('CUPS', 6),
          card('CUPS', 10),
          card('SWORDS', 2),
          card('SWORDS', 9),
          card('STICKS', 1),
          card('STICKS', 4),
          card('STICKS', 7),
        ],
      });
      await send('BRISCOLA_UPDATE');
      await send('SETTED_BET', {'nickname': 'andrea', 'bet': 4});
      await send('SETTED_BET', {'nickname': 'bob', 'bet': 5});
      await send('PLAYER_STATE_UPDATE', {'nickname': 'andrea', 'playerState': 'PUT'});
    case 'bet10':
      // Betting with a full hand of 10: eleven options, the hand still visible
      await start(['bob', 'andrea'], setsPlayed: 9, handSize: 10, points: {'bob': 110, 'andrea': 90});
      await send('HAND_UPDATE', {
        'cards': [
          card('COINS', 1),
          card('COINS', 8),
          card('CUPS', 3),
          card('CUPS', 6),
          card('CUPS', 10),
          card('SWORDS', 2),
          card('SWORDS', 9),
          card('STICKS', 1),
          card('STICKS', 4),
          card('STICKS', 7),
        ],
      });
      await send('BRISCOLA_UPDATE');
      await send('SETTED_BET', {'nickname': 'bob', 'bet': 4});
      await send('PLAYER_STATE_UPDATE', {'nickname': 'andrea', 'playerState': 'BET'});
    case 'left':
      // Four players, Dave has left: the match goes on with three
      await start(['carol', 'dave', 'andrea', 'bob'],
          setsPlayed: 4, handSize: 5, points: {'carol': 40, 'dave': 20, 'andrea': 50, 'bob': -10});
      await send('HAND_UPDATE', {
        'cards': [card('CUPS', 3), card('COINS', 10), card('CUPS', 8), card('SWORDS', 1), card('STICKS', 5)],
      });
      await send('BRISCOLA_UPDATE', {'briscolaCard': card('SWORDS', 6)});
      for (final (p, bet) in [('carol', 2), ('dave', 1), ('andrea', 2), ('bob', 1)]) {
        await send('SETTED_BET', {'nickname': p, 'bet': bet});
      }
      await send('PLAYED_CARD', {'nickname': 'carol', 'playedCard': card('CUPS', 10)});
      await send('PLAYER_EXIT_GAME', {'nickname': 'dave'});
      await send('PLAYER_STATE_UPDATE', {'nickname': 'andrea', 'playerState': 'PUT'});
    case 'setresult':
      await start(['bob', 'andrea'], setsPlayed: 5, handSize: 6);
      await send('SETTED_BET', {'nickname': 'andrea', 'bet': 2});
      await send('END_SET', {
        'nextSetNumber': 7,
        'setsPlayed': 6,
        'nextPlayerOrderAndScore': {'andrea': 30, 'bob': -20}
      });
    case 'gameover':
      await start(['bob', 'andrea', 'carol']);
      await send('END_GAME', {
        'gameResult': {'andrea': 180, 'carol': 150, 'bob': 90}
      });
    case 'offline':
      // A real offline match: the local engine and three bots play, the human is on turn in a moment
      await login();
      match.playOffline(bots: 3);
    case 'replaced':
      await start(['bob', 'andrea'], setsPlayed: 2, handSize: 3);
      await send('SESSION_REPLACED');
    case 'reconnecting':
      await start(['bob', 'andrea'], setsPlayed: 2, handSize: 3);
      await send('HAND_UPDATE', {
        'cards': [card('COINS', 1), card('CUPS', 9), card('SWORDS', 4)]
      });
      await send('BRISCOLA_UPDATE', {'briscolaCard': card('COINS', 7)});
      connector.serverDown = true;
      server.drop();
  }
}
