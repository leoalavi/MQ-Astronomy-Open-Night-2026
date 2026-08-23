import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/search_providers.dart';

/// Popped by the search sheet when the visitor picks the parking action card.
/// MapScreen routes this to the Wayfinding planner (which lists every car park
/// and its walking route) instead of a map pin — the carparks sit at the campus
/// edges and West 6 has no confirmed coordinate, so a pin would be false.
const kParkingSearchAction = '__parking__';

/// Whether [query] reads as a parking search. Kept liberal on purpose: a parent
/// types "parking", "car park", or a specific bay like "West 5" / "South 2".
bool looksLikeParkingQuery(String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return false;
  const terms = [
    'parking', 'car park', 'carpark', 'park',
    'west 5', 'west5', 'west 6', 'west6', 'south 2', 'south2',
    // Persian: پارکینگ / پارک / وست ۵ / وست ۶ / ساوث ۲
    'پارکینگ', 'پارک', 'ماشین', 'خودرو',
    'وست ۵', 'وست ۶', 'وست', 'ساوث ۲', 'ساوث',
  ];
  return terms.any((t) => q.contains(t));
}

/// Full-height search sheet. Layout is `Column(header, Expanded(ListView))` —
/// NOT a ListView inside a scroll view (G19). Selecting a row pops the sheet
/// with the chosen `PlaceKey`; MapScreen orchestrates the rest (§0b.F).
class CampusSearchSheet extends ConsumerStatefulWidget {
  const CampusSearchSheet({super.key});

  @override
  ConsumerState<CampusSearchSheet> createState() => _CampusSearchSheetState();
}

class _CampusSearchSheetState extends ConsumerState<CampusSearchSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(mapSearchQueryProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final query = ref.watch(mapSearchQueryProvider);
    final results = ref.watch(mapSearchResultsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AonSpacing.space4, AonSpacing.space4,
                  AonSpacing.space4, AonSpacing.space2),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) =>
                    ref.read(mapSearchQueryProvider.notifier).setQuery(v),
                decoration: InputDecoration(
                  labelText: l.mapSearchTitle,
                  hintText: l.mapSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (looksLikeParkingQuery(query))
              Padding(
                padding: const EdgeInsets.fromLTRB(AonSpacing.space4, 0,
                    AonSpacing.space4, AonSpacing.space2),
                child: Card(
                  color: context.aon.accent.withValues(alpha: 0.12),
                  child: ListTile(
                    key: const Key('search-parking-action'),
                    leading: Icon(Icons.local_parking_rounded,
                        color: context.aon.accent),
                    title: Text(l.mapSearchParkingTitle),
                    subtitle: Text(l.mapSearchParkingBody),
                    trailing: const Icon(Icons.directions_walk_rounded),
                    onTap: () => Navigator.of(context).pop(kParkingSearchAction),
                  ),
                ),
              ),
            if (results.isEmpty &&
                query.trim().isNotEmpty &&
                !looksLikeParkingQuery(query))
              Padding(
                padding: const EdgeInsets.all(AonSpacing.space5),
                child: Text(l.mapSearchEmpty(query),
                    style: TextStyle(color: context.aon.contentSecondary)),
              )
            else if (results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final e = results[i];
                    // A place with no map coordinate is list-only: say so and use
                    // a location-off icon rather than a normal pin (map audit P2).
                    final placeable = isPlaceableOnMap(e);
                    return ListTile(
                      leading: Icon(!placeable
                          ? Icons.location_off_rounded
                          : (e.kind == PlaceKind.building
                              ? Icons.business_rounded
                              : Icons.place_rounded)),
                      title: Text(e.title),
                      subtitle: !placeable
                          ? Text(l.mapPlaceListOnly,
                              style: TextStyle(color: context.aon.contentTertiary))
                          : (e.subtitle == null ? null : Text(e.subtitle!)),
                      onTap: () => Navigator.of(context).pop(e.placeKey),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
