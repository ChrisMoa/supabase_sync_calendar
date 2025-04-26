class TimeUtils {
  /// Snaps a DateTime to the nearest interval
  /// [dateTime] The original DateTime to snap
  /// [intervalMinutes] The interval in minutes (e.g., 15, 30)
  /// Returns the snapped DateTime
  static DateTime snapToInterval(DateTime dateTime, int intervalMinutes) {
    if (intervalMinutes <= 0) return dateTime;

    final minutes = dateTime.minute;
    final remainder = minutes % intervalMinutes;

    if (remainder == 0) return dateTime; // Already on interval

    // Round to nearest interval
    final roundedMinutes = remainder < intervalMinutes / 2
        ? minutes - remainder
        : minutes + (intervalMinutes - remainder);

    // Create new DateTime with snapped minutes
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour + (roundedMinutes ~/ 60),
      roundedMinutes % 60,
      0, // Zero out seconds
      0, // Zero out milliseconds
    );
  }
}
