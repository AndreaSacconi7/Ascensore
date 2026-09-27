import '../state/app_controller.dart';

/// Payload of a server message; applies itself to the part of the client state it concerns.
abstract class ExecutableInClient {
  void execute(AppController app);
}

/// Reads a JSON object of nickname -> int, keeping the server's key order (it carries meaning).
Map<String, int> intMap(dynamic json) =>
    (json as Map<String, dynamic>? ?? const {}).map((key, value) => MapEntry(key, value as int));
