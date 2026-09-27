import '../state/app_controller.dart';
import 'executable_in_client.dart';

class EndGame implements ExecutableInClient {
  /// Final scores, winner first.
  final Map<String, int> gameResult;

  EndGame.fromJson(Map<String, dynamic> json) : gameResult = intMap(json['gameResult']);

  @override
  void execute(AppController app) => app.match.handleEndGame(this);
}
