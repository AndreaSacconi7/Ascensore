/// Players waiting for a match to fill up.
class WaitingRoom {
  final int playersPerMatch;
  final List<String> players;

  const WaitingRoom({required this.playersPerMatch, required this.players});

  int get missing => (playersPerMatch - players.length).clamp(0, playersPerMatch);
}
