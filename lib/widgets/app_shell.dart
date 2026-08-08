import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/utils/haptics.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:go_router/go_router.dart';

/// The tab shell wrapping the five top-level screens.
///
/// The bottom navigation is a floating Liquid Glass-inspired island (the
/// signature nav), not a flat Material bar — see
/// docs/superpowers/specs/2026-08-08-aon-glass-liquid-nav-phase1-design.md.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<LiquidNavItem> _items = [
    LiquidNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      fx: TabFx.homecoming,
    ),
    LiquidNavItem(
      icon: Icons.list_alt_outlined,
      activeIcon: Icons.list_alt_rounded,
      label: 'Program',
      fx: TabFx.bounce,
    ),
    LiquidNavItem(
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule_rounded,
      label: 'Now',
      fx: TabFx.spin,
    ),
    LiquidNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Map',
      fx: TabFx.rotateOpen,
    ),
    LiquidNavItem(
      icon: Icons.info_outline_rounded,
      activeIcon: Icons.info_rounded,
      label: 'Info',
      fx: TabFx.orbit,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body runs behind the floating island so the glass has live content
      // to refract.
      extendBody: true,
      body: navigationShell,
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
              color: AonColors.contentSecondary,
              selectedColor: AonColors.amber,
              accent: AonColors.amber,
              items: _items,
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
