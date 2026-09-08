# Pouya's 2026-09-08 bug batch — triage

Source: WhatsApp, 8 Sep 2026 11:31–11:37. Nine screenshots (sent twice: once
compressed, once full-res) plus five Persian voice notes. Voice notes
transcribed locally with `openai-whisper` (`medium`, `--language fa`);
transcripts in the session scratchpad, quoted below where the wording matters.

The build he tested **predates `91d5f14`** (branding removal, 2026-09-07 10:30):
his Home hero still reads `MACQUARIE UNIVERSITY`. Anything already fixed by that
commit is marked *already fixed* and needs no new work.

---

## Confirmed in code, fixed in this change

| # | Defect | Evidence | Fix |
|---|---|---|---|
| 1 | **Program search: the keyboard never closes.** Tapping anywhere else leaves it up. | "وقتی که تو پروگرام سرچ می‌کنی، کیبورد میاد بالا، هرچی رو صفحه می‌زنی کیبورد نمیره" | Flutter's default `onTapOutside` deliberately does **not** unfocus for *touch* pointers on iOS/Android (`editable_text.dart`, `EditableTextTapOutsideAction`). The field must opt in. |
| 2 | **Locale goes half-Persian.** English UI with Persian times and digits: "Previewing ۴ب.ظ. on event night", "Happening now ۲", "Up next ۱۴". | Screenshot 14:25 | `TimeFormat.locale` was assigned as a side effect of `localeResolutionCallback`. That callback only runs when `MaterialApp.locale` is **non-null**; on "Match my device" `LocalizationsResolver.locale` returns a **cached** `_resolvedLocale` and never re-resolves. So FA → "Match my device" left `TimeFormat.locale` stuck on `fa`. |
| 3 | **"Happening now" rendered twice on Home.** | "دوبار Happening Now تکرار شده، اولی اون بالایه اضافه هست" | `phaseHappeningNow` and `timingHappeningNow` are the same string; the hero pill sits directly above the rail header. |
| 4 | **Sheet CTAs sit under the floating tab bar** — Directions / Show on map unreachable. | "روی منو قرار می‌گیره... از UI ایراد داره"; screenshots 14:11 (West 6) and 14:12 (1 Central Courtyard) | A **layering** bug, not a padding one. These sheets were pushed on the *branch* navigator, which lives inside the shell's `Scaffold`, so the floating island painted over them **and stayed hit-testable through the modal barrier** — verified on the 6.9" simulator, where a tap aimed at "Show on map" switched tabs. Fixed with `useRootNavigator: true`, which four of the chooser sheets already used. |
| 5 | **The sheet's drag handle doesn't drag the sheet.** You must drag the content instead. | "باید این سفیده رو بکشی بالا اون بیاد بالا... این اتفاق نمی‌افته، باید داخل رو بکشی بالا" | `DraggableScrollableSheet` nested inside `showModalBottomSheet`: the theme's drag handle drives the *outer* modal's dismiss-drag, while the *inner* sheet's extent is driven only by its `ListView`. |
| 6 | **Haptics do nothing.** | "این هپتیکس باز کار نمی‌کنه... هرچی تست کردم کار نکرد" | Not a plumbing failure — `AonHaptics` is wired correctly. Only 5 widget types ever call it; the ~59 Material buttons, switches, radios and filter rows never did. The Settings copy promises "when you tap buttons". |

## Already fixed before he tested

- **`MACQUARIE UNIVERSITY` in the Home hero** — removed in `91d5f14`; `_Hero`
  now starts at `EventInfo.name`.

## Not a defect — deliberate, and guarded by tests

- **The amber notes on Solar system walk** ("These times are not published…",
  "The exact position… is still being confirmed"). These encode the
  `openAllNight` case: Liz confirmed the walk runs all night but published **no**
  start or finish, and its position is genuinely unconfirmed. Deleting them
  breaks invariant #2/#5 and `test/unit/liz_update_2026_08_31_test.dart`. They
  disappear on their own once the organisers confirm — that is an organiser
  question, not a code change. See `docs/mq-staff-questions.md`.

## Needs a person, not a commit

- **Privacy Policy "rewritten from scratch"** ("کلاً از نو نوشته بشه"). This is
  legal copy naming Leo Alavi as publisher, and the in-app dialog is only the
  fallback shown while `EventConfig.privacyPolicyUrl` is null (no hosting domain
  yet). Rewriting it is Raouf's and Leo's call. Flagged, not touched.


---

## Correction, same day

The first pass at #4 treated it as a missing `AonNavMetrics.clearance` on the
sheets' bottom padding, and shipped in `3a34574`. Running the build on the 6.9"
simulator showed that was wrong: padding only decides where the *last* item
comes to rest, and the sheet still sat underneath a fully interactive tab bar.
Tapping where "Show on map" appeared switched tabs and dismissed the sheet.

The actual cause is which navigator the sheet is pushed on, and the repository
already had the right answer in four other sheets. Recorded here because the
first diagnosis looked convincing and passed a green gate — the thing that
caught it was opening the app and tapping the button.


---

## Open question — the first half of voice note 5 (`00000311`)

Note 5 covers two things. The second is unambiguous and is fixed above (#2):

> "وقتی که از انگلیسی به فارسی تغییر می‌دی و بعد از فارسی به انگلیسی دوباره،
>  اون ساعت‌ها همچنان فارسی می‌مونن" — switch EN→FA then FA→EN and the times
>  stay Persian.

The **first** half is not reliably decodable. Two independent passes
(`medium` default, and `medium` with beam search and a domain prompt) agree only
on the opening:

> "و خالیش هم مشکل تو حالت پرویو هست، وقتی که مثلا می‌زنی پرویو برای یه ساعتی،
>  میاد اون قسمت بالا … و اشکال می‌کنه … که اون پایین هست، بشون مشکل می‌شه."

Roughly: *"there is also a problem in preview mode — when you preview a
particular hour, that top section … glitches … the one at the bottom has a
problem."* The words between are lost, and the run with beam search truncated
the clip entirely rather than improving it. `large-v3` cannot be used to settle
it: it stalls on this machine (17 min, ~15% CPU, no output).

**Deliberately not guessed at.** The preview banner and the bottom island are
both plausible referents and the screenshots in this batch show nothing wrong
with either. This repository has a documented incident where three defects were
fabricated by inferring from one function and then repeated by two gauntlets and
two external reviews. Ask Pouya what this one was rather than inventing it.
