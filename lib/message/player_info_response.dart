import '../state/app_controller.dart';
import 'executable_in_client.dart';

class PlayerInfoResponse implements ExecutableInClient {
  static const invalidToken = 'INVALID_TOKEN';
  static const nicknameMissing = 'NICKNAME_MISSING';
  static const nicknameInvalid = 'NICKNAME_INVALID';
  static const nicknameTaken = 'NICKNAME_TAKEN';

  final String nickname;
  final bool isLogged;

  /// Logged in to Supabase but without a public nickname yet: the user must choose one.
  final bool needsNickname;

  /// A match is in progress: its table state follows.
  final bool inMatch;

  final String? error;

  PlayerInfoResponse.fromJson(Map<String, dynamic> json)
      : nickname = json['nickname'] as String? ?? '',
        isLogged = json['isLogged'] as bool? ?? false,
        needsNickname = json['needsNickname'] as bool? ?? false,
        inMatch = json['inMatch'] as bool? ?? false,
        error = json['error'] as String?;

  @override
  void execute(AppController app) => app.handlePlayerInfo(this);
}
