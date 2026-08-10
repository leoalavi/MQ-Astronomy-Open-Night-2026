import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/event_info.dart';

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

  Duration get duration => endsAt.difference(startsAt);

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
        terminology: const EventTerminology(
          // "My Night", not "Your Day" — the Open Day vocabulary reads as a
          // mistake at an event that starts at 4pm and ends at 10pm.
          myPlan: 'My Night',
          // Tab-bar length. "My Night" clips to "Ni" in a five-tab bar on a
          // 375pt phone; the star icon carries the rest of the meaning.
          myPlanShort: 'Night',
          myPlanEmpty: 'Your night is empty',
          laterLabel: 'Later tonight',
          programLabel: 'Program',
          eventPeriod: 'tonight',
        ),
        quickAccess: const [
          // Every one of these is backed by the official map legend or
          // programme. Nothing here is invented — see docs/data-sources.md.
          QuickAccessItem(
            id: 'telescopes',
            label: 'Telescopes',
            venueId: 'astronomical-observatory',
          ),
          QuickAccessItem(
            id: 'planetariums',
            label: 'Planetariums',
            venueId: 'sport-and-aquatic-centre',
          ),
          QuickAccessItem(
            id: 'talks',
            label: 'Talks',
            venueId: '14-sir-christopher-ondaatje-avenue',
          ),
          QuickAccessItem(
            id: 'kids',
            label: 'Kids’ activities',
            venueId: '1-central-courtyard',
          ),
          QuickAccessItem(
            id: 'food',
            label: 'Food and drink',
            venueId: 'food-and-drink',
          ),
          QuickAccessItem(
            id: 'toilets',
            label: 'Toilets',
            venueId: 'toilets-1-central-courtyard',
          ),
          QuickAccessItem(
            id: 'first-aid',
            label: 'First aid',
            venueId: 'first-aid',
          ),
          QuickAccessItem(
            id: 'parking',
            label: 'Parking',
            venueId: null,
          ),
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
  terminology: EventTerminology(
    myPlan: 'Your Day',        // daytime event -> day vocabulary
    laterLabel: 'Later today',
    eventPeriod: 'today',
  ),
  defaultThemeMode: AppThemeMode.system,   // daytime -> follow the OS
  features: EventFeatures(scan: true, stamps: true),
)''';
}

/// Event-specific vocabulary.
///
/// Reusable widgets read these instead of hardcoding copy. The set is
/// deliberately short: only words that would be *wrong* at another event.
@immutable
class EventTerminology {
  const EventTerminology({
    required this.myPlan,
    required this.myPlanShort,
    required this.myPlanEmpty,
    required this.laterLabel,
    required this.programLabel,
    required this.eventPeriod,
  });

  /// 'My Night' / 'Your Day'.
  final String myPlan;

  /// Tab-bar length version of [myPlan].
  final String myPlanShort;

  /// Empty-state headline for the plan screen.
  final String myPlanEmpty;

  /// 'Later tonight' / 'Later today'.
  final String laterLabel;

  /// 'Program' / 'Sessions'.
  final String programLabel;

  /// Fits into "…on {eventPeriod}" — 'tonight' / 'today'.
  final String eventPeriod;
}

/// A Home-screen shortcut.
///
/// [venueId] is a **stable venue identifier**, never a display string — the
/// same rule the map and AR layers follow. `null` means the shortcut routes
/// somewhere other than a venue (parking opens the wayfinding planner).
@immutable
class QuickAccessItem {
  const QuickAccessItem({
    required this.id,
    required this.label,
    required this.venueId,
  });

  final String id;
  final String label;
  final String? venueId;
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
final eventConfigProvider =
    Provider<EventConfig>((ref) => EventConfig.astronomyOpenNight);

/// Convenience accessors, so widgets don't repeat `.terminology` chains.
final terminologyProvider =
    Provider<EventTerminology>((ref) => ref.watch(eventConfigProvider).terminology);

final featuresProvider =
    Provider<EventFeatures>((ref) => ref.watch(eventConfigProvider).features);
