import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/nearby_list.dart';

/// The compass nearby list must clear the floating tab bar.
///
/// ## The bug this file exists to prevent
///
/// The shell sets `extendBody: true`, so the compass list runs UNDERNEATH the
/// floating glass island — but `NearbyList`'s `ListView` reserved no bottom
/// clearance (every other scroll body uses [AonNavMetrics.clearance]). The last
/// rows — "Complimentary shuttle bus", "Transport NSW bus stop", and the
/// collapsed "location unknown" section — sat behind the island. Seen on device.
void main() {
  const target = NearbyTarget(
    placeKey: 'venue:macquarie-theatre',
    title: 'Macquarie Theatre',
    kind: PlaceKind.venue,
    lat: -33.7737,
    lng: 151.1134,
    distanceMeters: 120,
    trueBearingDegrees: 45,
    confidence: DataConfidence.confirmed,
  );

  Widget host({double bottomInset = 34}) => ProviderScope(
        overrides: [
          nearbyTargetsProvider.overrideWithValue(const [target]),
          searchIndexProvider.overrideWithValue(const <SearchEntry>[]),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
            child: child!,
          ),
          home: const Scaffold(body: NearbyList()),
        ),
      );

  testWidgets('the list reserves clearance for the island AND home indicator',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    final list = t.widget<ListView>(find.byType(ListView));
    final pad = (list.padding as EdgeInsets?)!;
    final ctx = t.element(find.byType(NearbyList));
    final needed = AonNavMetrics.clearance(ctx);

    expect(pad.bottom, greaterThanOrEqualTo(needed),
        reason: 'the last nearby row would sit behind the floating tab bar');
    expect(needed, greaterThan(AonNavMetrics.barHeight));
  });

  testWidgets('the clearance grows with the safe-area inset', (t) async {
    await t.pumpWidget(host(bottomInset: 0));
    await t.pumpAndSettle();
    final flat =
        ((t.widget<ListView>(find.byType(ListView))).padding as EdgeInsets?)!
            .bottom;

    await t.pumpWidget(host(bottomInset: 34));
    await t.pumpAndSettle();
    final notched =
        ((t.widget<ListView>(find.byType(ListView))).padding as EdgeInsets?)!
            .bottom;

    expect(notched - flat, closeTo(34, 0.01),
        reason: 'a home-indicator phone needs more room, not the same');
  });
}
