import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/map_config.dart';

List<SearchEntry> _index() => [
      BuildingEntry(
        // BuildingEntry(this.building) is POSITIONAL — search_entry.dart:32.
        const Building(
          id: 'E7A',
          // `code` is REQUIRED — building.dart:18.
          code: 'E7A',
          name: 'Observatory',
          latitude: -33.7738,
          longitude: 151.1126,
        ),
      ),
    ];

/// App Review, Cupertino.
const _cupertino = LatLng(37.3349, -122.0090);

void main() {
  test('an on-campus fix still sees campus targets', () {
    final targets = nearestTargets(const LatLng(-33.7737, 151.1134), _index());
    expect(targets, isNotEmpty);
  });

  test('a Cupertino fix sees nothing rather than a 12,000 km bearing', () {
    expect(nearestTargets(_cupertino, _index()), isEmpty,
        reason: 'targets beyond the campus radius are not "nearby" in any '
            'sense a compass arrow can express honestly');
  });

  test('the ceiling defaults to the existing campus radius', () {
    // Just outside the radius on the same meridian (~3.3 km).
    const far = LatLng(-33.7737 + 0.03, 151.1134);
    expect(nearestTargets(far, _index()), isEmpty);
    expect(
      nearestTargets(far, _index(),
          maxDistanceMeters: MapConfig.locationCampusRadiusMeters * 100),
      isNotEmpty,
      reason: 'the bound must be a parameter, not a hard-coded rule',
    );
  });

  test('the compass empty state is reachable from off campus', () async {
    // Before the ceiling, targets was never empty, so nearby_list.dart:36's
    // existing copy was unreachable. The ceiling is what makes it fire.
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(l.compassNothingNearby.trim(), isNotEmpty);
    expect(nearestTargets(_cupertino, _index()), isEmpty,
        reason: 'an empty target list is what makes NearbyList render it');
  });
}
