import 'dart:async';
import 'dart:convert';

import 'package:ascensore_client/auth/auth_service.dart';
import 'package:ascensore_client/network/game_connection.dart';

class FakeAuthService implements AuthService {
  String? token;
  bool signedOut = false;
  bool anonymous = false;
  int anonymousSignIns = 0;

  /// Anonymous sign-in fails (disabled in the project, or no network).
  bool anonymousFails = false;

  FakeAuthService({this.token});

  @override
  Future<String> signInAnonymously() async {
    if (anonymousFails) throw StateError('anonymous sign-ins are disabled');
    anonymousSignIns++;
    anonymous = true;
    return token = 'anon-token';
  }

  @override
  bool get isAnonymous => anonymous;

  @override
  Future<String?> currentAccessToken() async => token;

  @override
  Future<String> signIn(String email, String password) async => token = 'token-$email';

  @override
  Future<String?> signUp(String email, String password) async => token = 'token-$email';

  @override
  Future<void> signOut() async {
    signedOut = true;
    token = null;
  }
}

/// A connection the test drives: [receive] plays the server, [sent] records the commands.
class FakeConnection implements GameConnection {
  final _incoming = StreamController<String>();
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String text) => sent.add(jsonDecode(text) as Map<String, dynamic>);

  @override
  Future<void> close() async {
    closed = true;
    unawaited(_incoming.close());
  }

  /// The server sends a message.
  void receive(String messageType, [Map<String, dynamic> executable = const {}]) =>
      _incoming.add(jsonEncode({'messageType': messageType, 'executable': executable}));

  /// The connection drops (network change, server restart).
  void drop() => _incoming.close();

  List<String> get sentTypes => sent.map((c) => c['commandType'] as String).toList();
}

/// Hands out a new [FakeConnection] per connection attempt, or fails while [serverDown].
class FakeConnector {
  final List<FakeConnection> connections = [];
  bool serverDown = false;

  Future<GameConnection> call() async {
    if (serverDown) throw StateError('connection refused');
    final connection = FakeConnection();
    connections.add(connection);
    return connection;
  }

  FakeConnection get last => connections.last;
}
