import 'package:intl/intl.dart';

/// Device-local date/time helpers for API parsing and UI display.
class AppDateTime {
  AppDateTime._();

  /// Converts UTC (or already-local) instants to the device timezone.
  static DateTime toLocal(DateTime value) =>
      value.isUtc ? value.toLocal() : value;

  /// Parses an ISO-8601 API timestamp in the device local timezone.
  static DateTime parseApi(String raw) => toLocal(DateTime.parse(raw));

  /// Plan cards and detail: "Today, 7:00 PM", "Tomorrow, 3:30 PM", etc.
  static String formatPlanTime(DateTime value) {
    final t = toLocal(value);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(t.year, t.month, t.day);
    final clock = DateFormat('h:mm a');
    if (planDay == today) {
      return 'Today, ${clock.format(t)}';
    }
    if (planDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${clock.format(t)}';
    }
    return '${DateFormat.MMMd().format(t)}, ${clock.format(t)}';
  }

  /// Date picker chip: "Today", "Tomorrow", or "Wed, May 28".
  static String formatDateLabel(DateTime d) {
    final local = toLocal(d);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(local.year, local.month, local.day);
    if (planDay == today) return 'Today';
    if (planDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(local);
  }

  /// Create/edit schedule summary: "Today · 7:00 PM".
  static String formatSchedule(DateTime d) {
    final local = toLocal(d);
    return '${formatDateLabel(local)} · ${DateFormat('h:mm a').format(local)}';
  }

  /// Notification relative time from [createdAt].
  static String formatTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(toLocal(createdAt));
    final m = diff.inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '${m}m ago';
    if (m < 60 * 24) return '${m ~/ 60}h ago';
    return '${m ~/ 60 ~/ 24}d ago';
  }
}
