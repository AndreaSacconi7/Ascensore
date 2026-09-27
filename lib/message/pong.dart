import '../state/app_controller.dart';
import 'executable_in_client.dart';

/// Answer to the heartbeat; receiving it is all that matters (see ServerLink).
class Pong implements ExecutableInClient {
  Pong.fromJson(Map<String, dynamic> json);

  @override
  void execute(AppController app) {}
}
