/// Lightweight date/time formatting helpers — kept dependency-free
/// (no `intl` package) so this file drops into any Flutter project.
class Fmt {
  Fmt._();

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];
  static String weekdayShort(DateTime d) => weekday(d).substring(0, 3);
  static String month(DateTime d) => _months[d.month - 1];
  static String monthShort(DateTime d) => _monthsShort[d.month - 1];

  static String fullDate(DateTime d) => '${weekday(d)}, ${d.day} ${month(d)} ${d.year}';
  static String mediumDate(DateTime d) => '${d.day} ${monthShort(d)} ${d.year}';

  static String time12(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return weekday(d);
    return mediumDate(d);
  }

  static String dateTime(DateTime d) => '${relativeDay(d)} · ${time12(d)}';

  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return mediumDate(d);
  }

  static bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
