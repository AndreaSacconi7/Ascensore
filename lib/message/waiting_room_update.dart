import '../state/app_controller.dart';
import 'executable_in_client.dart';

/// Who is waiting in your match, sent whenever someone joins or leaves before it starts.
class WaitingRoomUpdate implements ExecutableInClient {
  final int playersPerMatch;

  /// Nicknames in joining order.
  final List<String> players;

  WaitingRoomUpdate.fromJson(Map<String, dynamic> json)
      : playersPerMatch = json['playersPerMatch'] as int? ?? 2,
        players = List<String>.from(json['players'] as List? ?? const []);

  @override
  void execute(AppController app) => app.match.handleWaitingRoomUpdate(this);
}
