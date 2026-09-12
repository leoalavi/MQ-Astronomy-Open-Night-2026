# Frontend ↔ backend integration checklist

**Frontend owner:** Leo Alavi · **Backend / map / 3D owner:** Raouf

This is the contract between the two halves. It records what the frontend
consumes today, what it consumes from Raouf's existing code, and what is still
fixture-backed and awaiting a real implementation.

**Nothing in `lib/` reads a backend internal directly.** Every crossing point
below is a provider or a small typed lookup, so replacing a fixture with a real
source is a change in one file.

---

## 1. Already integrated (Raouf's code, consumed as-is)

The frontend **does not modify** any of these. They are consumed exactly as
implemented.

| Contract | Owner's API | Where the frontend uses it |
|---|---|---|
| Venue → 360° tour | `PanoramaData.tourFor(venueId)` / `hasTour(venueId)` | `venuesWithPanoramaProvider` |
| Tour availability set | `PanoramaData.tours` | Map venue sheet, event detail, `PanoramaBuildingPicker` |
| Indoor manifest load | `indoorManifestProvider(venueId)` → `IndoorManifest?` | `PanoramaScreen` |
| Viewer host | `PanoramaScreen`, `PanoramaTourView`, `PanoramaWebView` | Pushed at `/panorama/:venueId` |
| Local asset server | `panoramaServer.ensureStarted()` | Owned entirely by the panorama stack |
| Navigation-safety policy | `isAllowedViewerUrl(url)` | Untouched |

### Rules the frontend follows

1. **Availability is asked, never assumed.** The 360° button renders only when
   `venuesWithPanoramaProvider` contains the venue id. The frontend never
   constructs an asset path or guesses a scene id.
2. **No tour ⇒ no button.** Not a disabled button — the brief is explicit that
   raw ids and "scene not found" must never reach the visitor.
3. **Stable ids only.** Venue identity crosses the boundary as
   `Venue.id` (`'macquarie-theatre'`), never a display string. Renaming a venue
   in `venues_data.dart` must not break a tour lookup.

### One thing to confirm

`PanoramaData` currently ships **one** tour (`macquarie-theatre`, flagged
`placeholder: true`). Everything downstream is driven off that list, so adding
tours needs no frontend change. Please confirm the venue ids you intend to use
match `VenuesData` exactly — the lookup is intentionally exact-match, so a near
miss silently yields "not available" rather than an error.

---

## 2. Fixture-backed today — ready for your implementation

These are local `const` Dart data. Each has a provider seam: swap the provider
body for a `FutureProvider` over your source and the UI keeps working, because
every consumer already handles `AsyncValue` or a null result.

| Data | Fixture | Provider seam | Notes |
|---|---|---|---|
| Programme (36 items) | `lib/data/events_data.dart` | `eventsProvider` | Transcribed from the official PDF |
| Venues (20) | `lib/data/venues_data.dart` | `venuesProvider` | Stable ids; see below |
| Parking (3) | `lib/data/parking_data.dart` | `parkingProvider` | West 6 has **no** coordinate on purpose |
| Walking routes (9) | `lib/data/routes_data.dart` | `routesProvider` | All draft, see `navigation-strategy.md` |

### Model shapes the frontend expects

```dart
AonEvent {
  String  id;                 // stable
  String  title;              // official wording
  String  description;
  EventCategory category;     // activity | shortTalk | keynote | featuredPresentation
  List<EventSession> sessions;// >= 1; multiple = the same activity run twice
  String  venueId;            // MUST resolve in venuesProvider
  String? room;               // 'Room 108', 'Theatre 3'
  String? presenter;
  String? mapReference;       // printed-map legend letter A–I
  bool    bookingRequired;
  List<String> tags;
  String? sourceNote;         // provenance
}

EventSession { DateTime start; DateTime end; DataConfidence timeConfidence; String? note; }

Venue {
  String  id;                 // stable — the AR/map join key
  String  name;               // official
  String? shortName;          // chip-length label
  VenueCategory category;
  double? latitude, longitude;
  double? entranceLatitude, entranceLongitude;   // preferred routing target
  DataConfidence coordinateConfidence;
  String? mapReference;
  List<String> aliases;
}
```

`DataConfidence` is `confirmed | derived | placeholder`. **Please preserve it**
if you move this data to Supabase — the UI renders a visible "still to be
confirmed" note off the back of it, and dropping the field would silently
present guesses as facts.

### If you move the programme to Supabase

`timedEventsProvider`, `filteredEventsProvider` and `itineraryProvider` all
derive from `eventsProvider`. Making that one provider async is the whole
change; add a skeleton state to the four screens that consume it and nothing
else moves.

---

## 3. Not started — needs a contract from you

### QR / scan

The Scan feature is **switched off** in the event config
(`EventFeatures.scan == false`), so no dead UI ships. To turn it on I need:

| Field | Question |
|---|---|
| Payload format | What does an Astronomy QR encode — a venue id, an activity id, or an opaque token? |
| Resolution | Is there a `resolveQr(payload)` API, or is the mapping bundled? |
| Trust | Signed like the Open Day stamp QRs, or unsigned? |
| Failure | What should an unrecognised/expired code show? |

Once those are answered the frontend flow is: **scan → venue/activity card →
save to My Night → view on map → 360° where available.** No mapping will be
hardcoded in a widget.

### Live programme updates

Not built. If activities can be cancelled or moved *on the night*, we need a
push or poll channel, and the fixture→`FutureProvider` swap above.

### Wayfinding geometry

`WalkingRoute.points` currently holds two-point straight lines rendered
**dashed** with an on-screen "general direction, not the exact path" caption.
If your map data can supply surveyed path geometry (GPX or a coordinate list),
drop it into `points` and set `pathConfidence: DataConfidence.confirmed` — the
line renders solid automatically. No frontend change required.

---

## 3b. Changes since the first pass (light theme + l10n)

Two cross-cutting migrations landed. Both are mechanical from your side, but
you should know about them before your next merge.

### Colours now come from a ThemeExtension

`AonColors`' static tokens were replaced by `AonPalette`, resolved per
brightness and read as **`context.aon.<token>`**. The app now ships a real
light theme, so a `static const Color` can no longer be correct.

Token renames (role-based, because "night900" is wrong in light mode):

| Was | Now |
|---|---|
| `AonColors.night950` | `context.aon.surfaceBase` |
| `AonColors.night900` | `context.aon.surface` |
| `AonColors.night800` | `context.aon.surfaceRaised` |
| `AonColors.night700` | `context.aon.border` |
| `AonColors.night600` | `context.aon.borderStrong` |
| `AonColors.amber` | `context.aon.accent` |
| `AonColors.stellar` | `context.aon.info` |
| `AonColors.nebula` | `context.aon.tertiary` |

`VenueStyle.colorFor(...)` and `colorForEventCategory(...)` now take a
`BuildContext` as their first argument. The icon lookups are unchanged.

### Strings come from ARB

English + Persian only (`lib/l10n/`). Widgets read `AonL10n.of(context)`.
If you add user-facing copy, add a key rather than a literal — there is a test
(`localisation_rtl_test.dart`) that fails on hardcoded Astronomy strings.

### One thing to look at in your code

`lib/widgets/passport_grid.dart` imports `data/venues_data.dart` **directly**
rather than reading `venuesProvider`. Everything else in `lib/screens` and
`lib/widgets` goes through a provider, which is what will let the fixtures be
swapped for Supabase in one file. The fixture-boundary test currently exempts
`passport_*` and `panorama_*` so it does not fail your work — but that exemption
is a placeholder, not an endorsement. Worth a one-line change when convenient.

---

## 4. Boundaries I did not cross

Per the split, I did not modify:

- `lib/data/panorama_data.dart`
- `lib/services/panorama_server.dart`
- `lib/models/viewer_url_policy.dart`, `webview_bridge.dart`, `indoor_manifest.dart`
- `lib/widgets/panorama_*.dart`
- `assets/web/**` (viewer HTML, Pannellum vendor bundle)

**Shared files changed, and exactly how:**

| File | Change | Behaviour altered? |
|---|---|---|
| `lib/screens/map_screen.dart` | Added a "Look inside in 360°" button to the venue sheet, guarded by `venuesWithPanoramaProvider`; calls `Routes.panoramaFor(venue.id)` | No panorama internals touched. Your Map/360 toggle and `PanoramaBuildingPicker` wiring are untouched |
| `lib/screens/panorama_screen.dart` | Colour tokens only (`AonColors.*` → `context.aon.*`) | **No** |
| `lib/widgets/panorama_web_view.dart` | Colour tokens only | **No** |
| `lib/widgets/panorama_tour_view.dart` | Colour tokens only | **No** |
| `lib/widgets/panorama_scene_rail.dart` | Colour tokens only | **No** |
| `lib/widgets/panorama_building_picker.dart` | Colour tokens only | **No** |
| `lib/screens/passport_reward_screen.dart` | Colour tokens only | **No** |
| `lib/widgets/passport_grid.dart` | Colour tokens only | **No** |
| `lib/widgets/passport_home_card.dart` | Colour tokens only | **No** |

Untouched entirely: `panorama_data.dart`, `panorama_server.dart`,
`viewer_url_policy.dart`, `webview_bridge.dart`, `indoor_manifest.dart`,
`assets/web/**`, and all passport data/logic.

Your panorama and passport tests all still pass (430 total, green).

### Also worth knowing

* `AonColors` has been **deleted**. Every colour now comes from `AonPalette`
  via `context.aon.*`. If you have work in flight that references it, the
  rename table above is the whole migration.
* Your passport UI is not localised yet — `passport_home_card.dart` renders
  "0 / 9 stamps" in English even in Persian. Add ARB keys when convenient;
  `lib/l10n/app_en.arb` + `app_fa.arb` are the files.

---

## 5. Open questions for the organisers (Kelly / Liz / Charanya)

Tracked in full in `docs/data-sources.md`. The ones that block frontend work:

1. First aid location — currently rendered with no map pin.
2. Which of the two mapped "West 6" labels is the event car park.
3. Shuttle bus stops and timetable — legend-only today.
4. Finish times for the seven activities that publish only a start time.
5. Sign-off on the draft walking directions, ideally after a dusk walk-through.
