import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/widgets/quick_link_tile.dart';

/// Landing screen: branding, when and where, and the four things people
/// actually open the app for.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(currentTimeProvider);
    final happeningNow = ref.watch(happeningNowProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(now: now)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AonSpacing.space4,
              AonSpacing.space5,
              AonSpacing.space4,
              AonNavMetrics.clearance(context),
            ),
            sliver: SliverList.list(
              children: [
                // ── Live strip ──
                if (happeningNow.isNotEmpty)
                  _LiveStrip(count: happeningNow.length),
                if (happeningNow.isNotEmpty)
                  const SizedBox(height: AonSpacing.space5),

                // ── Quick links ──
                Text('Get started', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AonSpacing.space3),
                // A max column width, then add columns — the same intent as a
                // grid, but the tile height follows its content. A fixed cell
                // height clipped the two-line descriptions on a narrow phone
                // and at large accessibility text sizes; letting the row grow
                // is the accessible fix.
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = AonSpacing.space3;
                    final columns =
                        (constraints.maxWidth / 260).ceil().clamp(1, 4);
                    final tileWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    final tiles = <Widget>[
                      QuickLinkTile(
                        icon: Icons.list_alt_rounded,
                        label: 'Program',
                        description: 'Everything on tonight',
                        accent: AonColors.stellar,
                        onTap: () => context.go(Routes.program),
                      ),
                      QuickLinkTile(
                        icon: Icons.schedule_rounded,
                        label: 'What’s On Now',
                        description: 'Happening and starting soon',
                        accent: AonColors.live,
                        onTap: () => context.go(Routes.whatsOn),
                      ),
                      QuickLinkTile(
                        icon: Icons.map_rounded,
                        label: 'Map',
                        description: 'Venues, toilets, first aid',
                        accent: AonColors.amber,
                        onTap: () => context.go(Routes.map),
                      ),
                      QuickLinkTile(
                        icon: Icons.local_parking_rounded,
                        label: 'Parking & walking',
                        description: 'Get from your car to the event',
                        accent: AonColors.mapParking,
                        onTap: () => context.push(Routes.wayfinding),
                      ),
                    ];
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final tile in tiles)
                          SizedBox(width: tileWidth, child: tile),
                      ],
                    );
                  },
                ),

                const SizedBox(height: AonSpacing.space6),

                // ── Practical summary ──
                Text('Good to know', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AonSpacing.space3),
                const _FactRow(
                  icon: Icons.dark_mode_rounded,
                  title: 'It gets cold and dark',
                  body: 'Bring a jacket and a torch. Red-light mode is best '
                      'near the telescopes — it protects everyone’s night '
                      'vision.',
                ),
                const _FactRow(
                  icon: Icons.confirmation_number_rounded,
                  title: 'Some shows need pre-booking',
                  body: 'The magic shows and Destination Moon need seats '
                      'booked at the time of ticket purchase.',
                ),
                const _FactRow(
                  icon: Icons.local_parking_rounded,
                  title: 'Free parking',
                  body: 'West 5, West 6 and South 2.',
                ),
                const _FactRow(
                  icon: Icons.train_rounded,
                  title: 'Metro',
                  body: 'Macquarie University Metro Station is about a '
                      '10 minute walk from the Central Courtyard.',
                ),

                const SizedBox(height: AonSpacing.space6),
                _Attribution(theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero header — the supplied astrophotography image behind the event title.
class _Hero extends StatelessWidget {
  const _Hero({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    // A minimum height, not a fixed one: at a large accessibility text size
    // the title and date grow past 340px, and a fixed box clipped them. The
    // image and scrim fill via Positioned.fill; the text column (bottom-left
    // aligned) drives the height and lets the hero grow instead of overflow.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 340 + topInset),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero_deep_triangulum_galaxy.jpg',
              fit: BoxFit.cover,
              // Decorative: the title sits on top and the credit is given in
              // the attribution card, so screen readers skip the raw asset.
              excludeFromSemantics: true,
              // If the asset is ever missing, fall back to flat night rather
              // than throwing a red error box over the app's first screen.
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AonColors.night900),
            ),
          ),
          // Two-stop scrim. The image is bright in places; without this the
          // title would fail contrast over the galaxy core.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x6605070F),
                    Color(0xCC05070F),
                    AonColors.night950,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AonSpacing.space5,
              topInset + AonSpacing.space5,
              AonSpacing.space5,
              AonSpacing.space5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EventInfo.host.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AonColors.contentSecondary,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: AonSpacing.space2),
                Text(
                  EventInfo.name,
                  style: theme.textTheme.displayMedium,
                ),
                Text(
                  EventInfo.year,
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: AonColors.amber),
                ),
                const SizedBox(height: AonSpacing.space3),
                // A glass "date pill" floating over the galaxy photo — the hero's
                // single glass element (Phase 2). control tier = the translucent
                // rendering rung; the pill is not interactive.
                LayoutBuilder(
                  builder: (context, constraints) => GlassSurface(
                    variant: GlassVariant.control,
                    borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
                    child: ConstrainedBox(
                      // maxWidth = the available hero text-column width, so the
                      // pill never exceeds the hero's horizontal content bounds.
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AonSpacing.space3,
                          vertical: AonSpacing.space2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              size: AonSpacing.iconSm,
                              color: AonColors.contentSecondary,
                            ),
                            const SizedBox(width: AonSpacing.space2),
                            // Flexible so the long date+time string wraps on a
                            // narrow phone instead of overflowing off the edge.
                            Flexible(
                              child: Text(
                                '${TimeFormat.longDate(EventInfo.startsAt)}  ·  '
                                '${TimeFormat.range(
                                  EventInfo.startsAt,
                                  EventInfo.endsAt,
                                )}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AonColors.contentSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AonColors.live.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.whatsOn),
        child: Container(
          padding: const EdgeInsets.all(AonSpacing.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
            border: Border.all(
              color: AonColors.live.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 10, color: AonColors.live),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'activity' : 'activities'} '
                  'happening right now',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AonColors.live),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AonColors.live,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AonSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AonSpacing.iconMd, color: AonColors.amber),
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AonColors.contentSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AonSpacing.space4),
      decoration: BoxDecoration(
        color: AonColors.night900,
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: AonColors.night700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image credit',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
          const SizedBox(height: AonSpacing.space1),
          Text(
            'A Deep Triangulum Galaxy — Aleix Roig, 2026',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentSecondary),
          ),
          const SizedBox(height: AonSpacing.space3),
          Text(
            '${EventInfo.faculty}, ${EventInfo.host}. '
            '${EventInfo.cricosProvider}.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
        ],
      ),
    );
  }
}
