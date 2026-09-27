import '../state/app_controller.dart';
import '../model/card_game.dart';
import 'executable_in_client.dart';

/// Table state for a player who reconnected to a match in progress.
class InfoAfterReconnection implements ExecutableInClient {
  final int set;
  final int round;
  final int setsPlayed;
  final int maxHandSize;
  final Map<String, int> scores;
  final Map<String, int> bets;
  final Map<String, int> roundsWon;

  /// Cards on the table in the current trick, in play order.
  final Map<String, CardGame> playedCards;

  InfoAfterReconnection.fromJson(Map<String, dynamic> json)
      : set = json['set'] as int? ?? 1,
        round = json['round'] as int? ?? 0,
        setsPlayed = json['setsPlayed'] as int? ?? 0,
        maxHandSize = json['maxHandSize'] as int? ?? 10,
        scores = intMap(json['scores']),
        bets = intMap(json['bets']),
        roundsWon = intMap(json['roundsWon']),
        playedCards = (json['playedCards'] as Map<String, dynamic>? ?? const {})
            .map((key, value) => MapEntry(key, CardGame.fromJson(value as Map<String, dynamic>)));

  @override
  void execute(AppController app) => app.match.handleInfoAfterReconnection(this);
}
