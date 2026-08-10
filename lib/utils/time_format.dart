import 'package:intl/intl.dart';

import 'package:aon2026/models/event.dart';

/// Time and date formatting.
///
/// All output uses the Australian convention the printed programme uses —
/// "5pm", "6.15pm" (a dot, not a colon), lowercase meridiem — so the app reads
/// the same as the paper in the attendee's other hand. `intl`'s default
/// `jm` pattern would give "5:00 PM", which is subtly foreign here.
abstract final class TimeFormat {
  static final DateFormat _hour = DateFormat('h');
  static final DateFormat _hourMinute = DateFormat('h.mm');
  static final DateFormat _meridiem = DateFormat('a');

  /// '5pm', '6.15pm', '10pm'.
  ///
  /// Minutes are dropped when zero, matching the programme.
  static String time(DateTime t) {
    final meridiem = _meridiem.format(t).toLowerCase();
    final core = t.minute == 0 ? _hour.format(t) : _hourMinute.format(t);
    return '$core$meridiem';
  }

  /// '5pm – 5.45pm'. Uses an en dash, as the programme does.
  static String range(DateTime start, DateTime end) =>
      '${time(start)} – ${time(end)}';

  static String session(EventSession s) => range(s.start, s.end);

  /// 'Saturday 19 September 2026'.
  static String longDate(DateTime d) =>
      DateFormat('EEEE d MMMM y').format(d);

  /// '19 September 2026'.
  static String date(DateTime d) => DateFormat('d MMMM y').format(d);

  /// A live wall clock with seconds, in the app's convention: '8.41.07pm'.
  /// Used by the passport reward screen as a "this is live" nudge (design §7.3).
  static String clockWithSeconds(DateTime t) {
    final meridiem = _meridiem.format(t).toLowerCase();
    return '${DateFormat('h.mm.ss').format(t)}$meridiem';
  }

  /// All sessions of an event, joined for display.
  /// '5pm – 5.45pm, 6.15pm – 7pm, 8.45pm – 9.30pm'.
  static String allSessions(AonEvent event) {
    final sorted = [...event.sessions]
      ..sort((a, b) => a.start.compareTo(b.start));
    return sorted.map(session).join(', ');
  }

  /// A short relative countdown: 'in 12 min', 'in 1 hr 5 min', 'now'.
  ///
  /// Deliberately caps at hours — the event is six hours long, so "in 2 days"
  /// can never be a useful string here, and rounding to the nearest minute is
  /// the resolution people can act on.
  static String until(DateTime from, DateTime to) {
    final d = to.difference(from);
    if (d.isNegative || d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (minutes == 0) return 'in $hours hr';
    return 'in $hours hr $minutes min';
  }

  /// How long is left of a running session: 'ends in 12 min'.
  static String remaining(DateTime now, DateTime end) {
    final d = end.difference(now);
    if (d.isNegative) return 'ended';
    if (d.inMinutes < 1) return 'ending now';
    if (d.inMinutes < 60) return 'ends in ${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (minutes == 0) return 'ends in $hours hr';
    return 'ends in $hours hr $minutes min';
  }
}
