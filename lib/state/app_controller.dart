import 'package:flutter/foundation.dart';

import '../app_screen_state.dart';
import '../auth/auth_service.dart';
import '../message/player_info_response.dart';
import '../network/game_connection.dart';
import '../network/server_link.dart';
import 'match_controller.dart';
import 'message_inbox.dart';
import 'session_controller.dart';

/// Root of the client state. It wires together:
/// - the [session]: account, public nickname and connection to the server;
/// - the [match]: matchmaking, the table and the moves, online or offline;
/// - the inbox that applies server messages to them one at a time, in arrival order.
///
/// It also decides which [screen] is shown, from where the session and the match are.
class AppController extends ChangeNotifier {
  AppController({
    required AuthService auth,
    required GameConnector connector,
    Duration resultDisplayTime = const Duration(seconds: 3),
    List<Duration>? reconnectBackoff,
    Duration heartbeatInterval = const Duration(seconds: 10),
  }) {
    _inbox = MessageInbox(pauseTime: resultDisplayTime, apply: (message) => message.execute(this));
    session = SessionController(
      auth: auth,
      connector: connector,
      onServerText: _onServerText,
      onLinkStateChanged: _onLinkStateChanged,
      onSignedOut: () => match.reset(),
      reconnectBackoff: reconnectBackoff,
      heartbeatInterval: heartbeatInterval,
    );
    match = MatchController(inbox: _inbox, sendToServer: session.send, nickname: () => session.nickname);
    session.addListener(_updateScreen);
    match.addListener(_updateScreen);
  }

  late final SessionController session;
  late final MatchController match;
  late final MessageInbox _inbox;

  AppScreenState _screen = AppScreenState.login;

  AppScreenState get screen => _screen;

  void _updateScreen() {
    final next = _screenNow();
    if (next != _screen) {
      _screen = next;
      notifyListeners();
    }
  }

  AppScreenState _screenNow() {
    if (session.phase == SessionPhase.replaced) return AppScreenState.sessionReplaced;
    switch (match.phase) {
      case MatchPhase.over:
        return AppScreenState.gameOver;
      case MatchPhase.waiting:
      case MatchPhase.playing:
        return AppScreenState.inGame;
      case MatchPhase.none:
        break;
    }
    return switch (session.phase) {
      SessionPhase.ready => AppScreenState.mainMenu,
      SessionPhase.choosingNickname => AppScreenState.chooseNickname,
      // A guest back from an offline match lands here too
      SessionPhase.signedOut || SessionPhase.replaced => AppScreenState.login,
    };
  }

  // While an offline match is in progress the server's messages are ignored: its state is not ours now
  void _onServerText(String text) {
    if (!match.isOffline) _inbox.add(text);
  }

  void _onLinkStateChanged(LinkState state) {
    if (state == LinkState.reconnecting && !match.isOffline) {
      // The server replays the full table state after reconnecting: queued updates are stale
      _inbox.clear();
    }
  }

  // ------------------------------------------------------------------
  // Messages that concern both the session and the match
  // ------------------------------------------------------------------

  void handlePlayerInfo(PlayerInfoResponse response) {
    session.handlePlayerInfo(response);
    if (response.isLogged) {
      match.handleLoggedIn(inMatch: response.inMatch);
    }
  }

  void handleSessionReplaced() {
    match.reset();
    session.handleSessionReplaced();
  }

  @override
  void dispose() {
    _inbox.clear();
    match.dispose();
    session.dispose();
    super.dispose();
  }
}
