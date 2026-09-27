/// Seconds left until [deadline], rounded up; zero once it has passed.
int secondsLeft(DateTime deadline) {
  final millis = deadline.difference(DateTime.now()).inMilliseconds;
  return millis <= 0 ? 0 : (millis / 1000).ceil();
}

/// Share of the turn still left, from 1 to 0.
double turnFractionLeft(DateTime deadline, Duration length) {
  if (length <= Duration.zero) return 0;
  final left = deadline.difference(DateTime.now()).inMilliseconds / length.inMilliseconds;
  return left.clamp(0.0, 1.0);
}

/// In the last seconds the turn ring around the avatar turns red.
const hurrySeconds = 10;
