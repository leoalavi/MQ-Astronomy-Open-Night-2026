import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';

/// A titled section divider used down the length of the scrolling screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.count,
    this.icon,
    this.iconColor,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Item count, rendered as a pill after the title.
  final int? count;

  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        top: AonSpacing.space6,
        bottom: AonSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AonSpacing.iconMd,
                  color: iconColor ?? context.aon.accent,
                ),
                const SizedBox(width: AonSpacing.space2),
              ],
              Flexible(
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              if (count != null) ...[
                const SizedBox(width: AonSpacing.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AonSpacing.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.aon.surfaceRaised,
                    borderRadius:
                        BorderRadius.circular(AonSpacing.radiusFull),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: context.aon.contentSecondary),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AonSpacing.space1),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.aon.contentTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
