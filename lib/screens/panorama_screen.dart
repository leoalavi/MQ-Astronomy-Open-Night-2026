import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
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
/// Passes taps through the web 360° `<iframe>` to the Flutter control on top.
/// No-op on native.
Widget _maybeIntercept(Widget child) =>
    kIsWeb ? PointerInterceptor(child: child) : child;

class PanoramaScreen extends ConsumerWidget {
  const PanoramaScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final tour = PanoramaData.tourFor(venueId);
    final venue = ref.watch(venueByIdProvider(venueId));
    final title = venue?.name ?? l.panorama360Title;

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
                    // Reserve room for the back button this screen floats over
                    // the title island; both sit at the same top/left.
                    titleLeadingInset: AonSpacing.minTapTarget,
                    firstSceneId: m.nodes.first.id,
                  ),
            loading: () => const PanoramaUnavailable(loading: true),
            error: (_, _) => const PanoramaUnavailable(),
          );
    }

    return Scaffold(
      backgroundColor: context.aon.surfaceBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          Positioned(
            top: MediaQuery.paddingOf(context).top + AonSpacing.space3,
            left: AonSpacing.space4,
            // On web the 360° viewer is an <iframe> platform view that would
            // otherwise swallow this button's taps; PointerInterceptor lets
            // them through. No-op wrap on native (gated on kIsWeb).
            child: _maybeIntercept(GlassSurface(
              variant: GlassVariant.control,
              allowShader: false,
              borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
              padding: EdgeInsets.zero,
              child: IconButton(
                tooltip: l.actionBack,
                icon: Icon(Icons.arrow_back_rounded,
                    color: context.aon.contentPrimary),
                onPressed: () => context.pop(),
              ),
            )),
          ),
        ],
      ),
    );
  }
}
