import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:aon2026/widgets/passport_home_card.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/activity_rail_card.dart';

import 'package:aon2026/widgets/quick_link_tile.dart';
import 'package:aon2026/widgets/section_header.dart';
import 'package:aon2026/widgets/timing_badge.dart';
import 'package:aon2026/widgets/venue_info_sheet.dart';
import 'package:aon2026/widgets/parking_choices_sheet.dart';
<<<<<<< Updated upstream
import 'package:aon2026/widgets/toilet_choices_sheet.dart';
=======
import 'package:aon2026/widgets/information_points_sheet.dart';
>>>>>>> Stashed changes

/// Landing screen: branding, when and where, and the four things people
/// actually open the app for.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(currentTimeProvider);
    final happeningNow = ref.watch(happeningNowProvider);
    final startingSoon = ref.watch(startingSoonProvider);
    final upcoming = ref.watch(upcomingProvider);
    final phase = ref.watch(eventPhaseProvider);
    final terminology = ref.watch(terminologyProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(now: now, phase: phase),
          ),
          // The hero image credit lives here — immediately under the image it
          // describes — and nowhere else on Home. (A dedicated full credits
          // list also carries it, on the Info screen.)
          SliverToBoxAdapter(child: _HeroCredit(theme: theme)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AonSpacing.space4,
              AonSpacing.space5,
              AonSpacing.space4,
              AonNavMetrics.clearance(context),
            ),
            sliver: SliverList.list(
              children: [
                // ── 1. Where should I be? ──
                const _NextUpCard(),

                // ── 2. What's happening now ──
                _ActivityRail(
                  title: l.timingHappeningNow,
                  icon: Icons.circle,
                  iconColor: context.aon.live,
                  items: happeningNow,
                  now: now,
                  emptyMessage: phase.isLive ? l.homeNothingRunningNow : null,
                ),

                const SizedBox(height: AonSpacing.space5),
                const PassportHomeCard(),

                _ActivityRail(
                  title: l.homeUpNext,
                  subtitle: startingSoon.isNotEmpty
                      ? l.timingStartingWithin(
                          WhatsOnService.soonWindow.inMinutes,
                        )
                      : null,
                  icon: Icons.schedule_rounded,
                  iconColor: context.aon.soon,
                  items: startingSoon.isNotEmpty
                      ? startingSoon
                      : upcoming.take(6).toList(),
                  now: now,
                ),

                if (happeningNow.isNotEmpty ||
                    startingSoon.isNotEmpty ||
                    upcoming.isNotEmpty) ...[
                  const SizedBox(height: AonSpacing.space2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      // Goes to the Program tab, forcing its Tonight view.
                      // Program IS the canonical time-sliced programme; a
                      // second screen showing the same four buckets only made
                      // visitors wonder which one was "the real" programme.
                      onPressed: () {
                        ref
                            .read(programViewProvider.notifier)
                            .set(ProgramView.tonight);
                        context.go(Routes.program);
                      },
                      icon: const Icon(Icons.timeline_rounded),
                      label: Text(
                        l.homeSeeWholeEvent(terminology.eventPeriod(l)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AonSpacing.space5),

                const _MapCta(),

                const SizedBox(height: AonSpacing.space6),

                Text(
                  l.homeQuickAccessTitle,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AonSpacing.space3),
                const _QuickAccessGrid(),

                const SizedBox(height: AonSpacing.space6),

                // ── Practical summary ──
                Text(l.homeGoodToKnow, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AonSpacing.space3),
                _FactRow(
                  icon: Icons.dark_mode_rounded,
                  title: l.homeFactColdTitle,
                  body: l.homeFactColdBody,
                ),
                _FactRow(
                  icon: Icons.confirmation_number_rounded,
                  title: l.homeFactBookingTitle,
                  body: l.homeFactBookingBody,
                ),
                _FactRow(
                  icon: Icons.local_parking_rounded,
                  title: l.homeFactParkingTitle,
                  body: l.homeFactParkingBody,
                ),
                _FactRow(
                  icon: Icons.train_rounded,
                  title: l.homeFactMetroTitle,
                  body: l.homeFactMetroBody,
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
  const _Hero({required this.now, required this.phase});

  final DateTime now;
  final EventPhase phase;

  @override
  Widget build(BuildContext context) {
    // No `theme` here on purpose: every text style in this hero resolves from
    // the forced-dark Theme installed below, not from the page theme.
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
              errorBuilder: (_, _, _) => ColoredBox(color: context.aon.surface),
            ),
          ),
          // Two-stop scrim. The image is bright in places; without this the
          // title would fail contrast over the galaxy core.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x6605070F),
                    const Color(0xCC05070F),
                    context.aon.surfaceBase,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // The hero text always renders in the DARK palette, in both themes.
          //
          // It sits on a photograph of deep space — a permanently dark
          // backdrop. In light mode the page's near-black body text would be
          // dark-on-dark and effectively invisible, and the deep-amber light
          // accent would vanish too. Forcing the dark theme for this subtree
          // (text, the glass date pill and the phase badge alike) is the
          // standard fix for content over fixed-dark imagery.
          //
          // Note the scrim above deliberately stays outside this Theme: its
          // final stop blends into the *page* background, which is light in
          // light mode, so the hero melts into the screen instead of ending
          // on a hard dark edge.
          Theme(
            data: AonTheme.build(),
            // Builder so `Theme.of(context)` below resolves the DARK theme we
            // just installed. Without it the styles would still come from the
            // outer (possibly light) theme captured at the top of build().
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final l = AonL10n.of(context);
                return Padding(
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
                          color: context.aon.contentSecondary,
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
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: context.aon.accent,
                        ),
                      ),
                      const SizedBox(height: AonSpacing.space3),
                      // A glass "date pill" floating over the galaxy photo — the hero's
                      // single glass element (Phase 2). control tier = the translucent
                      // rendering rung; the pill is not interactive.
                      LayoutBuilder(
                        builder: (context, constraints) => GlassSurface(
                          variant: GlassVariant.control,
                          borderRadius: BorderRadius.circular(
                            AonSpacing.radiusFull,
                          ),
                          child: ConstrainedBox(
                            // maxWidth = the available hero text-column width, so the
                            // pill never exceeds the hero's horizontal content bounds.
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AonSpacing.space3,
                                vertical: AonSpacing.space2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    size: AonSpacing.iconSm,
                                    color: context.aon.contentSecondary,
                                  ),
                                  const SizedBox(width: AonSpacing.space2),
                                  // Flexible so the long date+time string wraps on a
                                  // narrow phone instead of overflowing off the edge.
                                  Flexible(
                                    child: Text(
                                      '${TimeFormat.longDate(EventInfo.startsAt)}  ·  '
                                      '${TimeFormat.range(EventInfo.startsAt, EventInfo.endsAt)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context.aon.contentSecondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_phaseLabel(phase, l) != null) ...[
                        const SizedBox(height: AonSpacing.space3),
                        _PhasePill(phase: phase),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Human phrasing for the event's own status. Returns null when there is
/// nothing worth saying — a badge reading "the event is in 3 weeks" on every
/// launch would be noise, so the pill only appears once it is actionable.
String? _phaseLabel(EventPhase phase, AonL10n l) => phase.labelOf(l);

/// The hero's event-status badge.
class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase});

  final EventPhase phase;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final label = _phaseLabel(phase, l);
    if (label == null) return const SizedBox.shrink();

    final (colour, icon) = switch (phase) {
      EventPhase.running => (context.aon.live, Icons.circle),
      EventPhase.endingSoon => (
        context.aon.soon,
        Icons.hourglass_bottom_rounded,
      ),
      EventPhase.startingSoon => (context.aon.soon, Icons.schedule_rounded),
      EventPhase.today => (context.aon.accent, Icons.event_available_rounded),
      EventPhase.ended => (
        context.aon.contentTertiary,
        Icons.check_circle_outline_rounded,
      ),
      EventPhase.future => (context.aon.contentTertiary, Icons.event_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space3,
        vertical: AonSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: phase == EventPhase.running ? 9 : AonSpacing.iconSm,
            color: colour,
          ),
          const SizedBox(width: AonSpacing.space2),
          // Same rule as TimingBadge: a min-size Row must let its label
          // shrink, or a long phase string ("This event has finished") runs
          // off a 320pt hero at large text scales.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.title, required this.body});

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
          Icon(icon, size: AonSpacing.iconMd, color: context.aon.accent),
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.aon.contentSecondary,
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

/// Small caption directly under the hero image — the image credit's single
/// canonical placement on Home.
class _HeroCredit extends ConsumerWidget {
  const _HeroCredit({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final config = ref.watch(eventConfigProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AonSpacing.space4,
        AonSpacing.space2,
        AonSpacing.space4,
        0,
      ),
      child: Text(
        // e.g. "Image credit: <hero credit from config>"
        '${l.homeImageCredit}: ${config.heroCredit}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: context.aon.contentTertiary,
        ),
      ),
    );
  }
}

/// Understated Home footer: who built the app, plus the institutional line.
///
/// Deliberately NOT the hero image credit (that lives under the hero) and NOT
/// framework/backend credits — the primary visitor journey stays about the
/// event. Just a quiet, professional "made by" line.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    return Container(
      padding: const EdgeInsets.all(AonSpacing.space4),
      decoration: BoxDecoration(
        color: context.aon.surface,
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: context.aon.border),
      ),
      child: Text(
        // Proper nouns isolated so they stay LTR inside Persian text. This is
        // the ONLY credit block on Home; the full formal credits live at the
        // bottom of Settings, and the hero image credit sits under the hero.
        l.creditsDevelopedBy(
          Bidi.isolate(EventInfo.developerPrimary),
          Bidi.isolate(EventInfo.developerSecondary),
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: context.aon.contentSecondary,
        ),
      ),
    );
  }
}

/// "Where should I be" — the single most useful thing on Home once the
/// visitor has saved anything. Absent entirely when they haven't, rather than
/// showing an empty shell; Home already has plenty to read.
class _NextUpCard extends ConsumerWidget {
  const _NextUpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final entry = ref.watch(nextUpProvider);
    final terminology = ref.watch(terminologyProvider);
    final savedCount = ref.watch(savedCountProvider);
    if (entry == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = ref.watch(currentTimeProvider);
    final venue = ref.watch(venueByIdProvider(entry.event.venueId));

    return Padding(
      padding: const EdgeInsets.only(bottom: AonSpacing.space5),
      child: AonTactileButton(
        onTap: () => context.go(Routes.myNight),
        borderRadius: AonSpacing.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(AonSpacing.space4),
          decoration: BoxDecoration(
            color: context.aon.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
            border: Border.all(
              color: context.aon.accent.withValues(alpha: 0.40),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: AonSpacing.iconSm,
                    color: context.aon.accent,
                  ),
                  const SizedBox(width: AonSpacing.space2),
                  Expanded(
                    child: Text(
                      l.myNightNext(terminology.myPlan(l)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.aon.accent,
                      ),
                    ),
                  ),
                  // TimingBadge is a min-size Row and documents that callers
                  // must bound it. Flexible is that bound: on a 320pt phone at
                  // 2.0 text scale the badge would otherwise push past the
                  // card edge.
                  Flexible(
                    child: TimingBadge(
                      timing: entry.timing,
                      trailingText: switch (entry.timing) {
                        // Only count down to a PUBLISHED finish — the same
                        // honesty gate event_card / activity_rail_card /
                        // my_night_screen already apply. A startOnly/repeating
                        // session's end is our own 10pm stand-in, so an
                        // ungated "ends in 3 hr" here invented a finish time
                        // the programme never printed (audit HP-A).
                        EventTiming.happeningNow =>
                          entry.session.hasPublishedEnd
                              ? TimeFormat.remaining(l, now, entry.session.end)
                              : null,
                        EventTiming.startingSoon => TimeFormat.until(
                          l,
                          now,
                          entry.session.start,
                        ),
                        // Only a published start; an open-all-night activity's
                        // 4pm is a stand-in, not a time the programme printed.
                        _ =>
                          entry.session.hasPublishedStart
                              ? TimeFormat.time(entry.session.start)
                              : null,
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AonSpacing.space2),
              Text(entry.event.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AonSpacing.space1),
              Text(
                Bidi.joinIsolated([
                  TimeFormat.sessionLabel(l, entry.session),
                  venue?.chipLabel ?? l.infoLocationToBeConfirmed,
                ], separator: '  ·  '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.aon.contentSecondary,
                ),
              ),
              if (savedCount > 1) ...[
                const SizedBox(height: AonSpacing.space2),
                Text(
                  l.myNightSavedCount(savedCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.aon.contentTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of activity cards.
///
/// Horizontal rather than a stacked list so Home can show three time horizons
/// without becoming an endless scroll. Each rail is independently scrollable
/// and shows a peek of the next card, which is what signals it scrolls.
class _ActivityRail extends StatelessWidget {
  const _ActivityRail({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.now,
    this.subtitle,
    this.emptyMessage,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final List<TimedEvent> items;
  final DateTime now;

  /// Shown instead of the rail when [items] is empty. When null, the whole
  /// section is omitted — an empty rail with no explanation is just noise.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyMessage == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          count: items.isEmpty ? null : items.length,
          icon: icon,
          iconColor: iconColor,
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AonSpacing.space2),
            child: Text(
              emptyMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.aon.contentTertiary,
              ),
            ),
          )
        else
          // The rail sizes to its tallest card rather than a fixed height.
          // A fixed height overflowed at large accessibility text sizes (the
          // app supports up to 2.0), and clipping a card is exactly the
          // failure the text-scale gauntlet exists to prevent. IntrinsicHeight
          // is O(children) but there are at most a handful of cards.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: AonSpacing.space3),
                    ActivityRailCard(timed: items[i], now: now),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The map call-to-action.
///
/// Given its own full-width surface rather than sharing the quick-access grid:
/// after "what's on", "where is it" is the most common reason the app is open,
/// and the organisers specifically asked for navigation to be obvious.
class _MapCta extends ConsumerWidget {
  const _MapCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);
    final features = ref.watch(featuresProvider);

    return AonTactileButton(
      onTap: () => context.go(Routes.map),
      borderRadius: AonSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space5),
        decoration: BoxDecoration(
          color: context.aon.surface,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(color: context.aon.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AonSpacing.space3),
              decoration: BoxDecoration(
                color: context.aon.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
              ),
              child: Icon(
                Icons.map_rounded,
                color: context.aon.accent,
                size: AonSpacing.iconLg,
              ),
            ),
            const SizedBox(width: AonSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.homeOpenMapTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    features.wayfinding
                        ? l.homeOpenMapBody
                        : l.homeOpenMapBodyNoWayfinding,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.aon.contentSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.aon.contentSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Astronomy quick access, driven entirely by [EventConfig.quickAccess].
///
/// Every destination is backed by the official map legend or programme — the
/// list lives in the config so it is reviewable in one place and so another
/// event supplies its own without touching this widget.
class _QuickAccessGrid extends ConsumerWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(eventConfigProvider).quickAccess;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AonSpacing.space3;
        final columns = (constraints.maxWidth / 180).floor().clamp(2, 4);
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _QuickAccessTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAccessTile extends ConsumerWidget {
  const _QuickAccessTile({required this.item});

  final QuickAccessItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final venue = item.venueId == null
        ? null
        : ref.watch(venueByIdProvider(item.venueId!));

<<<<<<< Updated upstream
    // Parking has no single venue — Home asks the visitor which official area
    // they mean instead of silently choosing one. Toilets are similar: the
    // programme names three buildings, so the shortcut opens a chooser too.
    final isParking = item.venueId == null;
    final isToilets = item.id == 'toilets';
=======
    // Two shortcuts are groups, not a single venue: parking asks which official
    // area, and information points lists registration + points 2/3. Both open a
    // chooser rather than silently picking one destination.
    final isParking = item.id == 'parking';
    final isInfoPoints = item.id == 'information-points';
>>>>>>> Stashed changes
    final icon = isParking
        ? Icons.local_parking_rounded
        : isInfoPoints
        ? VenueStyle.iconFor(VenueCategory.informationPoint)
        : VenueStyle.iconFor(venue?.category ?? VenueCategory.other);
    final accent = isParking
        ? context.aon.mapParking
        : isInfoPoints
        ? VenueStyle.colorFor(context, VenueCategory.informationPoint)
        : VenueStyle.colorFor(context, venue?.category ?? VenueCategory.other);

    // The venue's own name as the subtitle — so "Telescopes" is immediately
    // grounded in "Observatory", which is what the printed map calls it.
    // When the shortcut label and venue name are the same word ("Toilets"),
    // repeating it reads as a rendering bug, so use its building instead.
    final venueLabel = venue?.chipLabel;
    final description = isParking
        ? l.quickAccessWalkingRoutes
<<<<<<< Updated upstream
        : isToilets
        ? l.quickAccessToiletsAll
=======
        : isInfoPoints
        ? l.infoRegistrationAndInfo
>>>>>>> Stashed changes
        : (venueLabel == null || venueLabel == item.label(l)
              ? (venue?.building ?? l.infoLocationToBeConfirmed)
              : venueLabel);

    return QuickLinkTile(
      icon: icon,
      label: item.label(l),
      description: description,
      accent: accent,
      onTap: () {
        if (isParking) {
          ParkingChoicesSheet.show(context);
<<<<<<< Updated upstream
        } else if (isToilets) {
          // The three toilet buildings, each with directions and a map pin —
          // the same chooser pattern as parking, so Home never picks one
          // toilet for the visitor when the programme names three.
          ToiletChoicesSheet.show(context);
=======
        } else if (isInfoPoints) {
          InformationPointsSheet.show(context);
>>>>>>> Stashed changes
        } else {
          // Everything else opens the venue sheet, which answers "where is
          // this and what's on here" and offers walking directions only when
          // we actually have an authored route. Sending these straight to the
          // planner dropped five of eight tiles onto an empty screen.
          VenueInfoSheet.show(context, item.venueId!);
        }
      },
    );
  }
}
