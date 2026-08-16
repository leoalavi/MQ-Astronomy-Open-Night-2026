import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';

void main() {
  test('registry is exactly the four thematic variants', () {
    expect(CampusVariantsData.all.map((v) => v.variant).toSet(), {
      CampusMapVariant.parking,
      CampusMapVariant.accessibility,
      CampusMapVariant.water,
      CampusMapVariant.permits,
    });
    expect(CampusMapVariant.base,
        isNot(isIn(CampusVariantsData.all.map((v) => v.variant))));
  });

  test('registry covers every non-base enum value (no silent drift)', () {
    // assetFor() falls back to base for an unmatched enum. If someone adds a
    // CampusMapVariant and forgets the registry, that new value would quietly
    // render the base map. This makes the omission fail LOUDLY instead.
    final registered = CampusVariantsData.all.map((v) => v.variant).toSet();
    final expected = CampusMapVariant.values
        .where((v) => v != CampusMapVariant.base)
        .toSet();
    expect(registered, expected,
        reason:
            'a CampusMapVariant has no registry row → assetFor silently uses base');
  });

  test('eventVisible is the three public variants (permits hidden)', () {
    expect(CampusVariantsData.eventVisible.map((v) => v.variant), [
      CampusMapVariant.parking,
      CampusMapVariant.accessibility,
      CampusMapVariant.water,
    ]);
  });

  test('content-validity gate: eventVisible ⇒ contentApproved (must-fix #6)', () {
    for (final v in CampusVariantsData.all) {
      if (v.eventVisible) {
        expect(v.contentApproved, isTrue,
            reason: '${v.variant} is event-visible without approval');
      }
    }
  });

  test('every asset is under assets/maps/ and ends _dark.png', () {
    for (final v in CampusVariantsData.all) {
      expect(v.assetPath, startsWith('assets/maps/'));
      expect(v.assetPath, endsWith('_dark.png'));
    }
    expect(CampusVariantsData.baseAsset, 'assets/maps/mqcampus_dark.png');
  });

  test('assetFor is total: base → baseAsset, water → water asset', () {
    expect(CampusVariantsData.assetFor(CampusMapVariant.base),
        CampusVariantsData.baseAsset);
    expect(CampusVariantsData.assetFor(CampusMapVariant.water),
        'assets/maps/overlay_water_dark.png');
  });

  test('byVariant returns the row, null for base', () {
    // Compare Color objects directly — Color.value is @Deprecated (would flag
    // `flutter analyze`, which check.sh gates on). Color(int) ctor is fine.
    expect(CampusVariantsData.byVariant(CampusMapVariant.parking)!.swatch,
        const Color(0xFF3B82F6));
    expect(CampusVariantsData.byVariant(CampusMapVariant.base), isNull);
  });
}
