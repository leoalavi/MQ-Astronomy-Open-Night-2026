import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/widgets/passport_scanner_view.dart';

enum _Mode { choosing, manual, scanning }

/// Capture: scanning and manual entry are equal peers (design §5). The camera
/// is created only after the user taps "Scan" — opening this screen never
/// starts a camera or prompts for permission.
class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({this.scannerBuilder, super.key});

  /// Test seam: inject a fake scanner that emits a decoded string.
  final Widget Function(void Function(String) onDecoded)? scannerBuilder;

  @override
  ConsumerState<PassportScanScreen> createState() => PassportScanScreenState();
}

class PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _controller = TextEditingController();
  _Mode _mode = _Mode.choosing;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleInput(StampInput input) {
    final outcome = ref.read(passportProvider.notifier).collect(input);
    setState(() {
      _message = switch (outcome.result) {
        StampCollected() => 'Stamp collected!',
        StampAlreadyHave() => 'You already have this one.',
        StampUnknown() => 'That\'s not an Astronomy Open Night code.',
        StampDisabled() =>
          'The passport isn\'t live yet — see staff at an information point.',
      };
    });
    if (outcome.justCompleted) context.push(Routes.passportReward);
  }

  void _submitManual() => handleInput(StampInput.manual(_controller.text));

  Widget _scanner() {
    final Widget Function(void Function(String)) builder =
        widget.scannerBuilder ??
            (cb) => PassportScannerView(
                  onDecoded: cb,
                  onError: () => setState(() => _mode = _Mode.manual),
                );
    return builder((raw) => handleInput(StampInput.scan(raw)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Collect a stamp')),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          // Two equal peers.
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: kIsWeb
                      ? null
                      : () => setState(() {
                            _message = null;
                            _mode = _Mode.scanning;
                          }),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan QR code'),
                ),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = _Mode.manual),
                  icon: const Icon(Icons.keyboard_rounded),
                  label: const Text('Enter a code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AonSpacing.space4),

          if (_mode == _Mode.scanning) _scanner(),

          if (_mode == _Mode.manual) ...[
            Text(
              'Enter the code from the venue sign',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AonSpacing.space3),
            TextField(
              key: const Key('passport-manual-field'),
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AonSpacing.space3),
            FilledButton(
              key: const Key('passport-manual-submit'),
              onPressed: _submitManual,
              child: const Text('Add stamp'),
            ),
          ],

          if (_message != null) ...[
            const SizedBox(height: AonSpacing.space4),
            Text(_message!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AonSpacing.space3),
            // Resume affordance after any scan result (design §7.1).
            OutlinedButton(
              onPressed: () => setState(() {
                _message = null;
                _mode = _Mode.scanning;
              }),
              child: const Text('Scan another'),
            ),
          ],
        ],
      ),
    );
  }
}
