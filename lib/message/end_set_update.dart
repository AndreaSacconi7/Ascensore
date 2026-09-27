import '../state/app_controller.dart';
import 'executable_in_client.dart';

/// A set is over.
class EndSetUpdate implements ExecutableInClient {
  /// Scores per player, keyed in the betting order of the next set.
  final Map<String, int> nextPlayerOrderAndScore;

  /// Hand size of the next set.
  final int nextSetNumber;

  /// Sets completed so far; null from servers that do not send it.
  final int? setsPlayed;

  EndSetUpdate.fromJson(Map<String, dynamic> json)
      : nextPlayerOrderAndScore = intMap(json['nextPlayerOrderAndScore']),
        nextSetNumber = json['nextSetNumber'] as int,
        setsPlayed = json['setsPlayed'] as int?;

  @override
  void execute(AppController app) => app.match.handleEndSetUpdate(this);
}
