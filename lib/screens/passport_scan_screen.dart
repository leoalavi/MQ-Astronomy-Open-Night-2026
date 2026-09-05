import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/utils/haptics.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';
import 'package:aon2026/widgets/passport_scanner_view.dart';

enum _Mode { manual, scanning }

/// Capture: scanning and manual entry are equal peers (design §5). Scanning is
/// the default: opening this screen brings the camera up immediately (which
/// prompts for permission on first use) so a visitor at a venue sign can just
/// point and scan — no second tap. On the web, where there is no camera, manual
/// entry is the default instead.
class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({this.scannerBuilder, super.key});

  /// Test seam: inject a fake scanner that emits a decoded string.
  final Widget Function(void Function(String) onDecoded)? scannerBuilder;

  @override
  ConsumerState<PassportScanScreen> createState() => PassportScanScreenState();
}

class PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _controller = TextEditingController();
  // Scan is the default mode so the camera starts on open (design update: no
  // second tap). Web has no camera, so it starts on manual entry there.
  _Mode _mode = kIsWeb ? _Mode.manual : _Mode.scanning;
  StampResult? _outcome;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleInput(StampInput input) {
    if (!mounted || (input is ScanInput && _outcome != null)) return;
    final outcome = ref.read(passportProvider.notifier).collect(input);
    setState(() => _outcome = outcome.result);

    // Learning layer: only a real new stamp. Never touches scanner lifecycle.
    if (outcome.result is StampCollected) {
      unawaited(AonHaptics.light(true)); // one haptic per real collect (§13)
      if (outcome.justCompleted) {
        context.push(Routes.passportReward); // 9th: reward wins, no sheet (§11.2)
      } else {
        final venueId = (outcome.result as StampCollected).venueId;
        unawaited(showPassportFactSheet(context, venueId,
            reason: FactRevealReason.collected)); // 1–8 (§11.1)
      }
    }
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
    final l = AonL10n.of(context);
    final message = switch (_outcome) {
      null => null,
      StampCollected() => l.passportScanCollected,
      StampAlreadyHave() => l.passportScanAlready,
      StampUnknown() => l.passportScanUnknown,
      StampDisabled() => l.passportScanDisabled,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.passportScanTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
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
                            _outcome = null;
                            _mode = _Mode.scanning;
                          }),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(l.passportScanQrButton),
                ),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = _Mode.manual),
                  icon: const Icon(Icons.keyboard_rounded),
                  label: Text(l.passportEnterCodeButton),
                ),
              ),
            ],
          ),
          const SizedBox(height: AonSpacing.space4),

          if (!kIsWeb) ...[
            Text(l.passportScannerPrivacy, style: theme.textTheme.bodySmall),
            const SizedBox(height: AonSpacing.space3),
          ],
          if (_mode == _Mode.scanning && _outcome == null) _scanner(),

          if (_mode == _Mode.manual) ...[
            Text(l.passportEnterCodeHint, style: theme.textTheme.titleMedium),
            const SizedBox(height: AonSpacing.space3),
            TextField(
              key: const Key('passport-manual-field'),
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.passportCodeLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AonSpacing.space3),
            FilledButton(
              key: const Key('passport-manual-submit'),
              onPressed: _submitManual,
              child: Text(l.passportAddStamp),
            ),
          ],

          if (message != null) ...[
            const SizedBox(height: AonSpacing.space4),
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AonSpacing.space3),
            // Resume affordance after any scan result (design §7.1).
            OutlinedButton(
              onPressed: () => setState(() {
                _outcome = null;
                _mode = _Mode.scanning;
              }),
              child: Text(l.passportScanAnother),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
