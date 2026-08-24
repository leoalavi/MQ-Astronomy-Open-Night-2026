import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/timing_labels.dart';

/// The visitor-facing strings that used to be hardcoded English.
void main() {
  final en = AonL10nEn();
  final fa = AonL10nFa();

  group('venue categories', () {
    test('every category has a non-empty name in both languages', () {
      for (final c in VenueCategory.values) {
        expect(c.labelOf(en).trim(), isNotEmpty, reason: '$c in English');
        expect(c.labelOf(fa).trim(), isNotEmpty, reason: '$c in Persian');
      }
    });

    test('English matches the enum label the diagnostics still use', () {
      for (final c in VenueCategory.values) {
        expect(c.labelOf(en), c.label);
      }
    });

    test('Persian is translated, not the English passed through', () {
      // Every one of these is a common noun with a real Persian equivalent, so
      // an untranslated entry is a bug rather than a deliberate brand name.
      for (final c in VenueCategory.values) {
        expect(c.labelOf(fa), isNot(c.labelOf(en)), reason: '$c untranslated');
      }
    });
  });

  group('relative time', () {
    final start = DateTime(2026, 9, 19, 18);

    test('a countdown under a minute reads "now"', () {
      expect(TimeFormat.until(en, start, start.add(const Duration(seconds: 30))),
          'now');
      expect(TimeFormat.until(en, start, start.subtract(const Duration(hours: 1))),
          'now');
    });

    test('minutes, whole hours and hours-plus-minutes each have a form', () {
      expect(TimeFormat.until(en, start, start.add(const Duration(minutes: 12))),
          'in 12 min');
      expect(TimeFormat.until(en, start, start.add(const Duration(hours: 1))),
          'in 1 hr');
      expect(
          TimeFormat.until(
              en, start, start.add(const Duration(hours: 1, minutes: 5))),
          'in 1 hr 5 min');
    });

    test('a running session reports what is left, with no "ends" prefix', () {
      // The badge used to build "ends in 12 min" and then strip the prefix by
      // string surgery — which only ever worked in English.
      expect(
          TimeFormat.remaining(en, start, start.add(const Duration(minutes: 12))),
          'in 12 min');
      expect(TimeFormat.remaining(en, start, start.add(const Duration(seconds: 5))),
          'ending now');
      expect(TimeFormat.remaining(en, start, start.subtract(const Duration(minutes: 1))),
          'ended');
    });

    test('Persian countdowns carry no English and no Western digits', () {
      final texts = <String>[
        TimeFormat.until(fa, start, start.add(const Duration(minutes: 12))),
        TimeFormat.until(fa, start, start.add(const Duration(hours: 1))),
        TimeFormat.until(fa, start, start.add(const Duration(hours: 2, minutes: 5))),
        TimeFormat.remaining(fa, start, start.add(const Duration(minutes: 3))),
        TimeFormat.remaining(fa, start, start.add(const Duration(seconds: 5))),
        TimeFormat.remaining(fa, start, start.subtract(const Duration(minutes: 1))),
        TimeFormat.until(fa, start, start),
      ];
      for (final t in texts) {
        expect(t, isNot(matches(RegExp(r'[A-Za-z]'))), reason: 'English in "$t"');
        expect(t, isNot(matches(RegExp(r'[0-9]'))),
            reason: 'Western digits in "$t"');
      }
    });

    test('the bare duration is shared with the walking-ETA wording', () {
      expect(TimeFormat.duration(en, const Duration(minutes: 6)), '6 min');
      expect(TimeFormat.duration(en, const Duration(minutes: 64)), '1 hr 4 min');
      expect(TimeFormat.duration(en, const Duration(hours: 2)), '2 hr');
    });
  });

  group('search subtitles', () {
    final venue = VenuesData.all.firstWhere(
        (v) => v.category == VenueCategory.eventVenue);

    test('a venue result is subtitled with its category, translated', () {
      final entry = VenueEntry(venue);
      expect(entry.subtitleOf(en), venue.category.labelOf(en));
      expect(entry.subtitleOf(fa), venue.category.labelOf(fa));
      expect(entry.subtitleOf(fa), isNot(entry.subtitleOf(en)));
    });

    test('a resolved venue re-resolves its category rather than shipping it '
        'pre-rendered in English', () {
      const place = ResolvedPlace(
        kind: PlaceKind.venue,
        placeKey: 'venue:x',
        title: 'X',
        subtitle: 'Event venue',
        renderPoint: null,
        routingLat: null,
        routingLng: null,
        venueCategory: VenueCategory.eventVenue,
      );
      expect(place.subtitleOf(en), en.venueCatEventVenue);
      expect(place.subtitleOf(fa), fa.venueCatEventVenue);
    });

    test('a place with no category falls back to its stored subtitle', () {
      const park = ResolvedPlace(
        kind: PlaceKind.venue,
        placeKey: 'parking:west-5',
        title: 'West 5',
        subtitle: null,
        renderPoint: null,
        routingLat: null,
        routingLng: null,
      );
      expect(park.subtitleOf(fa), isNull);

      const building = ResolvedPlace(
        kind: PlaceKind.building,
        placeKey: 'building:C5C',
        title: 'C5C',
        subtitle: 'C5C',
        renderPoint: CampusMapPoint(LatLng(0, 0)),
        routingLat: null,
        routingLng: null,
      );
      expect(building.subtitleOf(fa), 'C5C');
    });
  });
}
