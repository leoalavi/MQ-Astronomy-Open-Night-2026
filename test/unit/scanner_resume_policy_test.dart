import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/passport_scanner_view.dart';

/// Android 16 emulator, 2026-09-05: declining the camera dialog fired
/// `inactive → resumed`, and the scanner restarted on every resume, so the
/// visitor was asked a SECOND time immediately after tapping "Don't allow"
/// (which on Android 11+ also spends the ask-again allowance). iOS never
/// showed it because iOS only ever prompts once. This pins the rule.
void main() {
  test('a resume after THIS view stopped the camera for the background '
      'restarts it', () {
    expect(
      shouldRestartScannerOnResume(
          permissionDenied: false,
          returningFromSettings: false,
          stoppedForBackground: true),
      isTrue,
    );
  });

  test('the resume caused by the OS dialog itself (nothing was stopped) '
      'must not start a second request — start() does not throw on refusal', () {
    expect(
      shouldRestartScannerOnResume(
          permissionDenied: false, returningFromSettings: false),
      isFalse,
    );
  });

  test('the resume right after "Don\'t allow" must NOT re-prompt', () {
    expect(
      shouldRestartScannerOnResume(
          permissionDenied: true, returningFromSettings: false),
      isFalse,
    );
  });

  test('coming back from app Settings after a refusal retries once', () {
    expect(
      shouldRestartScannerOnResume(
          permissionDenied: true, returningFromSettings: true),
      isTrue,
    );
  });

  test('a resume while the first start (and its dialog) is still pending '
      'never issues a second request', () {
    expect(
      shouldRestartScannerOnResume(
          permissionDenied: false,
          returningFromSettings: false,
          startInFlight: true),
      isFalse,
    );
  });
}
