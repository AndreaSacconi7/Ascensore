import '../state/app_controller.dart';
import '../model/card_game.dart';
import 'executable_in_client.dart';

class BriscolaUpdate implements ExecutableInClient {
  /// Null in the peak set until the card leading the trick sets it.
  final CardGame? briscolaCard;

  BriscolaUpdate.fromJson(Map<String, dynamic> json)
      : briscolaCard =
            json['briscolaCard'] == null ? null : CardGame.fromJson(json['briscolaCard'] as Map<String, dynamic>);

  @override
  void execute(AppController app) => app.match.handleBriscolaUpdate(this);
}
