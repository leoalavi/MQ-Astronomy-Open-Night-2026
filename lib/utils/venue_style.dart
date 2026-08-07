import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
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
  static Color colorFor(VenueCategory category) => switch (category) {
        VenueCategory.eventVenue => AonColors.mapVenue,
        VenueCategory.registration => AonColors.amberBright,
        VenueCategory.informationPoint => AonColors.mapFacility,
        VenueCategory.toilets => AonColors.mapFacility,
        VenueCategory.firstAid => AonColors.error,
        VenueCategory.foodAndDrink => AonColors.nebula,
        VenueCategory.parking => AonColors.mapParking,
        VenueCategory.metro => AonColors.mapTransport,
        VenueCategory.shuttleStop => AonColors.mapTransport,
        VenueCategory.busStop => AonColors.mapTransport,
        VenueCategory.other => AonColors.contentTertiary,
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
        VenueCategory.shuttleStop => Icons.directions_bus_rounded,
        VenueCategory.busStop => Icons.directions_bus_filled_rounded,
        VenueCategory.other => Icons.place_rounded,
      };

  static IconData iconForEventCategory(EventCategory category) =>
      switch (category) {
        EventCategory.activity => Icons.science_rounded,
        EventCategory.shortTalk => Icons.record_voice_over_rounded,
        EventCategory.keynote => Icons.auto_awesome_rounded,
        EventCategory.featuredPresentation => Icons.star_rounded,
      };

  static Color colorForEventCategory(EventCategory category) =>
      switch (category) {
        EventCategory.activity => AonColors.stellar,
        EventCategory.shortTalk => AonColors.mapTransport,
        EventCategory.keynote => AonColors.amber,
        EventCategory.featuredPresentation => AonColors.nebula,
      };
}
