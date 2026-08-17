import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/embedded_map.dart';

class _FakeSurface implements EmbeddedMapSurface {
  GeoBounds? seenBounds;
  @override
  Widget build({
    required GeoBounds bounds,
    required (double, double) origin,
    required (double, double) destination,
    required List<(double, double)> route,
  }) {
    seenBounds = bounds;
    return const SizedBox(key: Key('fake-surface'));
  }
}

void main() {
  testWidgets(
    'EmbeddedMap builds with a fake surface (no platform view) and passes the fitted bounds',
    (t) async {
      final fake = _FakeSurface();
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: EmbeddedMap(
            origin: const (-33.80, 151.10),
            destination: const (-33.78, 151.14),
            route: const [(-33.79, 151.20), (-33.82, 151.12)],
            surface: fake,
          ),
        ),
      );
      expect(find.byKey(const Key('fake-surface')), findsOneWidget);
      expect(t.takeException(), isNull);
      // The widget computed bounds over origin ∪ destination ∪ route and handed
      // them to the surface — extremes come from the route points.
      expect(fake.seenBounds!.southwest.$1, closeTo(-33.82, 1e-9));
      expect(fake.seenBounds!.northeast.$2, closeTo(151.20, 1e-9));
    },
  );
}
