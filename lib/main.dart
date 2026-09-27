import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'network/game_connection.dart';
import 'state/app_controller.dart';
import 'state/app_providers.dart';

// Game server endpoint, overridable with --dart-define=SERVER_URL=wss://host/ws
const _serverUrlOverride = String.fromEnvironment('SERVER_URL');

// Defaults reach a local server from a browser or from the Android emulator
Uri get _serverUrl => Uri.parse(
    _serverUrlOverride.isNotEmpty ? _serverUrlOverride : (kIsWeb ? 'ws://localhost:8080/ws' : 'ws://10.0.2.2:8080/ws'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The publishable key is meant to ship in clients; data access is guarded by Row Level Security
  await Supabase.initialize(
    url: 'https://hwjukdydgsejqbhzezyt.supabase.co',
    anonKey: 'sb_publishable_1c4XQ9P0rHnkh2sCC6pmlw_-1AGsTk9',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final app = AppController(
    auth: SupabaseAuthService(),
    connector: () => WebSocketGameConnection.connect(_serverUrl),
  );
  runApp(AppProviders(app: app, child: const AscensoreApp()));
}
