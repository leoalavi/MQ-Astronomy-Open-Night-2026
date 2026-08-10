import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';

/// Capture. Task 8 ships the camera-free manual path; Task 11 adds the "Scan"
/// peer + lazy camera. Manual entry never constructs a scanner.
class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({super.key});

  @override
  ConsumerState<PassportScanScreen> createState() => PassportScanScreenState();
}

class PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _controller = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shared by manual entry (here) and the scanner (Task 11).
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
    // Task 11 adds: if (outcome.justCompleted) push Routes.passportReward.
  }

  void _submitManual() => handleInput(StampInput.manual(_controller.text));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Collect a stamp')),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
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
          if (_message != null) ...[
            const SizedBox(height: AonSpacing.space4),
            Text(_message!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}
