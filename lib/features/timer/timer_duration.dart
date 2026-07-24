int elapsedTimerSeconds({
  required DateTime startedAt,
  required DateTime endedAt,
}) {
  final seconds = endedAt.difference(startedAt).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

int secondsWithinDay({
  required DateTime startedAt,
  required int durationSeconds,
  required DateTime day,
}) {
  if (durationSeconds <= 0) {
    return 0;
  }

  final dayStart =
      day.isUtc
          ? DateTime.utc(day.year, day.month, day.day)
          : DateTime(day.year, day.month, day.day);
  final nextDayStart =
      day.isUtc
          ? DateTime.utc(day.year, day.month, day.day + 1)
          : DateTime(day.year, day.month, day.day + 1);
  final endedAt = startedAt.add(Duration(seconds: durationSeconds));
  final overlapStart = startedAt.isAfter(dayStart) ? startedAt : dayStart;
  final overlapEnd = endedAt.isBefore(nextDayStart) ? endedAt : nextDayStart;

  return elapsedTimerSeconds(startedAt: overlapStart, endedAt: overlapEnd);
}
