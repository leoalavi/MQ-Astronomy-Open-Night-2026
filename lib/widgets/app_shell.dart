import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/utils/haptics.dart';
import 'package:aon2026/widgets/event_time_preview.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:go_router/go_router.dart';

/// The tab shell wrapping the five top-level screens.
///
/// The bottom navigation is a floating Liquid Glass-inspired island (the
/// signature nav), not a flat Material bar — see
/// docs/superpowers/specs/2026-08-08-aon-glass-liquid-nav-phase1-design.md.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Branch order below: home, program, plan, MAP, info, settings. The Map
  /// branch's index
  /// is the authoritative "Map tab on-screen" signal for `mapVisibleProvider`.
  static const int mapBranchIndex = 3;

  /// The third tab's label comes from the event config ("My Night" here,
  /// "Your Day" at a daytime event), so this list is built per-event rather
  /// than being a `const`.
  static List<LiquidNavItem> itemsFor(
    EventTerminology terminology,
    AonL10n l,
  ) => [
    LiquidNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: l.tabHome,
      fx: TabFx.homecoming,
    ),
    LiquidNavItem(
      icon: Icons.list_alt_outlined,
      activeIcon: Icons.list_alt_rounded,
      label: l.tabProgram,
      fx: TabFx.bounce,
    ),
    LiquidNavItem(
      icon: Icons.star_outline_rounded,
      activeIcon: Icons.star_rounded,
      label: terminology.myPlanShort(l),
      fx: TabFx.spin,
    ),
    LiquidNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: l.mapTitle,
      fx: TabFx.rotateOpen,
    ),
    LiquidNavItem(
      icon: Icons.info_outline_rounded,
      activeIcon: Icons.info_rounded,
      label: l.tabInfo,
      fx: TabFx.orbit,
    ),
    LiquidNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: l.tabSettings,
      fx: TabFx.rotateOpen,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final items = itemsFor(ref.watch(terminologyProvider), l);
    // Whether the preview banner is occupying the top inset (see body below).
    final previewing = ref.watch(simulatedTimeProvider) != null;

    // Drive GPS lifecycle from the authoritative branch index (Map Parity
    // Phase A). Deferred to a post-frame callback because provider state must
    // not be mutated mid-build; AppShell rebuilds whenever currentIndex changes,
    // and `set()` no-ops when unchanged, so this stays in sync and cheap.
    final onMap = navigationShell.currentIndex == mapBranchIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapVisibleProvider.notifier).set(onMap);
    });

    return Scaffold(
      // The body runs behind the floating island so the glass has live content
      // to refract.
      extendBody: true,
      body: Column(
        children: [
          // Visible on every tab while the clock is simulated. Without it, a
          // phone left in preview mode shows a confidently wrong programme
          // with no explanation.
          const EventTimePreviewBanner(),
          Expanded(
            // The banner already consumes the status-bar inset via its own
            // SafeArea. Without removing the top padding here, every tab's
            // AppBar applies that same inset a second time, opening a ~50pt
            // empty band between the banner and the screen title.
            child: previewing
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: navigationShell,
                  )
                : navigationShell,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassSurface(
            variant: GlassVariant.control,
            borderRadius: BorderRadius.circular(
              AonNavMetrics.resolvedBarHeight(context) / 2,
            ),
            child: LiquidTabBar(
              height: AonNavMetrics.resolvedBarHeight(context),
              currentIndex: navigationShell.currentIndex,
              color: context.aon.contentSecondary,
              selectedColor: context.aon.accent,
              accent: context.aon.accent,
              items: items,
              onSelected: (index) {
                // Fire-and-forget haptic; `unawaited` makes the intent explicit
                // and is future-proof if this callback ever becomes async.
                unawaited(AonHaptics.selection(true));
                // Tapping the active tab returns it to its root — the
                // platform-standard behaviour on both iOS and Android.
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
