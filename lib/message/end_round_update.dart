import '../state/app_controller.dart';
import 'executable_in_client.dart';

/// A trick is over.
class EndRoundUpdate implements ExecutableInClient {
  /// Tricks taken per player, keyed in the play order of the next trick (winner first).
  final Map<String, int> nextPlayerOrderAndTaken;

  /// Tricks completed so far in this set.
  final int nextRoundNumber;

  EndRoundUpdate.fromJson(Map<String, dynamic> json)
      : nextPlayerOrderAndTaken = intMap(json['nextPlayerOrderAndTaken']),
        nextRoundNumber = json['nextRoundNumber'] as int;

  @override
  void execute(AppController app) => app.match.handleEndRoundUpdate(this);
}
