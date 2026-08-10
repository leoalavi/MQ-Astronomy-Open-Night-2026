import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Localised names for the time-status enums.
///
/// The enums themselves carry an English `label` for diagnostics; everything
/// the visitor reads comes from here, so Persian shows Persian rather than a
/// hardcoded English badge in an otherwise translated screen.
extension EventTimingL10n on EventTiming {
  String labelOf(AonL10n l) => switch (this) {
        EventTiming.happeningNow => l.timingHappeningNow,
        EventTiming.startingSoon => l.timingStartingSoon,
        EventTiming.upcoming => l.timingLaterTonight,
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
