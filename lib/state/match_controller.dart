import 'package:flutter/foundation.dart';

import '../command/command.dart';
import '../message/briscola_update.dart';
import '../message/end_game.dart';
import '../message/end_round_update.dart';
import '../message/end_set_update.dart';
import '../message/hand_update.dart';
import '../message/info_after_reconnection.dart';
import '../message/join_game_response.dart';
import '../message/played_card_update.dart';
import '../message/player_exit_game.dart';
import '../message/player_state_update.dart';
import '../message/setted_bet_update.dart';
import '../message/starting_game.dart';
import '../message/text_message.dart';
import '../message/waiting_room_update.dart';
import '../model/card_game.dart';
import '../model/game.dart';
import '../model/game_rules.dart';
import '../model/my_self_player.dart';
import '../model/player.dart';
import '../model/player_state.dart';
import '../model/set_result_animation_state.dart';
import '../model/waiting_room.dart';
import '../offline/local_match.dart';
import 'message_inbox.dart';

/// Where the player is with the match.
enum MatchPhase {
  /// No match: the menu (or the login page for a guest).
  none,

  /// In matchmaking, waiting for the match to fill up.
  waiting,

  /// At the table (or reconnecting to it).
  playing,

  /// The match ended: the final standing.
  over,
}

/// The match on screen: matchmaking, the table, the player's moves and what the server says about them.
///
/// Online matches talk to the server through [sendToServer]; offline matches to a [LocalMatch] on the
/// device, which answers with the same messages, so the handlers below serve both.
class MatchController extends ChangeNotifier {
  MatchController({
    required MessageInbox inbox,
    required void Function(String command) sendToServer,
    required String? Function() nickname,
  })  : _inbox = inbox,
        _sendToServer = sendToServer,
        _nickname = nickname;

  final MessageInbox _inbox;
  final void Function(String command) _sendToServer;

  // The player's public nickname, if signed in
  final String? Function() _nickname;

  MatchPhase phase = MatchPhase.none;

  /// This player at the table; null before the match starts.
  MySelfPlayer? me;
  Game? game;

  /// Who is waiting in your match before it starts; null outside matchmaking.
  WaitingRoom? waitingRoom;

  SetResultAnimationState lastSetResult = SetResultAnimationState.none;

  /// Points this player gained or lost in the set that just ended, shown with [lastSetResult].
  int lastSetDelta = 0;

  /// One-off message for the player (a rejected move, a player leaving); cleared when shown.
  String? notice;

  /// Match size the player picked last (2 to 4), also used by "play again".
  int matchSize = 2;

  /// Computer opponents chosen last for an offline match (1 to 3).
  int offlineBots = 1;

  static const botNames = ['Gino', 'Pina', 'Tonio', 'Rita'];

  // The offline match in progress, if any: commands go to it instead of the server
  LocalMatch? _offline;
  Set<String> _offlineBotNames = const {};
  bool _lastMatchOffline = false;

  bool get isOffline => _offline != null;

  // ------------------------------------------------------------------
  // Player actions
  // ------------------------------------------------------------------

  /// Enters matchmaking for a match of [players] (the last chosen size if omitted).
  void joinGame({int? players}) {
    _lastMatchOffline = false;
    matchSize = players ?? matchSize;
    final nickname = _nickname();
    waitingRoom = WaitingRoom(playersPerMatch: matchSize, players: [if (nickname != null) nickname]);
    phase = MatchPhase.waiting;
    notifyListeners();
    _send(Command.joinGame(matchSize).toJson());
  }

  /// Starts a match against [bots] computer opponents on this device: no server, and no account needed.
  void playOffline({int? bots}) {
    offlineBots = (bots ?? offlineBots).clamp(1, 3);
    _lastMatchOffline = true;
    reset();
    final human = _nickname() ?? 'Tu';
    final names = botNames.where((name) => name != human).take(offlineBots).toList();
    _offlineBotNames = names.toSet();
    late final LocalMatch match;
    match = LocalMatch(
      human: human,
      botNames: names,
      // Messages from a match that has since been closed are dropped
      onMessage: (json) {
        if (identical(_offline, match)) _inbox.add(json);
      },
    );
    _offline = match;
    phase = MatchPhase.playing;
    notifyListeners();
    match.start();
  }

  /// Another match like the one just finished: online with the same size, or offline with the same bots.
  void playAgain() {
    if (_lastMatchOffline) {
      playOffline();
    } else {
      backToMenu();
      joinGame();
    }
  }

  /// Leaves matchmaking, or the match in progress for good, and goes back to the menu.
  void leaveGame() {
    final leftMatch = game != null;
    _send(Command.leaveGame().toJson());
    backToMenu();
    if (leftMatch) {
      notice = 'Hai abbandonato la partita.';
      notifyListeners();
    }
  }

  /// State changes only when the server confirms with SETTED_BET.
  void setBet(int bet) => _send(Command.setBet(bet).toJson());

  /// The card leaves the hand only when the server confirms with PLAYED_CARD.
  void putCard(CardGame card) => _send(Command.putCard(card).toJson());

  void backToMenu() {
    reset();
    notifyListeners();
  }

  /// Returns the pending notice and clears it.
  String? consumeNotice() {
    final pending = notice;
    notice = null;
    return pending;
  }

  /// Forgets the match: stops an offline one, drops queued messages and any pause, clears the table.
  void reset() {
    _offline?.dispose();
    _offline = null;
    _inbox.clear();
    _clearTable();
    notice = null;
    waitingRoom = null;
    phase = MatchPhase.none;
  }

  // Game commands go to the offline match when one is in progress, otherwise to the server
  void _send(String command) {
    final offline = _offline;
    if (offline != null) {
      offline.receive(command);
    } else {
      _sendToServer(command);
    }
  }

  // Safe inside a message handler: never touches the inbox, which may hold the messages that follow
  void _clearTable() {
    game = null;
    me = null;
    lastSetResult = SetResultAnimationState.none;
  }

  // ------------------------------------------------------------------
  // Server messages (applied by the inbox, in order)
  // ------------------------------------------------------------------

  /// The server identified the player on a new connection: back to the match in progress, whose state
  /// follows, or out of it if it ended while the player was away.
  void handleLoggedIn({required bool inMatch}) {
    if (phase == MatchPhase.over && !inMatch) return;
    final wasPlaying = phase == MatchPhase.playing && game != null;
    _clearTable();
    waitingRoom = null;
    if (inMatch) {
      // STARTING_GAME and the table state follow
      phase = MatchPhase.playing;
    } else {
      if (wasPlaying) notice = 'La partita è terminata mentre eri disconnesso.';
      phase = MatchPhase.none;
    }
    notifyListeners();
  }

  void handleJoinGameResponse(JoinGameResponse response) {
    if (!response.isJoined) {
      notice = 'Impossibile entrare in partita, riprova.';
      waitingRoom = null;
      phase = MatchPhase.none;
    } else {
      matchSize = response.playersPerMatch;
    }
    notifyListeners();
  }

  void handleWaitingRoomUpdate(WaitingRoomUpdate update) {
    // Late updates after the match started (or after leaving) are ignored
    if (game != null || phase != MatchPhase.waiting) return;
    waitingRoom = WaitingRoom(playersPerMatch: update.playersPerMatch, players: update.players);
    notifyListeners();
  }

  void handleStartingGame(StartingGame message) {
    final me = MySelfPlayer(_nickname() ?? 'Tu');
    final players = message.connectedPlayers
        .map((nickname) =>
            nickname == me.nickname ? me : (Player(nickname)..isBot = _offlineBotNames.contains(nickname)))
        .toList();
    this.me = me;
    game = Game(players, maxHandSize: message.maxHandSize);
    waitingRoom = null;
    phase = MatchPhase.playing;
    notifyListeners();
  }

  void handleHandUpdate(HandUpdate message) {
    me?.handCards = List.unmodifiable(message.handCards);
    notifyListeners();
  }

  void handleBriscolaUpdate(BriscolaUpdate message) {
    game?.briscola = message.briscolaCard;
    notifyListeners();
  }

  void handlePlayerStateUpdate(PlayerStateUpdate message) {
    final player = game?.playerNamed(message.nickname);
    if (player == null) return;
    player.playerState = message.playerState;
    final onTurn = message.playerState == PlayerState.BET || message.playerState == PlayerState.PUT;
    if (onTurn && message.turnLeft > Duration.zero) {
      player
        ..turnDeadline = message.receivedAt.add(message.turnLeft)
        ..turnLength = message.turnLength;
    } else {
      player
        ..turnDeadline = null
        ..turnLength = null;
    }
    notifyListeners();
  }

  void handleSettedBet(SettedBetUpdate message) {
    game?.playerNamed(message.nickname)
      ?..bet = message.bet
      ..hasBet = true;
    notifyListeners();
  }

  void handlePlayedCard(PlayedCardUpdate message) {
    final player = game?.playerNamed(message.nickname);
    if (player == null) return;
    player.playedCard = message.playedCard;
    if (player == me) {
      me!.removeCardFromHand(message.playedCard);
    }
    _markTrickWinner();
    notifyListeners();
  }

  // Once everyone has played, highlight who takes the trick while it stays on the table.
  // END_ROUND confirms it; the last trick of a set is only followed by END_SET, which does not say.
  void _markTrickWinner() {
    final game = this.game!;
    final inPlay = game.playerOrder.where((p) => p.playerState != PlayerState.EXIT).toList();
    if (inPlay.isEmpty || inPlay.any((p) => p.playedCard == null)) return;
    final trick = inPlay.map((p) => p.playedCard!).toList();
    game.trickWinner = inPlay[GameRules.trickWinnerIndex(trick, game.briscola?.seed)].nickname;
  }

  void handleEndRoundUpdate(EndRoundUpdate message) {
    final game = this.game;
    if (game == null) return;
    message.nextPlayerOrderAndTaken.forEach((nickname, taken) {
      game.playerNamed(nickname)?.roundsWon = taken;
    });
    game.playerOrder = game.playersInOrder(message.nextPlayerOrderAndTaken.keys);
    game.round = message.nextRoundNumber;
    // The winner leads the next trick, so comes first
    game.trickWinner = message.nextPlayerOrderAndTaken.keys.firstOrNull;
    notifyListeners();

    // Keep the finished trick on the table for a moment
    _inbox.pause(() {
      for (final p in game.players) {
        p.playedCard = null;
      }
      game.trickWinner = null;
      notifyListeners();
    });
  }

  void handleEndSetUpdate(EndSetUpdate message) {
    final game = this.game;
    final me = this.me;
    if (game == null || me == null) return;

    final myNewScore = message.nextPlayerOrderAndScore[me.nickname];
    if (myNewScore != null) {
      // An exact bet always gains points, a missed one always loses them
      lastSetDelta = myNewScore - me.score;
      lastSetResult = lastSetDelta > 0 ? SetResultAnimationState.win : SetResultAnimationState.loss;
    }
    message.nextPlayerOrderAndScore.forEach((nickname, score) {
      game.playerNamed(nickname)?.score = score;
    });
    game.playerOrder = game.playersInOrder(message.nextPlayerOrderAndScore.keys);
    game.set = message.nextSetNumber;
    game.setsPlayed = message.setsPlayed ?? game.setsPlayed + 1;
    game.round = 0;
    notifyListeners();

    // Show the last trick and the set result, then clear the table for the next deal
    _inbox.pause(() {
      for (final p in game.players) {
        p
          ..playedCard = null
          ..bet = 0
          ..hasBet = false
          ..roundsWon = 0;
      }
      game.trickWinner = null;
      lastSetResult = SetResultAnimationState.none;
      notifyListeners();
    });
  }

  void handleEndGame(EndGame message) {
    final game = this.game;
    if (game == null) return;
    message.gameResult.forEach((nickname, score) {
      game.playerNamed(nickname)?.score = score;
    });
    phase = MatchPhase.over;
    notifyListeners();
  }

  /// The player is out for good: the server has taken their card off the table and out of the turn order.
  /// If it is you, the server took you out after too many turns ran out.
  void handlePlayerExitGame(PlayerExitGame message) {
    final game = this.game;
    final player = game?.playerNamed(message.nickname);
    if (game == null || player == null) return;
    if (player == me) {
      _clearTable();
      phase = MatchPhase.none;
      notice = 'Sei stato tolto dalla partita: il tuo tempo è scaduto troppe volte.';
      notifyListeners();
      return;
    }
    player
      ..playerState = PlayerState.EXIT
      ..playedCard = null;
    game.playerOrder = game.playerOrder.where((p) => p != player).toList();
    if (game.trickWinner == player.nickname) game.trickWinner = null;
    notice = '${message.nickname} ha abbandonato la partita.';
    notifyListeners();
  }

  void handleTextMessage(TextMessage message) {
    notice = message.text;
    notifyListeners();
  }

  void handleInfoAfterReconnection(InfoAfterReconnection message) {
    final game = this.game;
    if (game == null) return;
    game
      ..set = message.set
      ..round = message.round
      ..setsPlayed = message.setsPlayed
      ..maxHandSize = message.maxHandSize;
    // A bet of 0 looks like no bet: once cards are being played, everyone has bet
    final bettingOver = message.round > 0 || message.playedCards.isNotEmpty;
    for (final p in game.players) {
      final bet = message.bets[p.nickname] ?? 0;
      p
        ..score = message.scores[p.nickname] ?? p.score
        ..bet = bet
        ..hasBet = bettingOver || bet > 0
        ..roundsWon = message.roundsWon[p.nickname] ?? 0
        ..playedCard = message.playedCards[p.nickname];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _offline?.dispose();
    super.dispose();
  }
}
