import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';

/// Bottom-sheet picker for the single thematic basemap variant. Uses a
/// `RadioGroup` ancestor (Flutter 3.44) — not the deprecated per-tile
/// `groupValue`/`onChanged`. Exactly one selection; base is an explicit row.
class CampusVariantPicker extends ConsumerWidget {
  const CampusVariantPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final selected = ref.watch(campusVariantProvider);
    return SafeArea(
      child: SingleChildScrollView(
        child: RadioGroup<CampusMapVariant>(
          groupValue: selected,
          // A null (framework deselect) maps to base in the controller.
          onChanged: (v) => ref.read(campusVariantProvider.notifier).select(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AonSpacing.space5,
                    AonSpacing.space4, AonSpacing.space5, AonSpacing.space2),
                child: Text(l.mapLayersTitle,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              RadioListTile<CampusMapVariant>(
                value: CampusMapVariant.base,
                title: Text(l.mapVariantBase),
              ),
              for (final v in CampusVariantsData.eventVisible)
                RadioListTile<CampusMapVariant>(
                  value: v.variant,
                  title: Text(_label(l, v.variant)),
                  subtitle: Text(_desc(l, v.variant)),
                  secondary: _Swatch(color: v.swatch),
                ),
              const SizedBox(height: AonSpacing.space4),
            ],
          ),
        ),
      ),
    );
  }

  String _label(AonL10n l, CampusMapVariant v) => switch (v) {
        CampusMapVariant.parking => l.mapVariantParking,
        CampusMapVariant.accessibility => l.mapVariantAccessibility,
        CampusMapVariant.water => l.mapVariantWater,
        _ => l.mapVariantBase,
      };

  String _desc(AonL10n l, CampusMapVariant v) => switch (v) {
        CampusMapVariant.parking => l.mapVariantParkingDesc,
        CampusMapVariant.accessibility => l.mapVariantAccessibilityDesc,
        CampusMapVariant.water => l.mapVariantWaterDesc,
        _ => '',
      };
}

/// A legend colour chip. Uses the source-legend ink colour directly (documented
/// `context.aon` exemption); the ring uses theme chrome.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: AonSpacing.iconMd,
        height: AonSpacing.iconMd,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.aon.contentTertiary, width: 1),
        ),
      );
}
