import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/nearby_list.dart';
import 'package:aon2026/widgets/preview_location_badge.dart';

/// The compass/radar mode container. Owns the visibility gate (post-frame +
/// captured notifiers, §0.3), triggers follow-free location activation (§0R-11),
/// and routes state by the explicit precedence in §0R-10.
class CompassModeView extends ConsumerStatefulWidget {
  const CompassModeView({super.key});
  @override
  ConsumerState<CompassModeView> createState() => _CompassModeViewState();
}

class _CompassModeViewState extends ConsumerState<CompassModeView> {
  late final CompassVisibleNotifier _visible;
  late final CompassLocked _locked;

  @override
  void initState() {
    super.initState();
    // Capture notifiers up front so dispose never touches `ref` (§0.3).
    _visible = ref.read(compassVisibleProvider.notifier);
    _locked = ref.read(compassLockedProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visible.set(true);
      if (ref.read(locationControllerProvider).fix == null) {
        ref.read(locationControllerProvider.notifier).ensureLocationActive();
      }
    });
  }

  @override
  void dispose() {
    try {
      _visible.set(false);
      _locked.set(null);
    } catch (_) {
      /* container torn down first (tests) */
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    // §0R-10 precedence: location → acquiring GPS → heading.
    final active = ref.watch(locationControllerProvider.select((s) => s.active));
    if (!active) {
      return _EnableLocation(
        message: l.compassLocationNeeded,
        action: l.compassEnableLocation,
        onEnable: () => ref.read(locationControllerProvider.notifier).ensureLocationActive(),
      );
    }
    final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
    if (fix == null) {
      return _Hint(icon: Icons.my_location_rounded, text: l.compassFindingYourLocation);
    }
    final avail = ref.watch(compassControllerProvider.select((s) => s.availability));
    final headingUsable = avail == HeadingAvailability.available ||
        avail == HeadingAvailability.acquiring;
    // A numbered blip is a cluster COUNT — several places sharing one bearing
    // (field report, Leo Alavi 2026-08-28: "numbers 8/3/2 with no clue what they
    // mean"). Explain it, but only when such a blip is actually on the rose, so
    // the hint never appears next to a rose that has no numbers.
    final hasNumberedCluster =
        clusterByBearing(ref.watch(nearbyTargetsProvider),
                MapConfig.compassMinAngularSepDegrees)
            .any((c) => c.count > 1);
    // The rose is north-up with ABSOLUTE bearings (§0R-1): "you" in the centre,
    // every place at its true compass bearing and scaled distance. Only the
    // facing arrow (`_FacingLayer`) needs a live heading, and it already
    // null-guards. So the graphic stays meaningful with NO magnetometer — we
    // always render rose + list once we have a fix, and never collapse the
    // compass to a bare list (field report, Leo Alavi 2026-08-28: "compass
    // disappears after switching tabs"; the real cause was this branch throwing
    // the rose away the moment heading resolved `unavailable`, which a
    // magnetometer-less simulator hits after its acquire window). When heading
    // is unusable we swap the cluster legend for an honest "why no arrow" note.
    final Widget body = Column(
      children: [
        if (!headingUsable)
          _RadarLegend(
            icon: Icons.explore_off_rounded,
            text: l.compassUnavailable,
            subtext: l.compassUnavailableBody,
          )
        else if (hasNumberedCluster)
          _RadarLegend(text: l.compassClusterLegend),
        const Expanded(flex: 3, child: CompassRadarView()),
        const Divider(height: 1),
        const Expanded(flex: 2, child: NearbyList()), // canonical a11y path (§0-A/§0R-9)
      ],
    );
    return Column(children: [
      // §3c: the bearings below may be computed from a simulated fix. Sits
      // above the filter so it covers the radar AND the NearbyList fallback.
      const Padding(
        padding: EdgeInsets.only(bottom: AonSpacing.space2),
        child: PreviewLocationBadge(),
      ),
      _FilterField(
        hint: l.compassFilterHint,
        onChanged: (q) => ref.read(compassFilterProvider.notifier).set(q),
      ),
      Expanded(child: body),
    ]);
  }
}

/// A one- or two-line note above the rose: either "what the numbers mean" or,
/// when there is no live heading, "why there's no facing arrow". `ExcludeSemantics`
/// because the blips it describes are themselves excluded (§0R-9) — the list
/// names every place for screen readers, so the note would be noise there.
class _RadarLegend extends StatelessWidget {
  const _RadarLegend({
    required this.text,
    this.subtext,
    this.icon = Icons.info_outline_rounded,
  });
  final String text;
  final String? subtext;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AonSpacing.space3, 0, AonSpacing.space3, AonSpacing.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: AonSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text,
                      // Capped so a large text scale on a tiny screen can never
                      // make this fixed-height note starve the flexible radar/
                      // list below and overflow the column.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor)),
                  if (subtext != null)
                    Text(subtext!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AonSpacing.space3),
        child: TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.filter_alt_rounded),
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _EnableLocation extends StatelessWidget {
  const _EnableLocation(
      {required this.message, required this.action, required this.onEnable});
  final String message;
  final String action;
  final VoidCallback onEnable;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AonSpacing.space4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_off_rounded, size: 40),
            const SizedBox(height: AonSpacing.space3),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AonSpacing.space3),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AonSpacing.minTapTarget),
              child: ElevatedButton(onPressed: onEnable, child: Text(action)),
            ),
          ]),
        ),
      );
}

/// Static (spinner-free) hint — never blocks `pumpAndSettle` (§0R-C spirit).
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40),
          const SizedBox(height: AonSpacing.space3),
          Text(text, textAlign: TextAlign.center),
        ]),
      );
}
