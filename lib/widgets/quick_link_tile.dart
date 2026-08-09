import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

/// A large home-screen shortcut.
///
/// Sized generously (minimum 96pt tall, well beyond the 56pt tap target) —
/// these are the four things someone reaches for while walking, so they are
/// built to be hit without looking carefully.
class QuickLinkTile extends StatelessWidget {
  const QuickLinkTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    required this.accent,
    super.key,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AonTactileButton(
      onTap: onTap,
      borderRadius: AonSpacing.radiusMd, // focus ring / pressed outline match the tile corners
      child: Material(
        color: AonColors.night900,
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(AonSpacing.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
            border: Border.all(color: AonColors.night700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AonSpacing.space2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
                ),
                child: Icon(
                  icon,
                  size: AonSpacing.iconMd,
                  color: accent,
                ),
              ),
              const SizedBox(height: AonSpacing.space3),
              Text(label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AonColors.contentTertiary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
