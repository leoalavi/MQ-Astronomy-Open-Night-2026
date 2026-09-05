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

class _PassportScannerViewState extends State<PassportScannerView>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  final ScanGate _gate = ScanGate();

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
    if (c == null) return;
    try {
      await c.start(); // requests camera permission on first use, then streams
    } catch (_) {
      // Already-started, or a hard failure (denied / no camera). A real failure
      // surfaces through MobileScanner.errorBuilder; nothing to do here beyond
      // not leaking an unhandled rejection.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Back from the permission dialog or Settings — a just-granted
        // permission now takes effect with no extra tap.
        unawaited(_start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
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
                          try {
                            await Geolocator.openAppSettings();
                          } catch (_) {
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
