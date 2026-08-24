import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/nearby_list.dart';

/// The compass points at places. It must not look like a list of failures.
///
/// ## The bug this file exists to prevent
///
/// Venues with no confirmed coordinate were appended FLAT into the same list as
/// the live compass targets. On a phone that meant most of the visible screen
/// was rows reading "Location unknown — see the printed map" — Gymnasium Road,
/// First aid, the shuttle bus, the bus stop — which reads as a broken feature
/// rather than as an honest gap in the source data. Seen on device.
///
/// They are still present (a safety venue must never be silently dropped) but
/// collapsed behind a counted heading, below the targets that actually work.
void main() {
  NearbyTarget target(String key, {double d = 100}) => NearbyTarget(
        placeKey: key,
        title: key,
        kind: PlaceKind.venue,
        lat: -33.77,
        lng: 151.11,
        distanceMeters: d,
        trueBearingDegrees: 45,
        confidence: DataConfidence.confirmed,
      );

  SearchEntry unlocated(String id, String name) =>
      VenueEntry(Venue(id: id, name: name, category: VenueCategory.firstAid));

  Widget app(ProviderContainer c, {Locale? locale, double textScale = 1.0}) =>
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: NearbyList()),
        ),
      );

  ProviderContainer container({
    List<NearbyTarget> targets = const [],
    List<SearchEntry> index = const [],
  }) {
    final c = ProviderContainer(overrides: [
      nearbyTargetsProvider.overrideWithValue(targets),
      searchIndexProvider.overrideWithValue(index),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<AonL10n> en() => AonL10n.delegate.load(const Locale('en'));
  Future<AonL10n> fa() => AonL10n.delegate.load(const Locale('fa'));

  group('confirmed targets are the compass', () {
    testWidgets('a confirmed target is shown as a live, tappable row',
        (t) async {
      final c = container(targets: [target('venue:observatory', d: 412)]);
      await t.pumpWidget(app(c));
      await t.pumpAndSettle();

      expect(find.text('venue:observatory'), findsOneWidget);
      expect(find.textContaining('412'), findsOneWidget,
          reason: 'a live target shows its distance');

      await t.tap(find.text('venue:observatory'));
      await t.pumpAndSettle();
      expect(c.read(compassLockedProvider), 'venue:observatory',
          reason: 'a confirmed target must be selectable');
    });

    testWidgets('unconfirmed places do NOT dominate — they start collapsed',
        (t) async {
      final c = container(
        targets: [target('venue:observatory')],
        index: [
          unlocated('first-aid', 'First aid'),
          unlocated('shuttle', 'Complimentary shuttle bus'),
          unlocated('bus-stop', 'Transport NSW bus stop'),
          unlocated('gym-road', 'Gymnasium Road'),
        ],
      );
      await t.pumpWidget(app(c));
      await t.pumpAndSettle();
      final l = await en();

      // The live target is visible; none of the four unknowns are.
      expect(find.text('venue:observatory'), findsOneWidget);
      for (final name in [
        'First aid',
        'Complimentary shuttle bus',
        'Transport NSW bus stop',
        'Gymnasium Road',
      ]) {
        expect(find.text(name), findsNothing,
            reason: '"$name" should be tucked into the collapsed group');
      }
      // Not a single "Location unknown" row on screen by default.
      expect(find.text(l.compassUnlocatable), findsNothing);
      // But the group announces itself, with a count.
      expect(find.text(l.compassUnconfirmedHeading(4)), findsOneWidget);
    });

    testWidgets('an unconfirmed place is never a live compass target',
        (t) async {
      final c = container(
        targets: const [],
        index: [unlocated('first-aid', 'First aid')],
      );
      await t.pumpWidget(app(c));
      await t.pumpAndSettle();
      final l = await en();

      await t.tap(find.text(l.compassUnconfirmedHeading(1)));
      await t.pumpAndSettle();

      // Present and readable, but disabled — it cannot be locked on to.
      final tile = t.widget<ListTile>(
        find.ancestor(of: find.text('First aid'), matching: find.byType(ListTile)),
      );
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
      await t.tap(find.text('First aid'));
      await t.pumpAndSettle();
      expect(c.read(compassLockedProvider), isNull,
          reason: 'locking onto a place with no coordinate would be a lie');
    });

    testWidgets('it stays discoverable once expanded (safety venues, §0R-4)',
        (t) async {
      final c = container(
        targets: [target('venue:x')],
        index: [unlocated('first-aid', 'First aid')],
      );
      await t.pumpWidget(app(c));
      await t.pumpAndSettle();
      final l = await en();

      await t.tap(find.text(l.compassUnconfirmedHeading(1)));
      await t.pumpAndSettle();
      expect(find.text('First aid'), findsOneWidget);
      expect(find.text(l.compassUnlocatable), findsOneWidget);
    });
  });

  group('empty states are clean', () {
    testWidgets('no targets and no unknowns → one plain message', (t) async {
      final c = container();
      await t.pumpWidget(app(c));
      await t.pumpAndSettle();
      final l = await en();
      expect(find.text(l.compassNothingNearby), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('unknowns but nothing pointable → says so, does not just list '
        'failures', (t) async {
      final c = container(
        targets: const [],
        index: [
          unlocated('first-aid', 'First aid'),
          unlocated('shuttle', 'Shuttle bus'),
        ],
      );
      await t.pumpWidget(app(c));
      await t.pumpAndSettle();
      final l = await en();

      expect(find.text(l.compassNoConfirmedTargets), findsOneWidget,
          reason: 'the screen must explain itself rather than show a wall of '
              '"location unknown" rows');
      expect(find.text('First aid'), findsNothing);
    });
  });

  group('localisation and accessibility', () {
    testWidgets('Persian renders the group in Persian, RTL', (t) async {
      final c = container(
        targets: [target('venue:x')],
        index: [unlocated('first-aid', 'First aid')],
      );
      await t.pumpWidget(app(c, locale: const Locale('fa')));
      await t.pumpAndSettle();
      final l = await fa();

      expect(find.text(l.compassUnconfirmedHeading(1)), findsOneWidget);
      expect(
        Directionality.of(t.element(find.byType(NearbyList))),
        TextDirection.rtl,
      );
      // No English leaked into the Persian build.
      final en_ = await en();
      expect(find.text(en_.compassUnconfirmedHeading(1)), findsNothing);
    });

    testWidgets('Persian expands and shows the Persian unknown-location copy',
        (t) async {
      final c = container(
        index: [unlocated('first-aid', 'First aid')],
      );
      await t.pumpWidget(app(c, locale: const Locale('fa')));
      await t.pumpAndSettle();
      final l = await fa();
      await t.tap(find.text(l.compassUnconfirmedHeading(1)));
      await t.pumpAndSettle();
      expect(find.text(l.compassUnlocatable), findsOneWidget);
    });

    testWidgets('survives 200% text without overflowing', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);

      final c = container(
        targets: [target('venue:observatory', d: 412)],
        index: [
          unlocated('first-aid', 'First aid'),
          unlocated('shuttle', 'Complimentary shuttle bus'),
        ],
      );
      await t.pumpWidget(app(c, textScale: 2.0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);

      final l = await en();
      await t.tap(find.text(l.compassUnconfirmedHeading(2)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'expanded group overflowed at 2x');
    });

    testWidgets('Persian at 200% text also survives', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);

      final c = container(
        targets: [target('venue:x')],
        index: [unlocated('first-aid', 'First aid')],
      );
      await t.pumpWidget(app(c, locale: const Locale('fa'), textScale: 2.0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
