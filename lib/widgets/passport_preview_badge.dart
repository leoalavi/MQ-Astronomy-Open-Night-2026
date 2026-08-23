import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/passport_preview.dart';

/// Renders nothing unless passport preview is engaged.
///
/// Same rule as [PreviewLocationBadge], for the same reason: the Settings
/// switch explains itself, but it is not on screen while someone is looking at
/// their stamps. A practice stamp must never be mistaken for one earned at a
/// venue, so the label travels with the passport rather than living where the
/// switch is.
class PassportPreviewBadge extends ConsumerWidget {
  const PassportPreviewBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(passportPreviewProvider)) return const SizedBox.shrink();

    return Container(
      key: const Key('passport-preview-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.aon.info.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
      ),
      child: Text(
        AonL10n.of(context).passportPreviewBadge,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: context.aon.info),
      ),
    );
  }
}
