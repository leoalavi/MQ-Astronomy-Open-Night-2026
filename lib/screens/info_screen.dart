import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/utils/bidi.dart';
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
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final venues = ref.watch(venuesProvider);
    final parking = ref.watch(parkingProvider);

    List<Venue> byCategory(VenueCategory c) =>
        venues.where((v) => v.category == c).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.infoTitle)),
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
              color: context.aon.surface,
              borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
              border: Border.all(color: context.aon.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(EventInfo.fullName, style: theme.textTheme.titleLarge),
                const SizedBox(height: AonSpacing.space2),
                Text(
                  '${TimeFormat.longDate(EventInfo.startsAt)}\n'
                  '${TimeFormat.range(EventInfo.startsAt, EventInfo.endsAt)}\n'
                  '${EventInfo.host}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.aon.contentSecondary,
                  ),
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
              label: Text(l.passportTitle),
            ),
          ),

          // ── First aid ──
          SectionHeader(
            title: l.infoFirstAid,
            icon: Icons.medical_services_rounded,
            iconColor: context.aon.error,
          ),
          for (final v in byCategory(VenueCategory.firstAid))
            _InfoTile(venue: v),

          // ── Toilets ──
          SectionHeader(
            title: l.infoToilets,
            icon: Icons.wc_rounded,
            iconColor: context.aon.mapFacility,
          ),
          for (final v in byCategory(VenueCategory.toilets))
            _InfoTile(venue: v),

          // ── Information & registration ──
          SectionHeader(
            title: l.infoRegistrationAndInfo,
            icon: Icons.info_rounded,
            iconColor: context.aon.mapFacility,
          ),
          for (final v in [
            ...byCategory(VenueCategory.registration),
            ...byCategory(VenueCategory.informationPoint),
          ])
            _InfoTile(venue: v),

          // ── Food ──
          SectionHeader(
            title: l.infoFoodAndDrink,
            icon: Icons.local_cafe_rounded,
            iconColor: context.aon.tertiary,
          ),
          for (final v in byCategory(VenueCategory.foodAndDrink))
            _InfoTile(venue: v),

          // ── Parking ──
          SectionHeader(
            title: l.infoParking,
            subtitle: l.infoParkingFree,
            icon: Icons.local_parking_rounded,
            iconColor: context.aon.mapParking,
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
                        Icon(
                          Icons.local_parking_rounded,
                          color: context.aon.mapParking,
                          size: AonSpacing.iconMd,
                        ),
                        const SizedBox(width: AonSpacing.space3),
                        Text(p.name, style: theme.textTheme.titleMedium),
                      ],
                    ),
                    if (p.notes != null) ...[
                      const SizedBox(height: AonSpacing.space2),
                      Text(
                        Bidi.isolate(p.notes),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.aon.contentSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AonSpacing.space3),
                    ConfidenceNote(
                      confidence: p.coordinateConfidence,
                      compact: true,
                      message: l.parkingNoConfirmedPosition,
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
              label: Text(l.infoWalkingFromParking),
            ),
          ),

          // ── Transport ──
          SectionHeader(
            title: l.infoGettingHere,
            icon: Icons.train_rounded,
            iconColor: context.aon.mapTransport,
          ),
          for (final v in [
            ...byCategory(VenueCategory.metro),
            ...byCategory(VenueCategory.shuttleStop),
            ...byCategory(VenueCategory.busStop),
          ])
            _InfoTile(venue: v),

          // ── Guidance ──
          SectionHeader(
            title: l.infoBeforeYouCome,
            icon: Icons.checklist_rounded,
          ),
          _Guidance(
            icon: Icons.thermostat_rounded,
            title: l.infoDressTitle,
            body: l.infoDressBody,
          ),
          _Guidance(
            icon: Icons.flashlight_on_rounded,
            title: l.infoTorchTitle,
            body: l.infoTorchBody,
          ),
          _Guidance(
            icon: Icons.confirmation_number_rounded,
            title: l.infoBookTitle,
            body: l.infoBookBody,
          ),
          _Guidance(
            icon: Icons.family_restroom_rounded,
            title: l.infoChildrenTitle,
            body: l.infoChildrenBody,
          ),
          _Guidance(
            icon: Icons.cloud_rounded,
            title: l.infoCloudTitle,
            body: l.infoCloudBody,
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
              color: VenueStyle.colorFor(context, venue.category),
              size: AonSpacing.iconMd,
            ),
            const SizedBox(width: AonSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Bidi.isolate(venue.name),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (venue.building != null &&
                      venue.building != venue.name) ...[
                    const SizedBox(height: 2),
                    Text(
                      Bidi.isolate(venue.building),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.aon.contentTertiary,
                      ),
                    ),
                  ],
                  if (venue.notes != null) ...[
                    const SizedBox(height: AonSpacing.space2),
                    Text(
                      Bidi.isolate(venue.notes),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.aon.contentSecondary,
                      ),
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

/// Opens the Maps SDK's open-source licence text. Renders nothing when the
/// platform has none, because an empty legal page is worse than no button.