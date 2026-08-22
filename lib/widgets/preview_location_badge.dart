import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/preview_location.dart';

/// Renders nothing unless preview mode is on.
///
/// Spec §3c: a simulated fix must never be presented as a real one. The Settings
/// toggle explains itself, but it is not on screen when the visitor is looking
/// at the map, the compass or the nearby list — so the label travels with the
/// position instead of living where the switch is.
class PreviewLocationBadge extends ConsumerWidget {
  const PreviewLocationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(previewLocationProvider)) return const SizedBox.shrink();

    return Container(
      key: const Key('preview-location-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.aon.info.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
      ),
      child: Text(
        AonL10n.of(context).previewLocationBadge,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: context.aon.info),
      ),
    );
  }
}
