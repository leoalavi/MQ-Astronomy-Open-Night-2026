import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/event_filter.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Localised names for the time-status enums.
///
/// The enums themselves carry an English `label` for diagnostics; everything
/// the visitor reads comes from here, so Persian shows Persian rather than a
/// hardcoded English badge in an otherwise translated screen.
extension EventTimingL10n on EventTiming {
  /// The visitor-facing name for this status.
  ///
  /// [phase] makes "not started yet" honest. EventTiming is computed by
  /// comparing timestamps, so on any date before 19 September *every* activity
  /// classifies as [EventTiming.upcoming] — and its label, "Later tonight",
  /// then claims the programme is running today. Most people download an event
  /// app in the weeks beforehand, so that wrong label is the one seen most.
  ///
  /// When the whole event is still [EventPhase.future] the same status reads
  /// "On the night" instead. Pass null only where the phase genuinely does not
  /// matter (diagnostics, tests of a single status).
  String labelOf(AonL10n l, {EventPhase? phase}) => switch (this) {
        EventTiming.happeningNow => l.timingHappeningNow,
        EventTiming.startingSoon => l.timingStartingSoon,
        EventTiming.upcoming => phase == EventPhase.future
            ? l.timingOnTheNight
            : l.timingLaterTonight,
        EventTiming.finished => l.timingFinished,
      };
}

extension EventPhaseL10n on EventPhase {
  /// Null when there is nothing worth announcing — see the Home hero.
  String? labelOf(AonL10n l) => switch (this) {
        EventPhase.future => null,
        EventPhase.today => l.phaseTonight,
        EventPhase.startingSoon => l.phaseStartsSoon,
        EventPhase.running => l.phaseHappeningNow,
        EventPhase.endingSoon => l.phaseEndingSoon,
        EventPhase.ended => l.phaseEnded,
      };
}

/// Localised names for the programme's own sections.
///
/// [EventCategory.label] stays English for diagnostics and test names; this is
/// what the visitor reads. Without it a fully Persian Program screen still
/// announced "Activities" above every card.
extension EventCategoryL10n on EventCategory {
  String labelOf(AonL10n l) => switch (this) {
        EventCategory.activity => l.categoryActivities,
        EventCategory.shortTalk => l.categoryShortTalks,
        EventCategory.keynote => l.categoryKeynote,
        EventCategory.featuredPresentation => l.categoryFeaturedPresentations,
      };
}

/// Localised names for the time-band filter chips.
///
/// The English labels are ranges — "4–6pm" — and a numeral/dash/numeral run
/// followed by a Latin "pm" is precisely the shape the bidi algorithm reorders
/// inside a right-to-left line: the chips rendered as "10pm–8", "8pm–6",
/// "6pm–4", each reversed and each therefore wrong. The Persian strings spell
/// the range out, so there is no mixed-direction run left to reorder.
extension TimeBandL10n on TimeBand {
  String labelOf(AonL10n l) => switch (this) {
        TimeBand.earlyEvening => l.bandEarlyEvening,
        TimeBand.evening => l.bandEvening,
        TimeBand.lateEvening => l.bandLateEvening,
      };
}
