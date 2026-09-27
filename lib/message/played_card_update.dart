import '../state/app_controller.dart';
import '../model/card_game.dart';
import 'executable_in_client.dart';

class PlayedCardUpdate implements ExecutableInClient {
  final String nickname;
  final CardGame playedCard;

  PlayedCardUpdate.fromJson(Map<String, dynamic> json)
      : nickname = json['nickname'] as String,
        playedCard = CardGame.fromJson(json['playedCard'] as Map<String, dynamic>);

  @override
  void execute(AppController app) => app.match.handlePlayedCard(this);
}
