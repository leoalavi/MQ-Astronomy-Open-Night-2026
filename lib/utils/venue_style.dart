import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/models/venue.dart';

/// Maps domain categories to their visual treatment.
///
/// Kept out of the widgets so a marker on the map, a chip in the filter row
/// and an icon on a detail sheet can never drift apart — there is exactly one
/// place that decides what "parking" looks like.
///
/// Colour is never the *only* channel: every category also has a distinct
/// icon shape, so the map remains usable for colour-blind attendees and under
/// a phone's night-shift filter, which badly distorts hue.
abstract final class VenueStyle {
  /// Colours now depend on the active theme, so the colour lookups take a
  /// [BuildContext]. The icon lookups deliberately do not — an icon is the
  /// same shape in both themes, and that is the point: colour is never the
  /// only channel carrying meaning.
  static Color colorFor(BuildContext context, VenueCategory category) =>
      switch (category) {
        VenueCategory.eventVenue => context.aon.mapVenue,
        VenueCategory.registration => context.aon.accentBright,
        VenueCategory.informationPoint => context.aon.mapFacility,
        VenueCategory.toilets => context.aon.mapFacility,
        VenueCategory.firstAid => context.aon.error,
        VenueCategory.foodAndDrink => context.aon.tertiary,
        VenueCategory.parking => context.aon.mapParking,
        VenueCategory.metro => context.aon.mapTransport,
        VenueCategory.other => context.aon.contentTertiary,
      };

  static IconData iconFor(VenueCategory category) => switch (category) {
        VenueCategory.eventVenue => Icons.stars_rounded,
        VenueCategory.registration => Icons.how_to_reg_rounded,
        VenueCategory.informationPoint => Icons.info_rounded,
        VenueCategory.toilets => Icons.wc_rounded,
        VenueCategory.firstAid => Icons.medical_services_rounded,
        VenueCategory.foodAndDrink => Icons.local_cafe_rounded,
        VenueCategory.parking => Icons.local_parking_rounded,
        VenueCategory.metro => Icons.train_rounded,
        VenueCategory.other => Icons.place_rounded,
      };

  static IconData iconForEventCategory(EventCategory category) =>
      switch (category) {
        EventCategory.activity => Icons.science_rounded,
        EventCategory.shortTalk => Icons.record_voice_over_rounded,
        EventCategory.keynote => Icons.auto_awesome_rounded,
        EventCategory.featuredPresentation => Icons.star_rounded,
      };

  static Color colorForEventCategory(
    BuildContext context,
    EventCategory category,
  ) =>
      switch (category) {
        EventCategory.activity => context.aon.info,
        EventCategory.shortTalk => context.aon.mapTransport,
        EventCategory.keynote => context.aon.accent,
        EventCategory.featuredPresentation => context.aon.tertiary,
      };
}
