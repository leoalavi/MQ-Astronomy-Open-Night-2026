import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/utils/time_format.dart';

/// Completion screen — GUARDED: redemption shows only when the passport is
/// actually complete (design §7.2), so opening `/passport/reward` directly with
/// fewer than 9 stamps cannot display the redemption UI. The live clock is a
/// nudge, not security (§7.3); staff + wristband is the real gate. Confetti
/// honours reduced motion.
class PassportRewardScreen extends ConsumerStatefulWidget {
  const PassportRewardScreen({super.key});

  @override
  ConsumerState<PassportRewardScreen> createState() => _RewardState();
}

class _RewardState extends ConsumerState<PassportRewardScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 3));
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _started = false;

  @override
  void dispose() {
    _confetti.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _startOnce() {
    if (_started) return;
    _started = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (!MediaQuery.disableAnimationsOf(context)) _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);
    final complete = ref.watch(passportProvider).isComplete;

    if (!complete) {
      return Scaffold(
        appBar: AppBar(title: Text(l.passportTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AonSpacing.space5),
            child: Text(
              l.passportRewardIncomplete,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Complete: start the celebration once, after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOnce());
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.passportRewardCompleteTitle)),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AonSpacing.space5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 72,
                    color: context.aon.accent,
                  ),
                  const SizedBox(height: AonSpacing.space4),
                  Text(
                    l.passportRewardAllCollected(
                      PassportPolicy.stationCount,
                    ),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AonSpacing.space3),
                  Text(
                    EventInfo.fullName,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AonSpacing.space3),
                  Text(
                    TimeFormat.clockWithSeconds(_now),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AonSpacing.space4),
                  Text(
                    l.passportRewardShowStaff,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (!reduceMotion)
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
            ),
        ],
      ),
    );
  }
}
