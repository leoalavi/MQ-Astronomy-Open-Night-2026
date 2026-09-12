import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
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
        // No published time — say exactly that, never a clock-derived status.
        EventTiming.unscheduled => l.timingTimeNotPublished,
      };
}

extension EventPhaseL10n on EventPhase {
  /// Null when there is nothing worth announcing — see the Home hero.
  String? labelOf(AonL10n l) => switch (this) {
        EventPhase.future => null,
        EventPhase.today => l.phaseTonight,
        EventPhase.startingSoon => l.phaseStartsSoon,
        // Deliberately null, not `phaseHappeningNow`.
        //
        // The hero pill sits directly above the "Happening now" activity rail,
        // whose header is the *same string* (`timingHappeningNow`) and whose
        // cards each carry the same badge again. On the night that put
        // "Happening now" on screen four times in one viewport, with the
        // topmost one saying the least — it repeats what the date pill above
        // it and the section below it already establish. Reported by Leo Alavi,
        // 2026-09-08: "دوبار Happening Now تکرار شده، اولی اون بالایه اضافه هست".
        //
        // Every other phase stays: each says something the rail cannot
        // ("Starts soon", "Ending soon", "This event has finished").
        EventPhase.running => null,
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


/// Localised names for the venue categories.
///
/// [VenueCategory.label] stays English for diagnostics; this is what the
/// visitor hears. Without it a Persian map announced every marker as
/// "Event venue" through the screen reader, and the campus search sheet
/// subtitled Persian results in English.
extension VenueCategoryL10n on VenueCategory {
  String labelOf(AonL10n l) => switch (this) {
        VenueCategory.eventVenue => l.venueCatEventVenue,
        VenueCategory.informationPoint => l.venueCatInformationPoint,
        VenueCategory.registration => l.venueCatRegistration,
        VenueCategory.toilets => l.venueCatToilets,
        VenueCategory.firstAid => l.venueCatFirstAid,
        VenueCategory.foodAndDrink => l.venueCatFoodAndDrink,
        VenueCategory.parking => l.venueCatParking,
        VenueCategory.metro => l.venueCatMetro,
        VenueCategory.other => l.venueCatOther,
      };
}

/// Localised subtitles for search results and resolved places.
///
/// A [SearchEntry] carries no pre-rendered subtitle: the venue category is
/// resolved here, in the visitor's language. [ResolvedPlace.subtitle] stays
/// English for the non-venue kinds that have no category to re-resolve.
extension SearchEntryL10n on SearchEntry {
  String? subtitleOf(AonL10n l) => switch (this) {
        VenueEntry(:final venue) => venue.category.labelOf(l),
        BuildingEntry(:final building) => building.code,
      };
}

extension ResolvedPlaceL10n on ResolvedPlace {
  String? subtitleOf(AonL10n l) => venueCategory?.labelOf(l) ?? subtitle;
}
