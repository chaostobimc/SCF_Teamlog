/// Zeit- und Zahlenformate fuer die Anzeige.
class AppFormatters {
  static String clock(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = s ~/ 60;
    final seconds = s % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String percent(double ratio) {
    if (ratio.isNaN) return '-';
    return '${(ratio * 100).round()}%';
  }

  static String date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  static String dateClock(DateTime value) {
    final d = date(value);
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$d, $h:$m Uhr';
  }
}
