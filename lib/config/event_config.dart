import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';

/// Per-event configuration.
///
/// ## Why this exists
///
/// This product family runs more than one event off one codebase: Open Day
/// (served today by the MQ Journey app) and Astronomy Open Night. The failure
/// mode we are avoiding is the obvious one — reusable widgets that say
/// "Astronomy" or "night" in their source, which then have to be forked or
/// string-replaced for the next event.
///
/// So: **reusable widgets read terminology and feature flags from here.**
/// Event-specific screens may still be event-specific; a `HomeScreen` designed
/// around a six-hour night event does not have to pretend to be generic.
///
/// ## Deliberately small
///
/// This is a configuration object, not a plugin framework. It holds the things
/// that genuinely differ between two events of the same shape — name, dates,
/// vocabulary, hero, quick access, feature flags. It does **not** attempt to
/// abstract layout, navigation or data loading; over-generalising those would
/// cost more than maintaining a second screen.
///
/// Only [astronomyOpenNight] is shipped. [openDayShape] documents the second
/// config's shape without pretending we have Open Day's content here — see
/// `docs/event-config.md`.
@immutable
class EventConfig {
  const EventConfig({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tagline,
    required this.host,
    required this.faculty,
    required this.startsAt,
    required this.endsAt,
    required this.heroAsset,
    required this.heroCredit,
    required this.terminology,
    required this.quickAccess,
    required this.features,
    this.defaultThemeMode = AppThemeMode.dark,
    this.privacyPolicyUrl,
  });

  /// Stable identifier. Used for persistence keys, so changing it orphans
  /// saved data — treat it as permanent.
  final String id;

  /// Full display name, e.g. 'Astronomy Open Night'.
  final String name;

  /// Compact name for tight spaces, e.g. 'Astronomy'.
  final String shortName;

  /// One line the visitor reads first. Must come from official material.
  final String tagline;

  final String host;
  final String faculty;

  final DateTime startsAt;
  final DateTime endsAt;

  final String heroAsset;

  /// Required attribution for [heroAsset]. Non-null on purpose — a hero image
  /// without a credit is a licensing problem waiting to happen.
  final String heroCredit;

  final EventTerminology terminology;

  /// Home-screen shortcuts. Ordered; the first four get prime position.
  final List<QuickAccessItem> quickAccess;

  final EventFeatures features;

  /// What the app opens as before the user chooses. Astronomy defaults to dark
  /// because the event is after sunset; the user can still override it.
  final AppThemeMode defaultThemeMode;

  /// The production, publicly-reachable HTTPS Privacy Policy URL (App Store /
  /// Play require the policy to be accessible from inside the app). **Null until
  /// Macquarie hosts the page** — do NOT guess an `mq.edu.au` path (release
  /// blocker B7). When null, the Settings Privacy Policy row is hidden rather
  /// than offering a dead link; setting this one value activates it.
  final String? privacyPolicyUrl;

  Duration get duration => endsAt.difference(startsAt);

  EventConfig copyWith({String? privacyPolicyUrl}) => EventConfig(
        id: id,
        name: name,
        shortName: shortName,
        tagline: tagline,
        host: host,
        faculty: faculty,
        startsAt: startsAt,
        endsAt: endsAt,
        heroAsset: heroAsset,
        heroCredit: heroCredit,
        terminology: terminology,
        quickAccess: quickAccess,
        features: features,
        defaultThemeMode: defaultThemeMode,
        privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      );

  // ══════════════════════════════════════════════════════
  // Astronomy Open Night 2026 — the shipped configuration
  // ══════════════════════════════════════════════════════
  static EventConfig get astronomyOpenNight => EventConfig(
    id: 'aon-2026',
    name: EventInfo.name,
    shortName: 'Astronomy',
    // Source: official programme, page 2 short-talks blurb — "designed for
    // the general public and amateur astronomers".
    tagline: 'A night of telescopes, talks and science for everyone.',
    host: EventInfo.host,
    faculty: EventInfo.faculty,
    startsAt: EventInfo.startsAt,
    endsAt: EventInfo.endsAt,
    heroAsset: 'assets/images/hero_deep_triangulum_galaxy.jpg',
    heroCredit: 'A Deep Triangulum Galaxy — Aleix Roig, 2026',
    // Night vocabulary — "My Night", not "Your Day". The actual words
    // come from the translation files.
    terminology: const EventTerminology(EventVocabulary.night),
    quickAccess: const [
      // Every one of these is backed by the official map legend or
      // programme. Nothing here is invented — see docs/data-sources.md.
      QuickAccessItem(id: 'telescopes', venueId: 'astronomical-observatory'),
      QuickAccessItem(id: 'planetariums', venueId: 'sport-and-aquatic-centre'),
      QuickAccessItem(
        id: 'talks',
        venueId: '14-sir-christopher-ondaatje-avenue',
      ),
      QuickAccessItem(id: 'kids', venueId: '1-central-courtyard'),
      QuickAccessItem(id: 'food', venueId: 'food-and-drink'),
      QuickAccessItem(id: 'toilets', venueId: 'toilets-1-central-courtyard'),
      QuickAccessItem(id: 'first-aid', venueId: 'first-aid'),
      QuickAccessItem(id: 'parking', venueId: null),
    ],
    features: const EventFeatures(
      panorama: true,
      wayfinding: true,
      myPlan: true,
      // Off until Raouf defines the Astronomy QR payload → venue contract.
      // See docs/backend-integration.md.
      scan: false,
      stamps: false,
    ),
  );

  /// The shape a second event's config would take.
  ///
  /// **Not wired up.** Open Day is served by the MQ Journey app; this exists so
  /// the abstraction above is demonstrably not Astronomy-shaped, and so the
  /// next event has a starting point. Content would come from that event's own
  /// materials — nothing here is real Open Day data.
  @visibleForTesting
  static const String openDayShape = '''
EventConfig(
  id: 'open-day-YYYY',
  name: 'Open Day',
  shortName: 'Open Day',
  terminology: EventTerminology(EventVocabulary.day),
  defaultThemeMode: AppThemeMode.system,   // daytime -> follow the OS
  features: EventFeatures(scan: true, stamps: true),
)''';
}

/// Which vocabulary an event speaks.
///
/// Astronomy Open Night runs 4pm–10pm, so it says "My Night" and "Later
/// tonight". A daytime event would say "Your Day" and "Later today". The
/// choice belongs to the event config; the *words* belong to the translation
/// files — which is why this is an enum rather than a bag of English strings.
enum EventVocabulary { night, day }

/// Resolves event vocabulary into localised copy.
///
/// Deliberately a thin resolver over [AonL10n] rather than a store of literal
/// strings: hardcoding "My Night" here would make the config untranslatable,
/// and hardcoding it in widgets would make it un-configurable. This is the one
/// place both concerns meet.
@immutable
class EventTerminology {
  const EventTerminology(this.vocabulary);

  final EventVocabulary vocabulary;

  /// 'My Night' / 'Your Day'.
  String myPlan(AonL10n l) => switch (vocabulary) {
    EventVocabulary.night => l.myNight,
    // Open Day is not shipped from this repo; if it ever is, add a
    // `yourDay` key and return it here. Falling back keeps the type total.
    EventVocabulary.day => l.myNight,
  };

  /// Tab-bar length version of [myPlan].
  String myPlanShort(AonL10n l) => l.tabMyNight;

  /// Empty-state headline for the plan screen.
  String myPlanEmpty(AonL10n l) => l.myNightEmptyTitle;

  /// 'Later tonight' / 'Later today'.
  /// Heading for the "hasn't started yet" bucket.
  ///
  /// [beforeEventDay] switches it away from tonight-relative wording, for the
  /// same reason as [EventTimingL10n.labelOf]: a month out, everything is in
  /// this bucket and "Later tonight" would be a false claim.
  String laterLabel(AonL10n l, {bool beforeEventDay = false}) =>
      beforeEventDay ? l.timingOnTheNight : l.timingLaterTonight;

  String programLabel(AonL10n l) => l.tabProgram;

  /// Fits into "see the whole {period}" — 'tonight' / 'today'.
  String eventPeriod(AonL10n l) => l.programTonight.toLowerCase();
}

/// A Home-screen shortcut.
///
/// [venueId] is a **stable venue identifier**, never a display string — the
/// same rule the map and AR layers follow. `null` means the shortcut routes
/// somewhere other than a venue (parking opens the wayfinding planner).
@immutable
class QuickAccessItem {
  const QuickAccessItem({required this.id, required this.venueId});

  /// Stable identifier. Also selects the localised label — the words live in
  /// the ARB files, not here, so Quick Access is not English-only in Persian.
  final String id;

  final String? venueId;

  /// The visitor-facing label for this shortcut.
  ///
  /// A switch rather than a map so adding a shortcut without a translation is
  /// a compile error instead of a silent English string on a Persian screen.
  String label(AonL10n l) => switch (id) {
    'telescopes' => l.quickAccessTelescopes,
    'planetariums' => l.quickAccessPlanetariums,
    'talks' => l.quickAccessTalks,
    'kids' => l.quickAccessKids,
    'food' => l.quickAccessFood,
    'toilets' => l.quickAccessToilets,
    'first-aid' => l.quickAccessFirstAid,
    'parking' => l.quickAccessParking,
    _ => id,
  };
}

/// Per-event feature switches.
///
/// A flag that is `false` means the feature is **hidden**, not stubbed. The
/// brief is explicit that dead UI is worse than absent UI.
@immutable
class EventFeatures {
  const EventFeatures({
    required this.panorama,
    required this.wayfinding,
    required this.myPlan,
    required this.scan,
    required this.stamps,
  });

  /// 360°/indoor viewer (Raouf's panorama stack).
  final bool panorama;

  /// Parking → venue walking directions.
  final bool wayfinding;

  /// Saved-itinerary feature ("My Night").
  final bool myPlan;

  /// QR scanning. Off for Astronomy pending the payload contract.
  final bool scan;

  /// Open Day stamp trail / gamification.
  final bool stamps;
}

/// Appearance preference. Mirrors [ThemeMode] but is ours to persist, so the
/// stored value never depends on a Flutter enum's index ordering.
enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static AppThemeMode fromName(String? name) {
    for (final v in AppThemeMode.values) {
      if (v.name == name) return v;
    }
    return AppThemeMode.dark;
  }
}

/// The active event.
///
/// Overridable in tests and — if this codebase ever hosts a second event — the
/// single place a build would switch configuration.
final eventConfigProvider = Provider<EventConfig>(
  (ref) => EventConfig.astronomyOpenNight,
);

/// Convenience accessors, so widgets don't repeat `.terminology` chains.
final terminologyProvider = Provider<EventTerminology>(
  (ref) => ref.watch(eventConfigProvider).terminology,
);

final featuresProvider = Provider<EventFeatures>(
  (ref) => ref.watch(eventConfigProvider).features,
);
