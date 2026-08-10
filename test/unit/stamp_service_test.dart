import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/services/stamp_service.dart';

void main() {
  const goodCode = 'AON-A-TBC';
  const goodVenue = 'macquarie-theatre';

  group('resolve — manual', () {
    test('valid bare code collects', () {
      final r = StampService.resolve(const StampInput.manual(goodCode), <String>{});
      expect(r, isA<StampCollected>());
      expect((r as StampCollected).venueId, goodVenue);
    });
    test('case/space-insensitive', () {
      expect(
        StampService.resolve(const StampInput.manual('  aon-a-tbc '), <String>{}),
        isA<StampCollected>(),
      );
    });
    test('already collected -> alreadyHave', () {
      expect(
        StampService.resolve(const StampInput.manual(goodCode), {goodVenue}),
        isA<StampAlreadyHave>(),
      );
    });
    test('unknown -> unknown', () {
      expect(
        StampService.resolve(const StampInput.manual('NOPE'), <String>{}),
        isA<StampUnknown>(),
      );
    });
  });

  group('resolve — scan (namespace required)', () {
    test('namespaced QR collects', () {
      expect(
        StampService.resolve(const StampInput.scan('AON2026:$goodCode'), <String>{}),
        isA<StampCollected>(),
      );
    });
    test('un-namespaced QR -> unknown even if token is real', () {
      expect(
        StampService.resolve(const StampInput.scan(goodCode), <String>{}),
        isA<StampUnknown>(),
      );
    });
    test('foreign QR -> unknown', () {
      expect(
        StampService.resolve(
          const StampInput.scan('https://example.com'),
          <String>{},
        ),
        isA<StampUnknown>(),
      );
    });
  });

  group('PassportPolicy', () {
    test('completedCount uses intersection', () {
      expect(PassportPolicy.completedCount({goodVenue, 'stale'}), 1);
    });
    test('isComplete needs all 9', () {
      expect(
        PassportPolicy.isComplete(StampStationsData.stationVenueIds),
        isTrue,
      );
      expect(PassportPolicy.isComplete({goodVenue}), isFalse);
    });
    test('release gate disabled while any placeholder', () {
      expect(
        PassportPolicy.isCollectionEnabled(
          StampStationsData.all,
          isRelease: true,
        ),
        isFalse,
      );
    });
    test('release gate enabled when all confirmed', () {
      final confirmed = [
        for (final s in StampStationsData.all)
          StampStation(
            venueId: s.venueId,
            code: s.code,
            codeConfidence: DataConfidence.confirmed,
          ),
      ];
      expect(
        PassportPolicy.isCollectionEnabled(confirmed, isRelease: true),
        isTrue,
      );
    });
    test('debug always enabled', () {
      expect(
        PassportPolicy.isCollectionEnabled(
          StampStationsData.all,
          isRelease: false,
        ),
        isTrue,
      );
    });
  });
}
