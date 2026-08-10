import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/passport_facts_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/passport_fact.dart';
import 'package:aon2026/services/passport_fact_publication.dart';
import 'package:aon2026/widgets/confidence_note.dart';

enum FactRevealReason { collected, revisit }

/// Looks up the fact for [venueId] and reveals it in a bottom sheet. No-ops if
/// no fact exists (design §11.5). Suppresses the sheet route animation under
/// reduced motion (design §9).
Future<void> showPassportFactSheet(
  BuildContext context,
  String venueId, {
  required FactRevealReason reason,
}) {
  final fact = PassportFactsData.byVenueId(venueId);
  if (fact == null) return Future<void>.value(); // no crash, no empty modal
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
    builder: (_) => PassportFactSheet(fact: fact, reason: reason),
  );
}

/// The reveal surface. Content-tier (solid), never shader glass (design §8.2).
class PassportFactSheet extends StatelessWidget {
  const PassportFactSheet({
    required this.fact,
    required this.reason,
    this.isRelease = kReleaseMode,
    super.key,
  });

  final PassportFact fact;
  final FactRevealReason reason;
  final bool isRelease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = resolveFactPresentation(fact, isRelease: isRelease);
    final showFallback = p.body == FactBody.fallback;
    final title = showFallback ? factFallbackTitle : fact.title;
    final body = showFallback ? factFallbackMessage : fact.fact;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Scrollable content, matching the app's other sheets (whats_on:312,
    // map:423) — a long fact at text scale 2.0 must scroll, not overflow.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AonSpacing.space5,
          AonSpacing.space5,
          AonSpacing.space5,
          AonSpacing.space5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stamp pop — only on a fresh collect, motion-aware (design §12).
            if (reason == FactRevealReason.collected)
              _StampPop(reduceMotion: reduceMotion),
            if (reason == FactRevealReason.collected)
              const SizedBox(height: AonSpacing.space3),
            // Venue + activity context (venue name is the heading, design §8.1).
            Semantics(
              header: true,
              child: Text(
                VenuesData.byId(fact.venueId)?.name ?? fact.venueId,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AonSpacing.space1),
            Text(
              fact.activityLabel.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: context.aon.contentTertiary),
            ),
            const SizedBox(height: AonSpacing.space3),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AonSpacing.space3),
            Text(body, style: theme.textTheme.bodyLarge),
            if (p.showDraftNote) ...[
              const SizedBox(height: AonSpacing.space4),
              // showDraftNote is only true for a placeholder fact, so
              // ConfidenceNote (which renders only for placeholder) shows here.
              ConfidenceNote(
                confidence: fact.confidence,
                message: 'Draft — awaiting review by the astronomy team.',
              ),
            ],
            const SizedBox(height: AonSpacing.space5),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampPop extends StatelessWidget {
  const _StampPop({required this.reduceMotion});
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.check_circle_rounded,
        color: context.aon.accent, size: 44);
    if (reduceMotion) return icon; // no scale/translate under reduced motion
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: AonAnimations.slow, // 300ms
      curve: AonAnimations.easeOutCubic,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}
