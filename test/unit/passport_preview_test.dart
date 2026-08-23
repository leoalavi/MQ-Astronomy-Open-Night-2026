import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_preview.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';

/// App Review guideline 2.3.1(a) forbids dormant functionality: a feature the
/// app ships but a reviewer cannot reach is grounds for rejection. Every
/// release build currently disables passport collection (all nine station codes
/// are `AON-*-TBC`), so the whole stamp rally was unreachable — the screen just
/// said "opens on event night".
///
/// `passportPreviewProvider` is the answer, and it deliberately mirrors
/// [PreviewLocationService]'s design: a first-class, user-visible control in
/// Settings rather than a hidden review switch, session-only so it can never
/// silently mislead a returning visitor.
void main() {
  group('passport preview mode', () {
    test('is off by default — a normal launch is unchanged', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(passportPreviewProvider), isFalse);
    });

    test('turning it on enables collection even when the codes are TBC', () {
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
      'the real codes are still TBC — this is why the gate exists at all',
      () {
        // A canary. When the organisers supply real codes and this flips, the
        // release gate opens on its own and preview stops being load-bearing.
        expect(
          PassportPolicy.isCollectionEnabled(
            StampStationsData.all,
            isRelease: true,
          ),
          isFalse,
          reason: 'if this fails, real stamp codes have landed — good news; '
              'update the release checklist in docs/release/',
        );
      },
    );
  });
}
