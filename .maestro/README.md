# Map E2E suite (Maestro)

End-to-end coverage for the campus map, run against a booted iOS simulator with
the app installed. These complement `flutter test` — they exercise the things a
widget test cannot: real `CrsSimple` camera fitting, real GPS through
`geolocator`, the real basemap raster, and the real iOS permission flow.

## Run

```bash
# build + install once
flutter build ios --simulator --debug
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app

maestro test .maestro/                       # everything
maestro test .maestro/map-basemap.yaml       # one flow
maestro test --include-tags smoke .maestro/  # quick gate
```

| Flow | Covers |
|---|---|
| `map-basemap.yaml` | official AON artwork renders; camera frames the whole published sheet; zoom controls; **regression: the retired M2 Layers button stays gone** |
| `map-markers.yaml` | all A–I venues + facilities pinned; venue/parking sheets open; category filters add and remove pin classes |
| `map-search-favorites.yaml` | idle browse, venue query, building query out of `buildings.json`, selection opens the right sheet, favourites |
| `map-location.yaml` | locate → iOS permission → dot on the artwork → follow state; a far fix yields the honest distance banner, never a clamped dot |
| `map-modes.yaml` | Map / 360° / Compass switching; walk-route FAB is campus-map only; compass degrades to the honest cardinal LIST (no magnetometer on the simulator) |
| `map-wayfinding.yaml` | Directions FAB → start/destination picker → route preview |

## Selector gotchas in THIS app

Flutter + Maestro + a bilingual app produce three traps. All are worked around
in the flows, with comments at each site.

1. **Merged semantics.** Flutter merges a row's title and subtitle into ONE
   accessibility string joined by a newline — `"Mason Theatre\nEvent venue"`.
   Maestro's `text:` is a **full-string** regex, so the partial
   `"Mason Theatre"` does **not** match. Use the whole two-line string.

2. **Bidi isolates.** Any label built from an l10n *placeholder* is wrapped by
   Flutter in `U+2068 … U+2069` because the app ships EN + Persian. The
   wayfinding chip is literally `"⁨Observatory⁩"`. Wrap in `.*`.

3. **Ambiguous "Map".** Three different things are exactly `"Map"` — the AppBar
   title, the mode-toggle segment, and the bottom-nav tab (which becomes
   `"Map\nMap"` once selected). The toggle is `text: "Map", index: 1`; the tab
   is tapped **by point**, because the animated `LiquidTabBar` pill shifts its
   neighbours mid-tap and stale bounds hit the wrong tab.

`leftOf:` / `rightOf:` do **not** disambiguate 1 and 3 — they ignore row
alignment and still match the AppBar title.

## Findings this suite surfaced

- The **Directions FAB covers the Metro Station and South 2 pins** at the
  default camera fit; they are present but not hittable until the map is panned.
  `map-markers.yaml` pans before asserting them.
- **Five venues share one coordinate** (Registration, Information 2, Information
  3, Food and drink, Central Courtyard all sit at `-33.7733531,151.1133796`), so
  they stack into identical bounds and only the topmost is tappable. The same
  happens for each toilet paired with its parent venue.
- The wayfinding route preview is the app's **last live-network surface** — it
  still renders OpenStreetMap tiles with no visible attribution. See the note in
  `map-wayfinding.yaml`.
