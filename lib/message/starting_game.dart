import '../state/app_controller.dart';
import 'executable_in_client.dart';

class StartingGame implements ExecutableInClient {
  /// Nicknames in betting order.
  final List<String> connectedPlayers;

  /// Largest hand of the match: hands go 1..maxHandSize..1.
  final int maxHandSize;

  StartingGame.fromJson(Map<String, dynamic> json)
      : connectedPlayers = List<String>.from(json['connectedPlayers'] as List),
        maxHandSize = json['maxHandSize'] as int? ?? 10;

  @override
  void execute(AppController app) => app.match.handleStartingGame(this);
}
