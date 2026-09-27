import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../authentication_state.dart';
import '../command/command.dart';
import '../message/player_info_response.dart';
import '../network/game_connection.dart';
import '../network/server_link.dart';

/// Where the player is with their profile.
enum SessionPhase {
  /// Not connected to the server as anyone: no profile yet, or not online. The menu (or, with email accounts,
  /// the login page).
  signedOut,

  /// Signed in to the account, but the server still needs a public nickname.
  choosingNickname,

  /// Signed in and known to the server by [SessionController.nickname].
  ready,

  /// The account logged in on another device, which took the connection.
  replaced,
}

/// Who the player is, and the connection to the server: the profile, the public nickname, and keeping the link
/// open (reconnecting after drops) while online.
///
/// Like most mobile games, playing needs no sign-up: the first time a player goes online ([goOnline]) they get
/// an anonymous profile tied to the device and only choose a nickname. Email accounts ([emailAccounts]) are
/// kept but off for now.
///
/// Every new connection starts by identifying the player with their access token; the server's answer
/// (PLAYER_INFO_RESPONSE) is applied through [handlePlayerInfo].
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService auth,
    required GameConnector connector,
    required void Function(String text) onServerText,
    required VoidCallback onSignedOut,
    this.emailAccounts = false,
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

  /// Sign-in with email and password, and log-out. Off: anonymous profiles only.
  final bool emailAccounts;
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

  /// The profile can be signed out of: an email account. Signing out of an anonymous profile would lose it.
  bool get canSignOut => emailAccounts && !_auth.isAnonymous && authState == AuthenticationState.authenticated;

  // Nickname the user chose, sent until the server accepts it
  String? _pendingNickname;

  // The player asked to go online, so a profile without a nickname is asked for one. A saved profile resumed
  // at startup is not: the nickname can wait until the player wants to play online.
  bool _wantsToPlay = false;

  /// Resumes the saved profile at startup, if there is one.
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

  /// Gets the player online: resumes the saved profile, or creates an anonymous one (no email, no password).
  /// The answer comes as PLAYER_INFO_RESPONSE: logged in, or asked for a nickname. False if no profile could be
  /// created (no network, or anonymous profiles disabled).
  Future<bool> goOnline() async {
    _wantsToPlay = true;
    if (phase == SessionPhase.ready) return true;
    if (await _auth.currentAccessToken() == null) {
      _setAuthState(AuthenticationState.loading);
      try {
        await _auth.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous sign-in failed: $e');
        _wantsToPlay = false;
        _setAuthState(AuthenticationState.unauthenticated);
        return false;
      }
    }
    if (phase == SessionPhase.replaced) phase = SessionPhase.signedOut;
    _link.open();
    return true;
  }

  /// The player changed their mind about choosing a nickname: back to the menu, offline. The profile stays.
  void cancelNickname() {
    _wantsToPlay = false;
    _pendingNickname = null;
    nicknameError = null;
    submittingNickname = false;
    unawaited(_link.close());
    phase = SessionPhase.signedOut;
    notifyListeners();
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
    _wantsToPlay = false;
    _pendingNickname = null;
    nicknameError = null;
    submittingNickname = false;
    phase = SessionPhase.signedOut;
    notifyListeners();
    await _auth.signOut();
    _setAuthState(AuthenticationState.unauthenticated);
  }

  /// Leaves the "playing elsewhere" page without taking the session back: back to the menu, offline.
  void leaveReplaced() {
    phase = SessionPhase.signedOut;
    notifyListeners();
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
      if (emailAccounts || _wantsToPlay) {
        nicknameError = response.error == PlayerInfoResponse.nicknameMissing ? null : response.error;
        phase = SessionPhase.choosingNickname;
      } else {
        // A saved profile without a nickname, resumed at startup: stay offline until the player goes online
        unawaited(_link.close());
        phase = SessionPhase.signedOut;
      }
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
