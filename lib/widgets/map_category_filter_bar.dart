import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/utils/haptics.dart';

/// Horizontal category filter row for the map.
///
/// Extracted from the map screen's private `_CategoryFilterBar` so it can be
/// widget-tested **without** mounting the live `FlutterMap` (spec P1-#1). It is
/// map-specific presentation, not a glass primitive: the state (`selected`) lives
/// in `MapScreen`; this widget only renders + reports toggles.
///
/// Faithful to the reference `_CategoryChip`: glass carries only the *inactive*
/// state; the selected chip is solid brand amber.
class MapCategoryFilterBar extends StatelessWidget {
  const MapCategoryFilterBar({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<VenueCategory> selected;
  final ValueChanged<VenueCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    // Chips the map deliberately does not offer. `other` is the uncategorised
    // sentinel. First aid has no verified coordinate (docs/data-sources.md) —
    // it renders no marker, so a chip that filters nothing is dead UI. Metro
    // stays: it has an approximated-but-real coordinate and is a useful
    // destination.
    const hidden = {
      VenueCategory.other,
      VenueCategory.firstAid,
    };
    final categories = VenueCategory.values
        .where((c) => !hidden.contains(c))
        .toList(growable: false);
    return SizedBox(
      height: 60, // holds the >=56 chip target with breathing room
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AonSpacing.space4),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AonSpacing.space2),
        itemBuilder: (context, i) {
          final category = categories[i];
          return _MapCategoryChip(
            category: category,
            isSelected: selected.contains(category),
            onTap: () {
              AonHaptics.select();
              onToggle(category);
            },
          );
        },
      ),
    );
  }
}

class _MapCategoryChip extends StatelessWidget {
  const _MapCategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final VenueCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = VenueStyle.colorFor(context, category);
    // `VenueCategory.label` is the English diagnostic name; the visitor sees the
    // ARB string. Every other surface already used `labelOf` — the map's filter
    // chips were the last place still shipping "Event venue" into a Persian UI.
    final label = category.labelOf(AonL10n.of(context));
    final fg = isSelected ? context.aon.onAccent : context.aon.contentPrimary;
    final radius = BorderRadius.circular(AonSpacing.radiusFull);

    final tappable = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AonSpacing.minTapTarget),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AonSpacing.space3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    VenueStyle.iconFor(category),
                    size: AonSpacing.iconSm,
                    color: isSelected ? context.aon.onAccent : categoryColor,
                  ),
                  const SizedBox(width: AonSpacing.space2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // labelMedium matches the density of the Material FilterChip
                    // this replaced (aon_theme chipTheme.labelStyle).
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Widget visual = isSelected
        ? DecoratedBox(
            decoration: BoxDecoration(color: context.aon.accent, borderRadius: radius),
            child: tappable,
          )
        : GlassSurface(
            variant: GlassVariant.control,
            borderRadius: radius,
            borderColor: categoryColor.withValues(alpha: 0.5),
            child: tappable,
          );

    // One coherent semantics node; the inner visual is excluded so the label is
    // read exactly once (spec P2-#7).
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(child: visual),
    );
  }
}
