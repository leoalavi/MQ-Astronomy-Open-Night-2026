import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';

class PointMeScreen extends ConsumerStatefulWidget {
  const PointMeScreen({required this.venueId, super.key});
  final String venueId;
  @override
  ConsumerState<PointMeScreen> createState() => _PointMeScreenState();
}

class _PointMeScreenState extends ConsumerState<PointMeScreen> {
  LatLng? _target;
  String? _placeName;
  AppLifecycleListener? _lifecycle;
  // Captured up front so lifecycle callbacks (incl. dispose) never touch `ref`
  // after the element is deactivated. The providers outlive this widget.
  PointMeTargetNotifier? _targetNotifier;
  PointMeActiveNotifier? _activeNotifier;

  @override
  void initState() {
    super.initState();
    // Fixtures are reached through providers (the swappable data seam), never
    // VenuesData/ParkingData directly.
    final v = ref.read(venueByIdProvider(widget.venueId));
    if (v != null && v.hasCoordinates) {
      _target = LatLng(v.latitude!, v.longitude!);
      _placeName = v.name;
    } else {
      final p = ref.read(parkingByIdProvider(widget.venueId));
      if (p != null && p.hasCoordinates) {
        _target = LatLng(p.latitude!, p.longitude!);
        _placeName = p.name;
      }
    }
    if (_target != null) {
      _targetNotifier = ref.read(pointMeTargetProvider.notifier);
      _activeNotifier = ref.read(pointMeActiveProvider.notifier);
      // Heading math assumes portrait (natural == display); hold it here.
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
      _lifecycle = AppLifecycleListener(onStateChange: (s) {
        if (s == AppLifecycleState.resumed) {
          _claim();
        } else if (s == AppLifecycleState.paused ||
            s == AppLifecycleState.inactive) {
          _release();
        }
      });
    }
  }

  void _claim() {
    if (!mounted || _target == null) return;
    _targetNotifier!.set(_target);
    _activeNotifier!.set(true);
  }

  void _release() {
    // Best-effort cleanup. In production the root ProviderScope outlives this
    // screen, so this always succeeds; guard only against a container being torn
    // down first (e.g. test teardown), where the notifiers are already gone.
    try {
      _targetNotifier?.set(null);
      _activeNotifier?.set(false);
    } catch (_) {
      /* providers already disposed — nothing to release */
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _release(); // uses captured notifiers, not ref
    SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  String _distance(AonL10n l, double m) => m < 1000
      ? l.pointMeDistanceMeters(m.round())
      : l.pointMeDistanceKm((m / 1000).toStringAsFixed(1));

  String _cardinal(AonL10n l, double trueBearing) =>
      switch (cardinalFor(trueBearing)) {
        Cardinal.n => l.cardinalN,
        Cardinal.ne => l.cardinalNE,
        Cardinal.e => l.cardinalE,
        Cardinal.se => l.cardinalSE,
        Cardinal.s => l.cardinalS,
        Cardinal.sw => l.cardinalSW,
        Cardinal.w => l.cardinalW,
        Cardinal.nw => l.cardinalNW,
      };

  String _side(AonL10n l, double rel) {
    final a = rel.abs();
    if (a < 20) return l.sideAhead;
    if (a > 160) return l.sideBehind;
    return rel > 0 ? l.sideRight : l.sideLeft;
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    if (_target == null) {
      return _scaffold(l, _message(context, l.pointMeUnknownPlace));
    }
    final s = ref.watch(pointMeControllerProvider);
    final name = _placeName ?? widget.venueId;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final Widget body;
    if (!s.hasFix) {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.pointMeNeedsLocation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AonSpacing.space4),
        FilledButton.icon(
          key: const Key('point-me-enable'),
          onPressed: () =>
              ref.read(locationControllerProvider.notifier).onLocateTapped(),
          icon: const Icon(Icons.my_location_rounded),
          label: Text(l.locateShow),
        ),
      ]);
    } else if (s.nearTarget) {
      body = _message(context, l.pointMeNearby, icon: Icons.place_rounded);
    } else if (!s.locationReliable) {
      // Fuzzy fix: cardinal + distance, honest note, no precise arrow.
      body = _bearingCard(context,
          sentence: l.pointMeBearingSentence(name,
              _distance(l, s.distanceMeters!), _cardinal(l, s.trueBearingDegrees!)),
          note: l.pointMeImprovingAccuracy);
    } else if (s.availability == HeadingAvailability.available &&
        s.relativeAngleDegrees != null) {
      body = _Arrow(
        semanticLabel: l.pointMeA11yDirection(name, _side(l, s.relativeAngleDegrees!),
            _distance(l, s.distanceMeters!)),
        angleDegrees: s.relativeAngleDegrees!,
        distance: _distance(l, s.distanceMeters!),
        cardinal: _cardinal(l, s.trueBearingDegrees!),
        reduceMotion: reduce,
      );
    } else if (s.availability == HeadingAvailability.acquiring) {
      body = _message(context, l.pointMeFindingNorth,
          icon: Icons.explore_rounded, dim: true);
    } else {
      // unsupported / unavailable → bearing fallback card
      body = _bearingCard(context,
          sentence: l.pointMeBearingSentence(name,
              _distance(l, s.distanceMeters!), _cardinal(l, s.trueBearingDegrees!)),
          note: l.pointMeNoCompass);
    }
    return _scaffold(l, body);
  }

  Widget _scaffold(AonL10n l, Widget child) => Scaffold(
        appBar: AppBar(title: Text(l.pointMeTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AonSpacing.space5),
            child: Center(child: child),
          ),
        ),
      );

  Widget _message(BuildContext context, String text,
          {IconData icon = Icons.info_outline_rounded, bool dim = false}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 48,
            color: dim ? context.aon.contentTertiary : context.aon.accent),
        const SizedBox(height: AonSpacing.space4),
        Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      ]);

  Widget _bearingCard(BuildContext context,
          {required String sentence, required String note}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.explore_outlined, size: 48, color: context.aon.accent),
        const SizedBox(height: AonSpacing.space4),
        Text(sentence,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AonSpacing.space3),
        Text(note,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.aon.contentSecondary)),
      ]);
}

/// Advance an accumulated *turns* value toward [targetDegrees] by the SHORTEST
/// arc (never more than half a turn). Feeding a raw `degrees/360` into
/// [AnimatedRotation] makes it tween linearly, so a target crossing the ±180°
/// wrap (e.g. +179°→−179°, a real 2° change) sweeps the arrow ~358° through
/// "dead ahead" — pointing the wrong way while the destination is behind you
/// (map audit P1). Accumulating continuous turns keeps every step ≤ half a turn.
@visibleForTesting
double shortestTurns(double currentTurns, double targetDegrees) {
  final target = targetDegrees / 360.0;
  var delta = (target - currentTurns) % 1.0; // Dart doubles: result in [0, 1)
  if (delta > 0.5) delta -= 1.0; // take the short way round
  return currentTurns + delta;
}

/// The live arrow. The rotation IS essential state, so under reduced motion it
/// snaps (plain Transform.rotate) rather than easing (AnimatedRotation) — but it
/// still reorients. One non-liveRegion Semantics node carries the spoken label.
class _Arrow extends StatefulWidget {
  const _Arrow({
    required this.semanticLabel,
    required this.angleDegrees,
    required this.distance,
    required this.cardinal,
    required this.reduceMotion,
  });
  final String semanticLabel;
  final double angleDegrees;
  final String distance;
  final String cardinal;
  final bool reduceMotion;

  @override
  State<_Arrow> createState() => _ArrowState();
}

class _ArrowState extends State<_Arrow> {
  // Continuous accumulated rotation in turns, so AnimatedRotation takes the
  // shortest arc across the ±180° wrap instead of spinning the long way.
  late double _turns = widget.angleDegrees / 360.0;

  @override
  void didUpdateWidget(_Arrow old) {
    super.didUpdateWidget(old);
    if (widget.angleDegrees != old.angleDegrees) {
      _turns = shortestTurns(_turns, widget.angleDegrees);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon =
        Icon(Icons.navigation_rounded, size: 140, color: context.aon.accent);
    final rotated = widget.reduceMotion
        ? Transform.rotate(angle: widget.angleDegrees * math.pi / 180, child: icon)
        : AnimatedRotation(
            turns: _turns,
            duration: const Duration(milliseconds: 220),
            child: icon);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // liveRegion:false (default) — do NOT announce on every sensor tick.
      Semantics(
        key: const Key('point-me-arrow'),
        label: widget.semanticLabel,
        excludeSemantics: true,
        child: rotated,
      ),
      const SizedBox(height: AonSpacing.space5),
      Text(widget.distance, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AonSpacing.space2),
      Text(widget.cardinal,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: context.aon.contentSecondary)),
    ]);
  }
}
