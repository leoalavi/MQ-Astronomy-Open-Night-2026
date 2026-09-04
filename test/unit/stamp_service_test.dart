import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/services/stamp_service.dart';

void main() {
  const goodCode = 'AON-A-FL3R';
  const goodVenue = 'macquarie-theatre';

  group('resolve — manual', () {
    test('valid bare code collects', () {
      final r = StampService.resolve(
        const StampInput.manual(goodCode),
        <String>{},
      );
      expect(r, isA<StampCollected>());
      expect((r as StampCollected).venueId, goodVenue);
    });
    test('case/space-insensitive', () {
      expect(
        StampService.resolve(
          const StampInput.manual('  aon-a-fl3r '),
          <String>{},
        ),
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
        StampService.resolve(
          const StampInput.scan('AON2026:$goodCode'),
          <String>{},
        ),
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
      // The shipped stations are all confirmed now, so this exercises the
      // policy against a synthetic table: ONE placeholder anywhere is enough
      // to shut the gate for the whole trail.
      final oneUnconfirmed = [
        StampStation(
          venueId: StampStationsData.all.first.venueId,
          code: 'AON-A-TBC',
        ),
        for (final s in StampStationsData.all.skip(1)) s,
      ];
      expect(
        PassportPolicy.isCollectionEnabled(oneUnconfirmed, isRelease: true),
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

  /// The other half of the printed-sign contract.
  ///
  /// `tools/passport/build_station_qr.py` prints `AON2026:<CODE>` on each of
  /// the nine venue signs, reading the codes straight out of
  /// `StampStationsData`. These tests are the app-side guarantee that what the
  /// generator prints is exactly what the scanner accepts — so a sign cannot go
  /// to the printer carrying a payload the app would reject on the night.
  group('printed station signs', () {
    String payloadFor(StampStation s) => 'AON2026:${s.code.toUpperCase()}';

    test('every station QR payload resolves to that station', () {
      for (final s in StampStationsData.all) {
        final r = StampService.resolve(
          StampInput.scan(payloadFor(s)),
          <String>{},
        );
        expect(
          r,
          isA<StampCollected>(),
          reason: '${payloadFor(s)} must stamp ${s.venueId}',
        );
        expect((r as StampCollected).venueId, s.venueId);
      }
    });

    test('every station code is also accepted typed in by hand', () {
      // Manual entry is the accessibility fallback printed on each sign for
      // anyone whose camera will not focus in the dark.
      for (final s in StampStationsData.all) {
        final r = StampService.resolve(
          StampInput.manual(s.code.toLowerCase()),
          <String>{},
        );
        expect((r as StampCollected).venueId, s.venueId);
      }
    });

    test('no two stations share a code', () {
      final codes = StampStationsData.all.map((s) => s.code.toUpperCase());
      expect(codes.toSet().length, StampStationsData.count);
    });

    test('codes avoid characters that are confusable in print or typing', () {
      // 0/O, 1/I, 2/Z, 5/S, 6/G and 8/B are the pairs people mistype off a
      // sign in the dark. The suffix is the only free part of the code.
      final banned = RegExp(r'[012568IOZSGB]');
      for (final s in StampStationsData.all) {
        final suffix = s.code.toUpperCase().split('-').last;
        expect(
          banned.hasMatch(suffix),
          isFalse,
          reason: '${s.code} contains a character that is easy to mistype',
        );
      }
    });

    test('a station sign cannot ship with an unconfirmed code', () {
      // The generator watermarks DRAFT off this same field, and the release
      // gate refuses collection while any station is a placeholder.
      for (final s in StampStationsData.all) {
        expect(
          s.codeConfidence,
          DataConfidence.confirmed,
          reason: '${s.venueId} would print DRAFT and refuse stamps in release',
        );
      }
    });
  });
}
