import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';

/// The "nothing here" placeholder.
///
/// Always offers an action where one exists. An empty programme with no way
/// out is a dead end, and on a phone in the dark a user is far more likely to
/// close the app than to work out that they need to clear a filter.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Centred when it fits, scrollable when it doesn't.
    //
    // The hero icon, title, body and action button together need roughly 300pt.
    // On a 320x568 phone, minus a status bar, an app bar and a bottom nav, the
    // body has ~430pt — but at 150% text the copy wraps to five lines and the
    // Column overflowed by 18pt, clipping the action button. An empty state
    // whose only way out is a button you cannot reach is a dead end, which is
    // the exact failure this widget exists to prevent.
    //
    // maxHeight is infinite when we are already inside a ListView (Wayfinding
    // renders two of these as list children). A SingleChildScrollView there
    // would assert on unbounded height, so in that case the ancestor already
    // owns scrolling and we hand back the intrinsic Column.
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _content(context);
        if (!constraints.hasBoundedHeight) return content;

        return SingleChildScrollView(
          child: ConstrainedBox(
            // Fill the viewport so Center still centres when there is room;
            // once the content is taller than this, the scroll view takes over.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AonSpacing.iconHero,
              color: context.aon.borderStrong,
            ),
            const SizedBox(height: AonSpacing.space4),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AonSpacing.space2),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.aon.contentTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AonSpacing.space5),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
