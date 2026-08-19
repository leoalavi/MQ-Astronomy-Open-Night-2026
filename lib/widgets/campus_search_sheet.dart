import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/search_providers.dart';

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
            if (results.isEmpty && query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AonSpacing.space5),
                child: Text(l.mapSearchEmpty(query),
                    style: TextStyle(color: context.aon.contentSecondary)),
              )
            else
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
