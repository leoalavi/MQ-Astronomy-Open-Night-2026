import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_preview.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';

/// App Review guideline 2.3.1(a) forbids dormant functionality: a feature the
/// app ships but a reviewer cannot reach is grounds for rejection. While the
/// nine station codes were `AON-*-TBC` placeholders every release build
/// disabled passport collection, so the whole stamp rally was unreachable —
/// the screen just said "opens on event night".
///
/// The real codes have since landed, so the domain gate now opens on its own
/// and preview is no longer load-bearing for review. It is kept because it is
/// still the only way to try the rally away from the venue signs, and because
/// these tests are what guarantee it can only ever *open* the gate, never
/// close one that is already open.
///
/// `passportPreviewProvider` deliberately mirrors [PreviewLocationService]'s
/// design: a first-class, user-visible control in Settings rather than a hidden
/// review switch, session-only so it can never silently mislead a returning
/// visitor.
void main() {
  group('passport preview mode', () {
    test('is off by default — a normal launch is unchanged', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(passportPreviewProvider), isFalse);
    });

    test('turning it on enables collection even with the domain gate shut', () {
      final c = ProviderContainer(
        overrides: [
          // Force the domain gate CLOSED, exactly as a release build does
          // while any station code is still a placeholder.
          releaseCollectionEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);

      expect(
        c.read(passportCollectionEnabledProvider),
        isFalse,
        reason: 'gate shut before preview is engaged',
      );

      c.read(passportPreviewProvider.notifier).set(true);

      expect(
        c.read(passportCollectionEnabledProvider),
        isTrue,
        reason: 'preview must make the rally reachable for App Review',
      );
    });

    test('a reviewer can actually collect a stamp in preview', () {
      final c = ProviderContainer(
        overrides: [
          releaseCollectionEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);

      final code = StampStationsData.all.first.code;

      // Gate shut: the capture is refused.
      expect(
        c.read(passportProvider.notifier).collect(ManualInput(code)).result,
        isA<StampDisabled>(),
      );

      c.read(passportPreviewProvider.notifier).set(true);

      // Gate open: the same code now stamps.
      final outcome =
          c.read(passportProvider.notifier).collect(ManualInput(code));
      expect(outcome.result, isA<StampCollected>());
      expect(c.read(passportProvider).count, 1);
    });

    test('never weakens the gate — turning preview off closes it again', () {
      final c = ProviderContainer(
        overrides: [
          releaseCollectionEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);

      final notifier = c.read(passportPreviewProvider.notifier);
      notifier.set(true);
      expect(c.read(passportCollectionEnabledProvider), isTrue);

      notifier.set(false);
      expect(c.read(passportCollectionEnabledProvider), isFalse);
    });

    test('preview cannot disable a gate that is already open', () {
      final c = ProviderContainer(
        overrides: [
          releaseCollectionEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(passportCollectionEnabledProvider), isTrue);
      c.read(passportPreviewProvider.notifier).set(false);
      expect(c.read(passportCollectionEnabledProvider), isTrue);
    });

    test(
      'the shipped codes are real, so the release gate is open on its own',
      () {
        // This canary used to assert the opposite: while every station code was
        // an `AON-*-TBC` placeholder the gate stayed shut and preview was the
        // only way in. The real codes have landed, so it now guards the other
        // direction — reintroduce a placeholder and the rally silently stops
        // working on the night, which is exactly what must not happen quietly.
        expect(
          PassportPolicy.isCollectionEnabled(
            StampStationsData.all,
            isRelease: true,
          ),
          isTrue,
          reason: 'a station code has gone back to placeholder — release '
              'builds will refuse every stamp on the night',
        );
        expect(
          StampStationsData.all.every((s) => s.codeConfidence.isReliable),
          isTrue,
        );
      },
    );
  });
}
