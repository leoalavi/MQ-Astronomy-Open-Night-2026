import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';

class LocateButton extends ConsumerWidget {
  const LocateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final s = ref.watch(locationControllerProvider);

    final (IconData icon, String label, Color color) = switch (s) {
      LocationSnapshot(status: LocationStatus.serviceOff) => (
          Icons.location_disabled_rounded,
          l.locateServiceOff,
          context.aon.contentTertiary
        ),
      LocationSnapshot(status: LocationStatus.denied) ||
      LocationSnapshot(status: LocationStatus.deniedForever) => (
          Icons.location_disabled_rounded,
          l.locateUnavailable,
          context.aon.contentTertiary
        ),
      // Low-accuracy wins over follow/stop so a fuzzy fix is called out and the
      // action reads "accuracy is low", not "following" (review #6).
      LocationSnapshot(active: true, fix: final f?) when f.isLowAccuracy => (
          Icons.location_searching_rounded,
          l.locateLowAccuracy,
          context.aon.contentSecondary
        ),
      LocationSnapshot(active: true, following: true) => (
          Icons.near_me_rounded,
          l.locateStopFollowing,
          context.aon.accent
        ),
      LocationSnapshot(active: true) => (
          Icons.near_me_outlined,
          l.locateFollow,
          context.aon.accent
        ),
      _ => (
          Icons.my_location_rounded,
          l.locateShow,
          context.aon.contentSecondary
        ),
    };

    void onTap() =>
        ref.read(locationControllerProvider.notifier).onLocateTapped();

    // ONE explicit semantics node: excludeSemantics drops the IconButton's own
    // node so bySemanticsLabel finds exactly one — but the outer node must then
    // carry `onTap` itself, or assistive tech can read the button yet not
    // activate it (review #7). onTap stays wired in every state (denied /
    // serviceOff re-prompt or open settings via onLocateTapped).
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: IconButton(icon: Icon(icon, color: color), onPressed: onTap),
    );
  }
}
