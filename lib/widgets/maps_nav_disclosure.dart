import 'package:flutter/material.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';

/// Consent disclosure shown BEFORE any location read or Google call: it tells
/// the user their current location will be sent to Google Maps to compute a
/// walking route. Returns `true` (accept) / `false` (decline). The caller maps
/// the result onto [MapsConsent] and only then proceeds.
class MapsNavDisclosure extends StatelessWidget {
  const MapsNavDisclosure({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      // scrollable so title + body + actions scroll together rather than
      // overflowing at small screens / large text scale (320×568 @ 2.0).
      scrollable: true,
      backgroundColor: context.aon.surface,
      title: Text(l.mapNavDisclosureTitle),
      content: Text(
        l.mapNavDisclosureBody,
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
Future<bool> showMapsNavDisclosure(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (_) => const MapsNavDisclosure(),
  );
  return accepted ?? false;
}
