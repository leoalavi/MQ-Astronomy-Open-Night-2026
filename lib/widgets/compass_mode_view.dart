import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
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
    final Widget body = switch (avail) {
      HeadingAvailability.available || HeadingAvailability.acquiring => const Column(
          children: [
            Expanded(flex: 3, child: CompassRadarView()),
            Divider(height: 1),
            Expanded(flex: 2, child: NearbyList()), // canonical a11y path (§0-A/§0R-9)
          ],
        ),
      HeadingAvailability.unavailable || HeadingAvailability.unsupported => const NearbyList(),
    };
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
