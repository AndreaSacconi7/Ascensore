import '../state/app_controller.dart';
import 'executable_in_client.dart';

/// Why the server rejected this player's last command.
class TextMessage implements ExecutableInClient {
  final String text;

  TextMessage.fromJson(Map<String, dynamic> json) : text = json['text'] as String;

  @override
  void execute(AppController app) => app.match.handleTextMessage(this);
}
