# Physical-device QA — the pass that closes B4

Everything below has been exercised on the iOS Simulator and **cannot** be
closed there: the simulator has no magnetometer, no real GPS, no camera and no
haptics engine. This is the list to work through on a real iPhone, ideally on
campus, before the final submission.

**Fill in as you go.** A row is only done when the "Observed" column is written.
An empty column is an open item, not a pass.

**Build to test:** the current Build 4 candidate (or the signed/TestFlight build produced from the same approved source),
installed via TestFlight — not a debug build. Note the device and iOS version at
the top of your notes.

---

## 1. Location

| # | Step | Expected | Observed |
|---|---|---|---|
| 1.1 | Fresh install, open the app, go to the **Map** tab | iOS asks for location once, "While Using the App". No prompt at launch, none on any other tab | |
| 1.2 | Tap **Don't Allow** | Map still opens and is fully usable; no crash, no empty screen, no repeated prompt | |
| 1.3 | Tap the **Locate** control after denying | The app offers the path back (Settings), rather than silently failing | |
| 1.4 | Re-enable location in iOS Settings, return to the app | The blue position dot appears and settles near where you actually are | |
| 1.5 | Walk 50–100 m across campus | The dot follows, with no obvious lag or teleporting | |
| 1.6 | Check the accuracy behaviour standing still | The dot does not jitter wildly; accuracy circle is plausible | |

**Why this cannot be simulated:** the settling policy rejects implausible fixes,
and only a real GPS produces the accuracy values it is judging.

## 2. Walking directions (Google Routes)

The 401 is fixed — a live request returned HTTP 200 and a real route on
2026-09-05. What is unproven is the same path from a real device with a real GPS
origin.

| # | Step | Expected | Observed |
|---|---|---|---|
| 2.1 | Open a venue → **Walking directions** | A real Google walking route renders: distance, duration, step list | |
| 2.2 | Check the origin | The route starts from where you are, not from a default campus point | |
| 2.3 | Confirm no 401 | No "route unavailable" banner. If one appears, capture the value logged by `navTrace('route API failure HTTP …')` | |
| 2.4 | Confirm you stay in the app | Directions render **inside** AON. No hand-off to the external Google Maps app anywhere | |
| 2.5 | Settings → Privacy → turn directions sharing **off**, retry | The in-app "sharing off" panel appears with a one-tap re-enable; no request is made | |
| 2.6 | Car-park wayfinding path | The explicit "Use Google Maps for directions?" disclosure appears **before** anything loads | |

## 3. Astronomy Passport

| # | Step | Expected | Observed |
|---|---|---|---|
| 3.1 | Open the passport at zero stamps | The "how it works" hint is visible | |
| 3.2 | Tap **Scan or enter a code** | The camera permission prompt appears *here* — never at launch | |
| 3.3 | Grant the camera | The scanner starts on its own, no second tap needed | |
| 3.4 | Scan a real printed venue QR | One stamp is added, with the fact revealed. Scanning the same sign twice does not double-stamp | |
| 3.5 | Torch on / off | The torch actually toggles | |
| 3.6 | Deny the camera instead | "Camera unavailable — enter the code" with working manual entry, and a path to iOS Settings | |
| 3.7 | Read every string on the way through | No "Draft", no "TBC", no internal or placeholder copy | |

## 4. Haptics

| # | Step | Expected | Observed |
|---|---|---|---|
| 4.1 | Haptics ON — collect a stamp, toggle switches | Light, deliberate feedback | |
| 4.2 | Haptics OFF — repeat | No haptic from the app at all | |

## 5. Dynamic Type

| # | Step | Expected | Observed |
|---|---|---|---|
| 5.1 | iOS Settings → Display → Text Size, largest non-accessibility size | Every screen reflows; nothing clipped | |
| 5.2 | Accessibility text sizes, up to the largest | The app clamps at 2.0×; **no overflow**, and the last actionable row on each screen is still reachable and tappable | |
| 5.3 | Home, Program, Map, Passport, Settings, Info at that size | All six pass | |

## 6. 360° tours

| # | Step | Expected | Observed |
|---|---|---|---|
| 6.1 | Open the Observatory tour | Loads, pans smoothly, no black frame | |
| 6.2 | Open 1 Central Courtyard | Same, and the scene rail moves between all scenes | |
| 6.3 | Rotate the device mid-tour | No crash, no stuck viewport | |

## 7. Persian (RTL)

| # | Step | Expected | Observed |
|---|---|---|---|
| 7.1 | Settings → language → Persian | The whole UI mirrors; nothing stays left-aligned by accident | |
| 7.2 | Home, Program, Map, Passport in Persian | Layout holds; no clipped or overlapping text | |
| 7.3 | Numbers and times in Persian | Rendered correctly, not as raw English patterns | |

## 8. Night conditions — worth doing once on site

| # | Step | Expected | Observed |
|---|---|---|---|
| 8.1 | Open the app outdoors after dark | The dark theme is readable; the bright campus basemap is not blinding | |
| 8.2 | Battery over ~30 min of map + compass use | No unreasonable drain | |
| 8.3 | With mobile data off | Everything except walking directions still works | |
