import '../state/app_controller.dart';
import '../model/player_state.dart';
import 'executable_in_client.dart';

class PlayerStateUpdate implements ExecutableInClient {
  final PlayerState playerState;
  final String nickname;

  /// Time left for this turn and the full turn length; zero when there is no time limit.
  final Duration turnLeft;
  final Duration turnLength;

  /// When the message arrived: the countdown starts from here, even if the message is applied later
  /// (queued behind a trick that stays on screen).
  final DateTime receivedAt;

  PlayerStateUpdate.fromJson(Map<String, dynamic> json)
      : playerState = PlayerState.values.byName(json['playerState'] as String),
        nickname = json['nickname'] as String,
        turnLeft = Duration(milliseconds: (json['turnMillisLeft'] as num?)?.toInt() ?? 0),
        turnLength = Duration(milliseconds: (json['turnMillis'] as num?)?.toInt() ?? 0),
        receivedAt = DateTime.now();

  @override
  void execute(AppController app) => app.match.handlePlayerStateUpdate(this);
}
