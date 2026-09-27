import 'package:flutter/foundation.dart';

import '../app_screen_state.dart';
import '../auth/auth_service.dart';
import '../config.dart';
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
    this.emailAccounts = emailAccountsEnabled,
    Duration resultDisplayTime = const Duration(seconds: 3),
    List<Duration>? reconnectBackoff,
    Duration heartbeatInterval = const Duration(seconds: 10),
  }) {
    _inbox = MessageInbox(pauseTime: resultDisplayTime, apply: (message) => message.execute(this));
    session = SessionController(
      auth: auth,
      connector: connector,
      emailAccounts: emailAccounts,
      onServerText: _onServerText,
      onLinkStateChanged: _onLinkStateChanged,
      onSignedOut: () {
        _pendingJoin = null;
        match.reset();
      },
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

  /// With email accounts the app opens on the login page; without, straight on the menu.
  final bool emailAccounts;

  // Match size to join once the player is online (profile created, nickname chosen)
  int? _pendingJoin;

  /// Getting the player online to join a match: shown as progress on the play button.
  bool get joining => _pendingJoin != null;

  late AppScreenState _screen = emailAccounts ? AppScreenState.login : AppScreenState.mainMenu;

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
      // Offline, with no profile or before going online: the menu is open to everyone
      SessionPhase.signedOut || SessionPhase.replaced => emailAccounts ? AppScreenState.login : AppScreenState.mainMenu,
    };
  }

  // ------------------------------------------------------------------
  // Player actions that need both the session and the match
  // ------------------------------------------------------------------

  /// Joins a match of [players] online. A player who is not online yet first gets their profile (an anonymous
  /// one, the first time) and, if they have none, chooses a nickname; matchmaking follows by itself.
  Future<void> playOnline({int? players}) async {
    if (session.phase == SessionPhase.ready) {
      match.joinGame(players: players);
      return;
    }
    _pendingJoin = players ?? match.matchSize;
    notifyListeners();
    if (!await session.goOnline()) {
      _pendingJoin = null;
      match.showNotice('Impossibile collegarsi al server, riprova tra poco.');
      notifyListeners();
    }
  }

  /// Back to the menu from the nickname page, without joining.
  void cancelNickname() {
    _pendingJoin = null;
    session.cancelNickname();
    notifyListeners();
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
      final players = _pendingJoin;
      if (players != null) {
        _pendingJoin = null;
        // Back in a match in progress (another device): that one comes first
        if (!response.inMatch) match.joinGame(players: players);
        notifyListeners();
      }
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
