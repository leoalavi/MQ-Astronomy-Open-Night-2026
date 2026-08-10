import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/panorama_tour_view.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';

/// Immersive full-screen 360° tour for a venue. Pushed above the tab shell.
///
/// Safety: the tour is resolved by an EXACT `panorama_data` lookup — an unknown
/// or tour-less `venueId` (incl. a hostile deep link) yields the unavailable
/// state, never an arbitrary asset read. Missing/empty/errored manifests do the
/// same. There is always a back affordance so the user is never trapped.
class PanoramaScreen extends ConsumerWidget {
  const PanoramaScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tour = PanoramaData.tourFor(venueId);
    final venue = ref.watch(venueByIdProvider(venueId));
    final title = venue?.name ?? '360° preview';

    Widget body;
    if (tour == null) {
      body = const PanoramaUnavailable();
    } else {
      body = ref.watch(indoorManifestProvider(venueId)).when(
            data: (m) => (m == null || m.isEmpty)
                ? const PanoramaUnavailable()
                : PanoramaTourView(
                    manifest: m,
                    title: title,
                    firstSceneId: m.nodes.first.id,
                  ),
            loading: () => const PanoramaUnavailable(loading: true),
            error: (_, _) => const PanoramaUnavailable(),
          );
    }

    return Scaffold(
      backgroundColor: AonColors.night950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          Positioned(
            top: MediaQuery.paddingOf(context).top + AonSpacing.space3,
            left: AonSpacing.space4,
            child: GlassSurface(
              variant: GlassVariant.control,
              allowShader: false,
              borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
              padding: EdgeInsets.zero,
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AonColors.contentPrimary),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
