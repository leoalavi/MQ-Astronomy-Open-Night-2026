import 'package:intl/intl.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

import 'package:aon2026/models/event.dart';

/// Time and date formatting.
///
/// All output uses the Australian convention the printed programme uses —
/// "5pm", "6.15pm" (a dot, not a colon), lowercase meridiem — so the app reads
/// the same as the paper in the attendee's other hand. `intl`'s default
/// `jm` pattern would give "5:00 PM", which is subtly foreign here.
abstract final class TimeFormat {
  /// A count formatted for the current locale.
  ///
  /// Persian uses Extended Arabic-Indic digits (۳۶), so a bare `'$n'` renders a
  /// Western "36" next to correctly localised times like "۴ب.ظ." — the Program
  /// screen showed exactly that mismatch in its section-count pills.
  static String count(int value) =>
      NumberFormat.decimalPattern(locale).format(value);

  /// The locale used for date/time formatting.
  ///
  /// Set from `AonApp` whenever the app locale changes. `intl`'s `DateFormat`
  /// resolves month and weekday names from this, so a Persian UI gets Persian
  /// dates instead of English ones embedded in a right-to-left screen.
  ///
  /// A static rather than a parameter on every call: `TimeFormat` is used from
  /// ~30 call sites, most of them deep in widget trees that would otherwise
  /// have to thread a locale down purely for formatting.
  static String? locale;

  static DateFormat _fmt(String pattern) => DateFormat(pattern, locale);

  static DateFormat get _hour => _fmt('h');
  static DateFormat get _hourMinute => _fmt('h.mm');
  static DateFormat get _meridiem => _fmt('a');

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
      _fmt('EEEE d MMMM y').format(d);

  /// '19 September 2026'.
  static String date(DateTime d) => _fmt('d MMMM y').format(d);

  /// A live wall clock with seconds, in the app's convention: '8.41.07pm'.
  /// Used by the passport reward screen as a "this is live" nudge (design §7.3).
  static String clockWithSeconds(DateTime t) {
    final meridiem = _meridiem.format(t).toLowerCase();
    return '${_fmt('h.mm.ss').format(t)}$meridiem';
  }

  /// All sessions of an event, joined for display.
  /// '5pm – 5.45pm, 6.15pm – 7pm, 8.45pm – 9.30pm'.
  static String allSessions(AonEvent event) {
    final sorted = [...event.sessions]
      ..sort((a, b) => a.start.compareTo(b.start));
    return sorted.map(session).join(', ');
  }

  /// A bare duration: '12 min', '1 hr', '1 hr 5 min'.
  ///
  /// Deliberately caps at hours — the event is six hours long, so "2 days"
  /// can never be a useful string here, and rounding to the nearest minute is
  /// the resolution people can act on. Shares the walking-ETA wording so a
  /// duration reads the same everywhere in the app.
  static String duration(AonL10n l, Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 60) return l.mapNavEtaMin(minutes);
    final hours = d.inHours;
    final rest = minutes % 60;
    if (rest == 0) return l.timeDurationHours(hours);
    return l.mapNavEtaHourMin(hours, rest);
  }

  /// A short relative countdown: 'in 12 min', 'in 1 hr 5 min', 'now'.
  static String until(AonL10n l, DateTime from, DateTime to) {
    final d = to.difference(from);
    if (d.isNegative || d.inMinutes < 1) return l.timeRelativeNow;
    return l.timeRelativeIn(duration(l, d));
  }

  /// How long is left of a running session: 'in 12 min', 'ending now',
  /// 'ended'.
  ///
  /// Returns the countdown WITHOUT an "ends" prefix. Callers used to build the
  /// full sentence and then `replaceFirst('ends ', '')` it back off for the
  /// badge — string surgery that only ever worked in English, and silently
  /// left the whole sentence in a Persian badge.
  static String remaining(AonL10n l, DateTime now, DateTime end) {
    final d = end.difference(now);
    if (d.isNegative) return l.timeRelativeEnded;
    if (d.inMinutes < 1) return l.timeRelativeEndingNow;
    return l.timeRelativeIn(duration(l, d));
  }
}
