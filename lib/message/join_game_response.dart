import '../state/app_controller.dart';
import 'executable_in_client.dart';

class JoinGameResponse implements ExecutableInClient {
  final String nickname;
  final bool isJoined;
  final int playersPerMatch;

  JoinGameResponse.fromJson(Map<String, dynamic> json)
      : nickname = json['nickname'] as String,
        isJoined = json['isJoined'] as bool,
        playersPerMatch = json['playersPerMatch'] as int? ?? 2;

  @override
  void execute(AppController app) => app.match.handleJoinGameResponse(this);
}
