import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/services/preview_location.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';

/// Consent disclosure shown BEFORE any location read or Google call: it tells
/// the user their current location will be sent to Google Maps to compute a
/// walking route. Returns `true` (accept) / `false` (decline). The caller maps
/// the result onto [MapsConsent] and only then proceeds.
/// Which truth this disclosure is telling.
///
/// [navigation] — the surface captures a location snapshot and sends it to the
/// Routes API. [mapDisplay] — the surface renders a Google basemap but reads no
/// location (wayfinding, whose routes are hand-authored and bundled offline).
/// One [MapsConsent] covers both, so [mapDisplay]'s copy also discloses what the
/// grant permits on the navigation surface: otherwise accepting here would
/// silently authorise sending location there.
enum MapsDisclosureKind { navigation, mapDisplay }

class MapsNavDisclosure extends ConsumerWidget {
  const MapsNavDisclosure({
    super.key,
    this.kind = MapsDisclosureKind.navigation,
  });

  final MapsDisclosureKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    // Under preview mode `navOriginProvider` reads the effective service and
    // sends the SIMULATED coordinate to Google. Saying "your current location"
    // then would misdescribe what is actually transmitted.
    final previewing = ref.watch(previewLocationProvider);
    final (title, body) = switch (kind) {
      MapsDisclosureKind.navigation => (
          l.mapNavDisclosureTitle,
          previewing ? l.mapNavDisclosureBodyPreview : l.mapNavDisclosureBody
        ),
      MapsDisclosureKind.mapDisplay => (
          l.mapDisplayDisclosureTitle,
          l.mapDisplayDisclosureBody
        ),
    };
    return AlertDialog(
      // scrollable so title + body + actions scroll together rather than
      // overflowing at small screens / large text scale (320×568 @ 2.0).
      scrollable: true,
      backgroundColor: context.aon.surface,
      title: Text(title),
      content: Text(
        body,
        style: theme.textTheme.bodyMedium?.copyWith(color: context.aon.contentSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AonSpacing.space2, 0, AonSpacing.space2, AonSpacing.space2),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.mapNavDisclosureDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.mapNavDisclosureAccept),
        ),
      ],
    );
  }
}

/// Shows [MapsNavDisclosure] and resolves to whether the user accepted.
/// A barrier dismiss counts as decline (`false`).
Future<bool> showMapsNavDisclosure(
  BuildContext context, {
  MapsDisclosureKind kind = MapsDisclosureKind.navigation,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (_) => MapsNavDisclosure(kind: kind),
  );
  return accepted ?? false;
}
