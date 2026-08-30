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
| `map-wayfinding.yaml` | Directions FAB → Google consent disclosure (the §2b invariant) → decline returns to the campus map, no network. **Rewritten 2026-08-30**: the old offline origin/destination picker is gone; Directions is now always the consent-gated Google nav. |
| `map-360-picker.yaml` | 360° picker: an early tourable card + the honest "coming soon", the LAST legend card reachable+tappable past the floating tab bar, and its tour opens |

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

4. **The tab-tap percentage is tab-count dependent.** `flows/open-map.yaml` taps
   Map by point. That point was `68%` while the app had five tabs. Settings
   became a sixth, first-class tab, which moved Map into slot 4-of-6 and pointed
   68% at **Info** — every flow in this suite then ran against the wrong screen
   and the failures looked like unrelated assertion bugs. It is now `58%`
   (Map occupies [220,288] of a 440pt bar → centre 57.7%). **If a tab is added
   or removed, recompute it.**

5. **Merged semantics can swallow an entire panel.** Trap 1 gets far worse than
   a two-line row: the wayfinding route panel merges origin, destination,
   duration, distance, every note and every numbered step into ONE newline-
   separated string. Maestro's regex is full-string and `.` does not cross a
   newline, so matching anything inside it needs `(?s)` (DOTALL):
   `assertVisible: "(?s).*Map not shown\\..*"`.

6. **A dialog button's label is not its hit target.** `tapOn: "Not now"` on the
   Google consent dialog reports success and does nothing — Maestro taps the
   Text node rather than the button. Tap it by point.

## Findings this suite surfaced

- The **Directions FAB covers the Metro Station and South 2 pins** at the
  default camera fit; they are present but not hittable until the map is panned.
  `map-markers.yaml` pans before asserting them.
- **Five venues share one coordinate** (Registration, Information 2, Information
  3, Food and drink, Central Courtyard all sit at `-33.7733531,151.1133796`), so
  they stack into identical bounds and only the topmost is tappable. The same
  happens for each toilet paired with its parent venue.
- ~~The wayfinding route preview still renders unattributed OpenStreetMap
  tiles.~~ **RESOLVED 2026-08-23.** Re-verified on an iPhone 17 Pro Max
  simulator: there are no OSM tiles. Choosing a destination now raises the
  Google consent disclosure *before* any map is drawn, and declining leaves the
  screen with no map plus the honest line "Map not shown. The written directions
  below are complete on their own." This is also the first on-device evidence
  for the spec §2b consent invariant — the UI half of it, at least; a packet
  capture is still the only thing that can prove zero traffic.
- **The 360° tours render.** Tour A (Macquarie Theatre) loads its equirectangular
  image in the WKWebView and the scene rail switches Entrance ↔ Theatre foyer.
  Until 2026-08-23 no one had ever seen them run.
- Opening a tour on a device exposed a defect no widget test could see: the
  floating back button and the title island were positioned at the same
  top/left, so the title rendered as "◄acquarie Theatre". Fixed via
  `PanoramaTourView.titleLeadingInset`, guarded by
  `test/widget/panorama_title_clearance_test.dart`.
