import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/scan_gate.dart';

/// Camera QR adapter.
///
/// Owns the [MobileScannerController] and starts it as soon as it is mounted, so
/// the camera — and, on first use, the OS permission prompt — come up without a
/// second tap. Starting is explicit (`autoStart: false` + [start]) rather than
/// left to the widget, and a lifecycle observer re-starts on resume so a
/// permission the visitor granted in the system dialog (or in Settings) takes
/// effect the moment they return. Emits one decode per capture (§7.1, via
/// [ScanGate]), offers a state-reflecting torch, and routes a hard camera error
/// (no camera) to [onError]. On web it never constructs the scanner (design
/// §5.1) — manual entry is the web path.
class PassportScannerView extends StatefulWidget {
  const PassportScannerView({required this.onDecoded, this.onError, super.key});

  final void Function(String decoded) onDecoded;
  final VoidCallback? onError;

  @override
  State<PassportScannerView> createState() => _PassportScannerViewState();
}

/// Whether a `resumed` lifecycle event should restart the camera.
///
/// Pure, so the rule is unit-testable without a camera. The trap it closes
/// (Android 16 emulator, 2026-09-05): declining the OS camera dialog fires
/// `inactive → resumed`, and an unconditional restart on resume re-requested
/// the permission — a second dialog straight after the first "Don't allow",
/// which on Android 11+ also burns the "ask again" allowance. After a denial
/// the only resume that should retry is the one coming back from the app's
/// Settings page (the visitor may have granted it there); everything else
/// stays on the honest "Camera unavailable — enter the code" state.
///
/// The second trap (same emulator): the OS dialog itself takes the app
/// through `inactive → resumed` BEFORE the pending `start()` has learned the
/// answer, so a restart on that resume issues a second request while the
/// first is still in flight. A resume during an in-flight start never
/// restarts — the pending call will resolve on its own.
///
/// The third finding (adb-injected denial, permission flags `USER_SET`, and
/// the dialog came straight back): `MobileScannerController.start()` does NOT
/// throw on a refusal — it records the error in `controller.value` and
/// completes normally — so "was it denied?" cannot be inferred from an
/// exception. The rule is therefore inverted: a resume restarts the camera
/// ONLY when this view itself stopped it for the background
/// ([stoppedForBackground]) or the visitor is returning from app Settings.
/// The OS dialog's own `inactive → resumed` round-trip stops nothing, so it
/// restarts nothing.
bool shouldRestartScannerOnResume({
  required bool permissionDenied,
  required bool returningFromSettings,
  bool startInFlight = false,
  bool stoppedForBackground = false,
}) {
  if (startInFlight) return false;
  if (returningFromSettings) return true;
  if (permissionDenied) return false;
  return stoppedForBackground;
}

class _PassportScannerViewState extends State<PassportScannerView>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  final ScanGate _gate = ScanGate();

  /// Set when the last start attempt was refused for lack of permission.
  bool _permissionDenied = false;

  /// True while a `start()` (and possibly its OS permission dialog) is
  /// pending; a resume during that window must not start a second one.
  bool _starting = false;

  /// True after THIS view stopped the camera for paused/hidden/detached, so
  /// the matching resume knows there is something to restart.
  bool _stoppedForBackground = false;

  /// Set when the visitor taps "Open app settings", so the resume that
  /// follows is allowed to retry once.
  bool _returningFromSettings = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // autoStart:false — we drive start/stop ourselves so the permission
      // request and the app lifecycle stay in step (7.x guidance).
      _controller = MobileScannerController(autoStart: false);
      WidgetsBinding.instance.addObserver(this);
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final c = _controller;
    if (c == null || _starting) return;
    _starting = true;
    try {
      await c.start(); // requests camera permission on first use, then streams
      // start() completes normally on a refusal and parks the error in
      // `value`; read it back rather than trusting the absence of a throw.
      _permissionDenied =
          c.value.error?.errorCode == MobileScannerErrorCode.permissionDenied;
    } on MobileScannerException catch (e) {
      // Remember a permission refusal so the next `resumed` (the dialog
      // closing) does not immediately ask again. Other failures (already
      // started, no camera) surface through MobileScanner.errorBuilder.
      if (e.errorCode == MobileScannerErrorCode.permissionDenied) {
        _permissionDenied = true;
      }
    } catch (_) {
      // Nothing to do beyond not leaking an unhandled rejection.
    } finally {
      _starting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Back from the permission dialog or Settings — a just-granted
        // permission takes effect with no extra tap. After a refusal, only
        // the return from Settings retries (see shouldRestartScannerOnResume).
        final retry = shouldRestartScannerOnResume(
          permissionDenied: _permissionDenied,
          returningFromSettings: _returningFromSettings,
          startInFlight: _starting,
          stoppedForBackground: _stoppedForBackground,
        );
        _returningFromSettings = false;
        _stoppedForBackground = false;
        if (retry) unawaited(_start());
      case AppLifecycleState.inactive:
        // Deliberately NOT stopped. `inactive` is what the OS permission
        // dialog (and a pulled-down shade) puts us in; stopping here aborted
        // the pending `start()` with a non-permission error, so the resume
        // that followed restarted it and the visitor got a SECOND camera
        // prompt right after "Don't allow" (Android 16 emulator, 2026-09-05).
        // The camera is released on paused/hidden/detached below.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stoppedForBackground = true;
        unawaited(c.stop().catchError((_) {})); // release camera + torch offstage
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    // dispose() releases the camera AND turns the torch off, so leaving the
    // screen can never strand the flashlight on.
    if (c != null) unawaited(c.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_gate.accept()) return; // debounce: one per capture
    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null) {
      _gate.reset(); // empty frame — stay open for a real code
      return;
    }
    final c = _controller;
    if (c != null) unawaited(c.stop().catchError((_) {}));
    widget.onDecoded(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final c = _controller;
    if (kIsWeb || c == null) {
      return Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Text(
          l.passportScanWebUnavailable,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: MobileScanner(
            controller: c,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              // A real camera error (permission denied, no camera). Do NOT auto-
              // switch to manual — that is exactly the "tap Scan twice" bug when
              // it fired on the transient permission-pending state. Show the
              // reason and offer a one-tap path to manual entry instead.
              return SingleChildScrollView(
                child: Padding(
                padding: const EdgeInsets.all(AonSpacing.space4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.passportScanCameraUnavailable,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (error.errorCode == MobileScannerErrorCode.permissionDenied) ...[
                      const SizedBox(height: AonSpacing.space3),
                      OutlinedButton.icon(
                        onPressed: () async {
                          // The resume after Settings is the one retry a
                          // refusal allows (the visitor may have granted it).
                          _returningFromSettings = true;
                          try {
                            await Geolocator.openAppSettings();
                          } catch (_) {
                            _returningFromSettings = false;
                            // Manual entry remains available if Settings cannot open.
                          }
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(l.passportCameraSettings),
                      ),
                    ],
                    if (widget.onError != null) ...[
                      const SizedBox(height: AonSpacing.space3),
                      OutlinedButton.icon(
                        onPressed: widget.onError,
                        icon: const Icon(Icons.keyboard_rounded),
                        label: Text(l.passportEnterCodeButton),
                      ),
                    ],
                  ],
                ),
                ),
              );
            },
          ),
        ),
        // Torch: reflects ON/OFF, disabled when the device reports no torch, and
        // never throws if a toggle is rejected.
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: c,
          builder: (context, state, _) {
            final torch = state.torchState;
            final unavailable = torch == TorchState.unavailable;
            final on = torch == TorchState.on;
            void toggle() => unawaited(c.toggleTorch().catchError((_) {}));
            return Semantics(
              toggled: on,
              child: on
                  ? FilledButton.tonalIcon(
                      key: const Key('passport-torch'),
                      onPressed: toggle,
                      icon: const Icon(Icons.flashlight_on_rounded),
                      label: Text(l.passportScanTorch),
                    )
                  : TextButton.icon(
                      key: const Key('passport-torch'),
                      onPressed: unavailable ? null : toggle,
                      icon: const Icon(Icons.flashlight_off_rounded),
                      label: Text(l.passportScanTorch),
                    ),
            );
          },
        ),
      ],
    );
  }
}
