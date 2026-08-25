import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/nav_format.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/nav_metrics.dart';

/// The canonical accessible interaction for the compass (§0R-9): distance-sorted
/// rows (56px, semantic buttons) plus disabled "location unknown" rows for
/// known-but-unlocatable safety venues (§0R-4). Rendered beside/below the rose.
class NearbyList extends ConsumerWidget {
  const NearbyList({super.key});

  static String _cardinal(AonL10n l, Cardinal c) => switch (c) {
        Cardinal.n => l.cardinalN,
        Cardinal.ne => l.cardinalNE,
        Cardinal.e => l.cardinalE,
        Cardinal.se => l.cardinalSE,
        Cardinal.s => l.cardinalS,
        Cardinal.sw => l.cardinalSW,
        Cardinal.w => l.cardinalW,
        Cardinal.nw => l.cardinalNW,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final targets = ref.watch(nearbyTargetsProvider);
    final unlocatable = unlocatableVenues(ref.watch(searchIndexProvider));

    if (targets.isEmpty && unlocatable.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AonSpacing.space4),
          child: Text(l.compassNothingNearby, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      // The compass runs under the floating glass tab bar (shell `extendBody`),
      // so reserve the same clearance every other scroll body does — otherwise
      // the last rows and the collapsed "location unknown" section hide behind
      // the island. Already includes the home-indicator inset, so this list is
      // NOT additionally wrapped in a bottom SafeArea (that would double it).
      padding: EdgeInsets.only(bottom: AonNavMetrics.clearance(context)),
      children: [
        // Confirmed, pointable targets first and unadorned — these are what the
        // compass is for.
        for (final t in targets) _TargetRow(target: t, l: l),

        // When nothing can be pointed at, say so plainly instead of letting a
        // wall of "location unknown" rows stand in for an answer.
        if (targets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AonSpacing.space4),
            child: Text(
              l.compassNoConfirmedTargets,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

        // Unconfirmed places are kept — a safety venue like First aid must
        // never be silently dropped (§0R-4) — but COLLAPSED behind a counted
        // heading. Previously they were appended flat into the same list, so on
        // a phone the compass looked like a broken screen full of "Location
        // unknown — see the printed map".
        if (unlocatable.isNotEmpty)
          _UnconfirmedSection(entries: unlocatable, l: l),
      ],
    );
  }
}

/// The collapsed "no confirmed location" group.
class _UnconfirmedSection extends StatelessWidget {
  const _UnconfirmedSection({required this.entries, required this.l});

  final List<SearchEntry> entries;
  final AonL10n l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      // Collapsed by default: discoverable, never dominant.
      initiallyExpanded: false,
      leading: const Icon(Icons.location_off_rounded),
      title: Text(l.compassUnconfirmedHeading(entries.length)),
      childrenPadding: const EdgeInsets.only(bottom: AonSpacing.space2),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AonSpacing.space4,
            vertical: AonSpacing.space2,
          ),
          child: Text(
            l.compassUnconfirmedBlurb,
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final e in entries) _UnlocatableRow(entry: e, l: l),
      ],
    );
  }
}

class _TargetRow extends ConsumerWidget {
  const _TargetRow({required this.target, required this.l});
  final NearbyTarget target;
  final AonL10n l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approx = !target.confidence.isReliable; // placeholder/derived
    final cardinal = NearbyList._cardinal(l, cardinalFor(target.trueBearingDegrees));
    final dist = formatNavDistance(l, target.distanceMeters.round());
    // §0R-13: encode state by ICON + label, never colour hue alone.
    final icon = approx
        ? Icons.help_outline_rounded
        : target.kind == PlaceKind.venue
            ? Icons.star_rounded
            : Icons.place_rounded;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AonSpacing.minTapTarget),
      child: ListTile(
        leading: Icon(icon),
        title: Text(target.title),
        isThreeLine: approx,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$cardinal · $dist'),
            if (approx)
              Text(l.compassApproximate, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () => ref.read(compassLockedProvider.notifier).set(target.placeKey),
      ),
    );
  }
}

class _UnlocatableRow extends StatelessWidget {
  const _UnlocatableRow({required this.entry, required this.l});
  final SearchEntry entry;
  final AonL10n l;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AonSpacing.minTapTarget),
        child: ListTile(
          enabled: false,
          leading: const Icon(Icons.location_off_rounded),
          title: Text(entry.title),
          subtitle: Text(l.compassUnlocatable),
        ),
      );
}
