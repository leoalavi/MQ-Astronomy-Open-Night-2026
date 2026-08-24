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

NearbyTarget _t(String k,
        {double d = 100, DataConfidence c = DataConfidence.confirmed}) =>
    NearbyTarget(
        placeKey: k, title: k, kind: PlaceKind.building, lat: -33.77, lng: 151.11,
        distanceMeters: d, trueBearingDegrees: 45, confidence: c);

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: NearbyList()),
      ),
    );

ProviderContainer _c({List<NearbyTarget> targets = const [], List<SearchEntry> index = const []}) {
  final c = ProviderContainer(overrides: [
    nearbyTargetsProvider.overrideWithValue(targets),
    searchIndexProvider.overrideWithValue(index),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('tapping a row locks that target; distance shown (rounded)', (t) async {
    final c = _c(targets: [_t('building:A', d: 412)]);
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(find.textContaining('412'), findsOneWidget);
    await t.tap(find.text('building:A'));
    await t.pumpAndSettle();
    expect(c.read(compassLockedProvider), 'building:A');
  });

  testWidgets('unlocatable venue → DISABLED "see printed map" row (§0R-4 safety)', (t) async {
    // Still guarantees a safety venue is never silently dropped. It now lives
    // inside the collapsed "no confirmed location" group rather than flat in
    // the main list, so expand that first — the claim is that it is REACHABLE,
    // not that it crowds out the pointable targets.
    final c = _c(index: [VenueEntry(const Venue(id: 'first-aid', name: 'First Aid', category: VenueCategory.firstAid))]);
    await t.pumpWidget(_app(c));
    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.pumpAndSettle();
    await t.tap(find.text(l.compassUnconfirmedHeading(1)));
    await t.pumpAndSettle();
    expect(find.text('First Aid'), findsOneWidget);
    expect(find.text(l.compassUnlocatable), findsOneWidget);
  });

  testWidgets('empty index + no unlocatables → "nothing nearby" (§0-I)', (t) async {
    final c = _c();
    await t.pumpWidget(_app(c));
    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.pumpAndSettle();
    expect(find.text(l.compassNothingNearby), findsOneWidget);
  });

  testWidgets('placeholder-confidence target labelled approximate (§0-B/§0R-13)', (t) async {
    final c = _c(targets: [_t('building:P', c: DataConfidence.placeholder)]);
    await t.pumpWidget(_app(c));
    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.pumpAndSettle();
    expect(find.text(l.compassApproximate), findsOneWidget);
  });
}
