# Theme and localisation

## Theme architecture

### The problem with the old approach

Colours used to live in `AonColors` as `static const Color` tokens. That is
perfect for one theme and structurally incapable of supporting two: a
`static const` cannot know whether the app is currently light or dark.

### `AonPalette` — a `ThemeExtension`

`lib/app/theme/aon_palette.dart` defines every semantic colour, with a `dark`
and a `light` instance. It is attached to `ThemeData.extensions`, and widgets
read it as:

```dart
Text('…', style: TextStyle(color: context.aon.contentSecondary));
```

`ThemeExtension` rather than a bespoke `InheritedWidget` because it rides on
`ThemeData`: it participates in `MaterialApp`'s theme cross-fade, survives
nested `Theme.of` overrides, and switches with `themeMode` — no restart, no
manual plumbing.

### Role-based token names

The old names described a *look*; the new ones describe a *role*, because
"night900" is actively misleading when it resolves to near-white.

| Old | New | Role |
|---|---|---|
| `night950` | `surfaceBase` | Scaffold background |
| `night900` | `surface` | Cards, sheets, dialogs |
| `night800` | `surfaceRaised` | Selected chips, skeletons |
| `night700` | `border` | Hairlines, dividers |
| `night600` | `borderStrong` | Disabled chrome |
| `amber` | `accent` | Primary action |
| `amberBright` | `accentBright` | Pressed / high emphasis |
| `stellar` | `info` | Secondary / informational |
| `nebula` | `tertiary` | Sparing highlight |

### The light theme is designed, not inverted

Inverting the dark palette produces muddy colours and an accent that fails
contrast: dark's `#FFB945` is about **1.9:1 on white**. Light therefore has its
own accent family — deep amber `#9A5B00` at 5.5:1, with **white** text on
accent fills (dark uses near-black on a bright amber).

Every foreground token is verified against its intended background by
`test/widget/theme_light_dark_test.dart`, which computes real WCAG contrast
ratios. Body text must clear 4.5:1; map markers, being large graphics, must
clear 3:1. That test is the guard against a half-migrated palette.

### Surfaces that stay dark in both themes

The Home hero renders over a photograph of deep space — a permanently dark
backdrop. Its subtree is wrapped in a forced dark `Theme`, so the title stays
white and the year stays bright amber in light mode. The scrim deliberately
sits *outside* that wrapper so its final stop still blends into the page
background.

The same reasoning applies to the map: `DarkTileLayer` inverts OpenStreetMap's
light raster tiles **only in dark mode**. Inverting in light mode would give a
dark basemap under light chrome.

### Appearance setting

System / Light / Dark, persisted in `shared_preferences`. Dark is the default
because the event runs after sunset, and it is marked "Recommended" — but it is
not forced.

---

## Localisation

### Scope: English and Persian, honestly

`l10n.yaml` generates `AonL10n` from `lib/l10n/app_en.arb` (template) and
`app_fa.arb`.

**MQ Journey's 35 locales were deliberately not inherited.** Its translations
are Open Day wording; the Astronomy strings ("My Night", "Later tonight", the
event phase copy, the wayfinding warnings) are new. Machine-filling 35 locales
to reach "zero untranslated keys" would ship confidently wrong translations to
a public event, which is worse than shipping two good ones.

`.dart_tool/untranslated_messages.json` is `{}` — Persian is genuinely
complete, and `localisation_rtl_test.dart` proves it by diffing the two ARB
files and failing if any Persian value is still its English source.

> **Persian needs a native review before the event.** The translations are
> careful but unreviewed. The event name in particular — rendered
> «شب باز نجوم» — should be confirmed with the organisers, since an official
> event name may have an approved rendering or may be left in English.

### Adding a locale

1. Add `lib/l10n/app_<code>.arb` with every key from the English template.
2. `flutter gen-l10n`.
3. The supported-locales test will fail until you update its expected set —
   deliberately, so adding a locale is a conscious act.

### Right-to-left

Persian lays out RTL automatically. Three things needed explicit work:

**Date and time formatting.** `TimeFormat.locale` is set from the app's
resolved locale in `MaterialApp.localeResolutionCallback`, so `intl` renders
Persian month names and Persian-Indic digits rather than English dates inside
an RTL screen.

**Bidi isolation.** The programme is full of English proper nouns —
"Macquarie Theatre", "17 Wally's Walk" — embedded in Persian sentences. Without
isolation the Unicode bidi algorithm resolves them against their neighbours and
punctuation drifts ("Room 108, 1 Central Courtyard" → "1 Central Courtyard
,108 Room"). `lib/utils/bidi.dart` wraps each run in FSI/PDI isolates. It is a
no-op in LTR, so call sites need not know the direction.

**Enum labels.** `EventTiming` and `EventPhase` keep an English `label` for
test/diagnostic output; user-facing text comes from
`lib/utils/timing_labels.dart`, which resolves each enum through `AonL10n`.

### The guard against regressions

`localisation_rtl_test.dart` fails if any of a list of user-facing Astronomy
strings appears as a literal in `lib/screens` or `lib/widgets`. Add an ARB key
instead.

---

## Known gaps

| Gap | Note |
|---|---|
| Persian not natively reviewed | Translations are careful but unverified. Event-name rendering needs organiser sign-off |
| Passport UI not localised | `passport_home_card.dart` / `passport_grid.dart` / `passport_reward_screen.dart` are Raouf's and still render English ("0 / 9 stamps"). Flagged in `docs/backend-integration.md` |
| Plural digits | `myNightSavedCount` renders "2" rather than "۲" in Persian. Cosmetic; the dates and times do use Persian digits |
| Locale picker | `AppSettings.localeCode` and `localeProvider` exist and work, but Settings has no language selector yet — the app follows the device. Add one when a third locale lands |
