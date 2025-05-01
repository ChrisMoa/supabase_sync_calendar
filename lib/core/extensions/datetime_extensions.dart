extension DateTimeExtensions on DateTime {
  bool isStartOfDay() {
    return hour == 0 && minute == 0 && second == 0 && millisecond == 0;
  }

  bool isEndOfDay() {
    return hour == 23 && minute == 59 && second == 59 && millisecond == 999;
  }
}
