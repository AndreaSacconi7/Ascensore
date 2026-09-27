import '../state/app_controller.dart';
import 'executable_in_client.dart';

/// This account logged in on another device; the server closes this connection next.
class SessionReplaced implements ExecutableInClient {
  SessionReplaced.fromJson(Map<String, dynamic> json);

  @override
  void execute(AppController app) => app.handleSessionReplaced();
}
