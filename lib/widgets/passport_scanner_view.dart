import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/scan_gate.dart';

/// Camera QR adapter.
///
/// Constructed ONLY when the user chooses Scan, so the permission prompt is
/// lazy (design §5). Emits one decode per capture (§7.1, via [ScanGate]),
/// offers a torch, and routes camera/permission errors to [onError]. On web it
/// never constructs the scanner (design §5.1) — manual entry is the web path.
class PassportScannerView extends StatefulWidget {
  const PassportScannerView({required this.onDecoded, this.onError, super.key});

  final void Function(String decoded) onDecoded;
  final VoidCallback? onError;

  @override
  State<PassportScannerView> createState() => _PassportScannerViewState();
}

class _PassportScannerViewState extends State<PassportScannerView> {
  MobileScannerController? _controller;
  final ScanGate _gate = ScanGate();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _controller = MobileScannerController();
  }

  @override
  void dispose() {
    final c = _controller;
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
    if (c != null) unawaited(c.stop());
    widget.onDecoded(raw);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (kIsWeb || c == null) {
      return Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Text(
          'Scanning isn\'t available on the web — enter the code below.',
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
              // Permission denied / no camera: hand back to manual entry.
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => widget.onError?.call());
              return Padding(
                padding: const EdgeInsets.all(AonSpacing.space4),
                child: Text(
                  'Camera unavailable — enter the code from the sign instead.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
          ),
        ),
        TextButton.icon(
          onPressed: () => unawaited(c.toggleTorch()),
          icon: const Icon(Icons.flashlight_on_rounded),
          label: const Text('Torch'),
        ),
      ],
    );
  }
}
