import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/section_header.dart';

/// Practical information: facilities, transport, parking and event guidance.
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final venues = ref.watch(venuesProvider);
    final parking = ref.watch(parkingProvider);

    List<Venue> byCategory(VenueCategory c) =>
        venues.where((v) => v.category == c).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Useful information'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonNavMetrics.clearance(context),
        ),
        children: [
          // ── The essentials ──
          Container(
            margin: const EdgeInsets.only(top: AonSpacing.space4),
            padding: const EdgeInsets.all(AonSpacing.space4),
            decoration: BoxDecoration(
              color: AonColors.night900,
              borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
              border: Border.all(color: AonColors.night700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(EventInfo.fullName, style: theme.textTheme.titleLarge),
                const SizedBox(height: AonSpacing.space2),
                Text(
                  '${TimeFormat.longDate(EventInfo.startsAt)}\n'
                  '${TimeFormat.range(
                    EventInfo.startsAt,
                    EventInfo.endsAt,
                  )}\n'
                  '${EventInfo.host}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AonColors.contentSecondary),
                ),
              ],
            ),
          ),

          // ── Astronomy Passport ──
          const SizedBox(height: AonSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.passport),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Astronomy Passport'),
            ),
          ),

          // ── First aid ──
          const SectionHeader(
            title: 'First aid',
            icon: Icons.medical_services_rounded,
            iconColor: AonColors.error,
          ),
          for (final v in byCategory(VenueCategory.firstAid))
            _InfoTile(venue: v),

          // ── Toilets ──
          const SectionHeader(
            title: 'Toilets',
            icon: Icons.wc_rounded,
            iconColor: AonColors.mapFacility,
          ),
          for (final v in byCategory(VenueCategory.toilets))
            _InfoTile(venue: v),

          // ── Information & registration ──
          const SectionHeader(
            title: 'Registration and information',
            icon: Icons.info_rounded,
            iconColor: AonColors.mapFacility,
          ),
          for (final v in [
            ...byCategory(VenueCategory.registration),
            ...byCategory(VenueCategory.informationPoint),
          ])
            _InfoTile(venue: v),

          // ── Food ──
          const SectionHeader(
            title: 'Food and drink',
            icon: Icons.local_cafe_rounded,
            iconColor: AonColors.nebula,
          ),
          for (final v in byCategory(VenueCategory.foodAndDrink))
            _InfoTile(venue: v),

          // ── Parking ──
          SectionHeader(
            title: 'Parking',
            subtitle: 'Free event parking',
            icon: Icons.local_parking_rounded,
            iconColor: AonColors.mapParking,
            count: parking.length,
          ),
          for (final p in parking)
            Card(
              margin: const EdgeInsets.only(bottom: AonSpacing.space3),
              child: Padding(
                padding: const EdgeInsets.all(AonSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_parking_rounded,
                          color: AonColors.mapParking,
                          size: AonSpacing.iconMd,
                        ),
                        const SizedBox(width: AonSpacing.space3),
                        Text(p.name, style: theme.textTheme.titleMedium),
                      ],
                    ),
                    if (p.notes != null) ...[
                      const SizedBox(height: AonSpacing.space2),
                      Text(
                        p.notes!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AonColors.contentSecondary),
                      ),
                    ],
                    const SizedBox(height: AonSpacing.space3),
                    ConfidenceNote(
                      confidence: p.coordinateConfidence,
                      compact: true,
                      message:
                          'We don’t have a confirmed position for this car '
                          'park yet — follow on-site signage.',
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.wayfinding),
              icon: const Icon(Icons.directions_walk_rounded),
              label: const Text('Walking directions from parking'),
            ),
          ),

          // ── Transport ──
          const SectionHeader(
            title: 'Getting here',
            icon: Icons.train_rounded,
            iconColor: AonColors.mapTransport,
          ),
          for (final v in [
            ...byCategory(VenueCategory.metro),
            ...byCategory(VenueCategory.shuttleStop),
            ...byCategory(VenueCategory.busStop),
          ])
            _InfoTile(venue: v),

          // ── Guidance ──
          const SectionHeader(
            title: 'Before you come',
            icon: Icons.checklist_rounded,
          ),
          const _Guidance(
            icon: Icons.thermostat_rounded,
            title: 'Dress for standing outside',
            body: 'The Telescope Park and the Central Courtyard are open '
                'ground, and September evenings get cold. Bring a jacket.',
          ),
          const _Guidance(
            icon: Icons.flashlight_on_rounded,
            title: 'Bring a torch — red light if you have it',
            body: 'It gets genuinely dark towards the Observatory, and that '
                'is on purpose. White light ruins night vision for everyone '
                'around you, so use a red torch mode near the telescopes and '
                'turn your phone brightness down.',
          ),
          const _Guidance(
            icon: Icons.confirmation_number_rounded,
            title: 'Book the ticketed shows early',
            body: 'The physics and chemistry magic shows and Destination '
                'Moon need seats pre-booked at the time of ticket purchase.',
          ),
          const _Guidance(
            icon: Icons.family_restroom_rounded,
            title: 'Children must be supervised',
            body: 'Children must be accompanied by a parent or guardian at '
                'all times in the Kids’ space.',
          ),
          const _Guidance(
            icon: Icons.cloud_rounded,
            title: 'If it clouds over',
            body: 'Telescope viewing depends on the weather, but the '
                'planetarium sessions at the Sport and Aquatic Centre run '
                'regardless.',
          ),

          // ── Credits ──
          const SectionHeader(title: 'Credits'),
          Text(
            'Event materials, campus map and branding © Macquarie University, '
            '${EventInfo.faculty}. ${EventInfo.cricosProvider}.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
          const SizedBox(height: AonSpacing.space2),
          Text(
            'Hero image: “A Deep Triangulum Galaxy” — Aleix Roig, 2026. '
            'Used with permission for this project.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
          const SizedBox(height: AonSpacing.space2),
          Text(
            'Map data © OpenStreetMap contributors.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
          const SizedBox(height: AonSpacing.space2),
          Text(
            '${EventInfo.socialHandle}  ${EventInfo.hashtag}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AonSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              VenueStyle.iconFor(venue.category),
              color: VenueStyle.colorFor(venue.category),
              size: AonSpacing.iconMd,
            ),
            const SizedBox(width: AonSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: theme.textTheme.titleSmall),
                  if (venue.building != null &&
                      venue.building != venue.name) ...[
                    const SizedBox(height: 2),
                    Text(
                      venue.building!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AonColors.contentTertiary),
                    ),
                  ],
                  if (venue.notes != null) ...[
                    const SizedBox(height: AonSpacing.space2),
                    Text(
                      venue.notes!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AonColors.contentSecondary),
                    ),
                  ],
                  if (!venue.coordinateConfidence.isReliable ||
                      !venue.hasCoordinates) ...[
                    const SizedBox(height: AonSpacing.space2),
                    ConfidenceNote(
                      confidence: venue.coordinateConfidence,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Guidance extends StatelessWidget {
  const _Guidance({
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
