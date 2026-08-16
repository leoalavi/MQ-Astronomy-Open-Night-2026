import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';

void main() {
  ProviderContainer harness() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('default is base', () {
    final c = harness();
    expect(c.read(campusVariantProvider), CampusMapVariant.base);
  });

  test('select(parking) → parking', () {
    final c = harness();
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.parking);
    expect(c.read(campusVariantProvider), CampusMapVariant.parking);
  });

  test('exclusive: a second select replaces, never accumulates', () {
    final c = harness();
    final n = c.read(campusVariantProvider.notifier);
    n.select(CampusMapVariant.parking);
    n.select(CampusMapVariant.water);
    expect(c.read(campusVariantProvider), CampusMapVariant.water);
  });

  test('select(base) returns to base', () {
    final c = harness();
    final n = c.read(campusVariantProvider.notifier);
    n.select(CampusMapVariant.water);
    n.select(CampusMapVariant.base);
    expect(c.read(campusVariantProvider), CampusMapVariant.base);
  });

  test('select(null) — RadioGroup deselect sentinel — maps to base', () {
    final c = harness();
    final n = c.read(campusVariantProvider.notifier);
    n.select(CampusMapVariant.parking);
    n.select(null);
    expect(c.read(campusVariantProvider), CampusMapVariant.base);
  });
}
