import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/config/qa_mode.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/maps_nav_providers.dart';

/// Deterministic single-value stub — same approach as `nav_origin_test`. A
/// broadcast controller would race `navOriginProvider`'s `.first` subscription
/// and fall through to its 12-second timeout.
class _StubLoc implements LocationService {
  _StubLoc({required this.grant, this.fix});
  final LocationStatus grant;
  final UserLocationFix? fix;

  @override
  Future<LocationStatus> status() async => grant;
  @override
  Future<LocationStatus> request() async => grant;
  @override
  Stream<UserLocationFix> watch() {
    final f = fix;
    return f == null ? const Stream.empty() : Stream.value(f);
  }

  @override
  Stream<bool> serviceEnabledChanges() => const Stream.empty();
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

/// The QA off-campus flag: what it relaxes, and — more importantly — what it
/// must NOT relax.
///
/// The production rule (campus-only routing) is correct on the night and
/// impossible to test beforehand, because a developer at home is off campus by
/// definition. The flag lifts the geographic gate ONLY. If it ever started
/// lifting walking-only or the Google-only provider rule, the thing it exists to
/// make testable would no longer be the thing that ships.
void main() {
  /// A fix in the Sydney CBD — unambiguously off campus.
  const offCampus = LatLng(-33.8568, 151.2153);
  const onCampus = LatLng(-33.77379, 151.11459);

  Future<NavOrigin> resolveOrigin({
    required bool qaMode,
    required LatLng at,
  }) {
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(_StubLoc(
        grant: LocationStatus.granted,
        fix: UserLocationFix(position: at, accuracyMeters: 10),
      )),
      allowOffCampusTestingProvider.overrideWithValue(qaMode),
    ]);
    addTearDown(c.dispose);
    return c.read(navOriginProvider.future);
  }

  group('the flag is OFF unless deliberately passed', () {
    test('the compile-time default is false', () {
      // A release build that forgets the define must get production behaviour.
      expect(kAllowOffCampusTesting, isFalse,
          reason: 'QA relaxations must never be the default');
    });

    test('the provider mirrors the constant by default', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(allowOffCampusTestingProvider), kAllowOffCampusTesting);
    });

    test('the passport reset tool is off by default too', () {
      expect(kPassportResetTool, isFalse,
          reason: 'a debug build must show the shipped app bar');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(passportResetToolProvider), isFalse);
    });

    test('source notes are off by default', () {
      // The provenance line quotes the programme PDF or Liz's email verbatim,
      // names her, and on Solar system walk printed the internal
      // classification. It is a data-integrity artefact — data_integrity_test
      // requires one on every event — not visitor copy, and it shipped
      // unconditionally until 2026-09-08.
      expect(kShowSourceNotes, isFalse,
          reason: 'attendees would read an internal email quote');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(showSourceNotesProvider), isFalse);
    });
  });

  group('PRODUCTION mode still enforces campus scope', () {
    test('an off-campus origin is refused', () async {
      final origin = await resolveOrigin(qaMode: false, at: offCampus);
      expect(origin, isA<NavOriginOffCampus>(),
          reason: 'the shipping rule must survive the flag existing');
    });

    test('an on-campus origin still routes', () async {
      final origin = await resolveOrigin(qaMode: false, at: onCampus);
      expect(origin, isA<NavOriginOnCampus>());
    });
  });

  group('QA mode allows an off-campus origin', () {
    test('the CBD is accepted as a routing origin', () async {
      final origin = await resolveOrigin(qaMode: true, at: offCampus);
      expect(origin, isA<NavOriginOnCampus>(),
          reason: 'QA mode must let the tester route from where they are');
      final point = (origin as NavOriginOnCampus).point;
      expect(point.$1, closeTo(offCampus.latitude, 1e-9));
      expect(point.$2, closeTo(offCampus.longitude, 1e-9),
          reason: 'the REAL coordinate is used — never snapped to campus');
    });

    test('an on-campus origin is unaffected', () async {
      final origin = await resolveOrigin(qaMode: true, at: onCampus);
      expect(origin, isA<NavOriginOnCampus>());
    });

    test('permission refusal is still refusal — the flag is not a bypass for '
        'everything', () async {
      final c = ProviderContainer(overrides: [
        locationServiceProvider
            .overrideWithValue(_StubLoc(grant: LocationStatus.denied)),
        allowOffCampusTestingProvider.overrideWithValue(true),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(navOriginProvider.future),
          isA<NavOriginUnavailable>());
    });
  });
}
