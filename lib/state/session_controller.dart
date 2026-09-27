import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../authentication_state.dart';
import '../command/command.dart';
import '../message/player_info_response.dart';
import '../network/game_connection.dart';
import '../network/server_link.dart';

/// Where the player is with their account.
enum SessionPhase {
  /// Not signed in (or signing in): the login page.
  signedOut,

  /// Signed in to the account, but the server still needs a public nickname.
  choosingNickname,

  /// Signed in and known to the server by [SessionController.nickname].
  ready,

  /// The account logged in on another device, which took the connection.
  replaced,
}

/// Who the player is, and the connection to the server: signing in and out, choosing the public nickname,
/// and keeping the link open (reconnecting after drops) while signed in.
///
/// Every new connection starts by identifying the player with their access token; the server's answer
/// (PLAYER_INFO_RESPONSE) is applied through [handlePlayerInfo].
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService auth,
    required GameConnector connector,
    required void Function(String text) onServerText,
    required VoidCallback onSignedOut,
    void Function(LinkState state)? onLinkStateChanged,
    List<Duration>? reconnectBackoff,
    Duration heartbeatInterval = const Duration(seconds: 10),
  })  : _auth = auth,
        _onSignedOut = onSignedOut,
        _onLinkStateChanged = onLinkStateChanged {
    _link = ServerLink(
      connector: connector,
      onConnected: _identify,
      onMessage: onServerText,
      onStateChanged: _linkStateChanged,
      heartbeatMessage: Command.ping().toJson(),
      heartbeatInterval: heartbeatInterval,
      backoff: reconnectBackoff ?? ServerLink.defaultBackoff,
    );
  }

  final AuthService _auth;
  final VoidCallback _onSignedOut;
  final void Function(LinkState state)? _onLinkStateChanged;
  late final ServerLink _link;

  SessionPhase phase = SessionPhase.signedOut;
  AuthenticationState authState = AuthenticationState.unknown;

  /// Shown once by the login page, then cleared.
  String? authError;

  /// Why the chosen nickname was refused (one of the PlayerInfoResponse error codes).
  String? nicknameError;
  bool submittingNickname = false;

  LinkState linkState = LinkState.closed;

  /// The player's public nickname, once the server has accepted the login.
  String? nickname;

  /// Playing without an account (offline only).
  bool get isGuest => authState != AuthenticationState.authenticated;

  // Nickname the user chose, sent until the server accepts it
  String? _pendingNickname;

  /// Resumes a saved session at startup, if there is one.
  Future<void> checkLoginStatus() async {
    _setAuthState(AuthenticationState.loading);
    final token = await _auth.currentAccessToken();
    if (token == null) {
      _setAuthState(AuthenticationState.unauthenticated);
      return;
    }
    _link.open();
  }

  Future<void> loginWithEmail(String email, String password) async {
    _setAuthState(AuthenticationState.loading);
    try {
      await _auth.signIn(email, password);
      _link.open();
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      _failAuth('Email o password non corretti.');
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    _setAuthState(AuthenticationState.loading);
    try {
      final token = await _auth.signUp(email, password);
      if (token == null) {
        authError = 'Controlla la tua email per confermare la registrazione, poi accedi.';
        _setAuthState(AuthenticationState.unauthenticated);
        return;
      }
      _link.open();
    } catch (e) {
      debugPrint('Sign-up failed: $e');
      _failAuth('Registrazione non riuscita: controlla l\'email e usa una password di almeno 6 caratteri.');
    }
  }

  /// Sends the chosen public nickname; the answer comes as PLAYER_INFO_RESPONSE.
  void submitNickname(String nickname) {
    _pendingNickname = nickname;
    nicknameError = null;
    submittingNickname = true;
    notifyListeners();
    _identify();
  }

  void clearAuthError() {
    authError = null;
  }

  Future<void> logOut() async {
    _link.send(Command.logout().toJson());
    // Not awaited: the close handshake must not keep the player on this screen
    unawaited(_link.close());
    _onSignedOut();
    nickname = null;
    _pendingNickname = null;
    nicknameError = null;
    submittingNickname = false;
    phase = SessionPhase.signedOut;
    notifyListeners();
    await _auth.signOut();
    _setAuthState(AuthenticationState.unauthenticated);
  }

  /// Takes the session back from the other device.
  void playHere() {
    authState = AuthenticationState.loading;
    phase = SessionPhase.signedOut;
    notifyListeners();
    _link.open();
  }

  /// Sends a command to the server (dropped if the link is down: the server replays the state on reconnect).
  void send(String command) => _link.send(command);

  // ------------------------------------------------------------------
  // Server messages
  // ------------------------------------------------------------------

  void handlePlayerInfo(PlayerInfoResponse response) {
    submittingNickname = false;
    if (response.isLogged) {
      _pendingNickname = null;
      nicknameError = null;
      authState = AuthenticationState.authenticated;
      nickname = response.nickname;
      phase = SessionPhase.ready;
    } else if (response.needsNickname) {
      authState = AuthenticationState.authenticated;
      nicknameError = response.error == PlayerInfoResponse.nicknameMissing ? null : response.error;
      phase = SessionPhase.choosingNickname;
    } else {
      // Token refused: the session is no longer valid
      authError = 'Sessione scaduta, accedi di nuovo.';
      unawaited(logOut());
    }
    notifyListeners();
  }

  /// The account logged in on another device and the server closed this connection. Reconnecting on our
  /// own would take the session back and the two devices would keep replacing each other, so the link
  /// stays closed until the player chooses to play here again ([playHere]).
  void handleSessionReplaced() {
    phase = SessionPhase.replaced;
    unawaited(_link.close());
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  // Runs on every new connection: identifies the player, which also resumes a match in progress
  Future<void> _identify() async {
    final token = await _auth.currentAccessToken();
    if (token == null) {
      // The saved session is gone (signed out elsewhere, or the refresh token expired)
      await logOut();
      return;
    }
    _link.send(Command.playerInfoRequest(token: token, nickname: _pendingNickname ?? '').toJson());
  }

  void _linkStateChanged(LinkState state) {
    linkState = state;
    _onLinkStateChanged?.call(state);
    notifyListeners();
  }

  void _failAuth(String message) {
    authError = message;
    _setAuthState(AuthenticationState.error);
  }

  void _setAuthState(AuthenticationState state) {
    authState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_link.close());
    super.dispose();
  }
}
