# Coverage policy

`scripts/check.sh` runs the Dart suite with `--coverage` and enforces
`policy.json` against the resulting `coverage/lcov.info`.

## Why line coverage and not function coverage

`flutter test --coverage` writes **only `DA:` (line) records**. It emits no
`FN:`/`FNDA:` records at all:

```console
$ grep -c '^FN:' coverage/lcov.info
0
```

So "100% of functions" is not a figure this toolchain can produce, let alone
gate on. Line coverage is what exists, and it is what the policy enforces.

## Why not 100% lines either

Seven files cannot execute in the Flutter test VM — a platform channel, a
camera, a WebView, a native map view, a GPU shader, an app hand-off, and the
`runApp` bootstrap. They are named individually in `platform_exempt` with the
reason, rather than hidden behind a lower global number. Covering them needs a
real device, which is the standing on-device IOU.

Generated l10n (`lib/l10n/generated/`) is excluded from both numerator and
denominator. Covering it means calling every string getter in turn: the
percentage moves and nothing is tested.

## The three rules

1. **Whole-repo floor** — hand-written `lib/` coverage may not fall below
   `minimum_total_pct`.
2. **Per-file minimum** — every hand-written file reaches
   `per_file_minimum_pct` (80%), unless it is in `platform_exempt` or carries
   its own lower floor in `debt`.
3. **Neither list may rot** — a `debt` entry that has been paid off, or an
   exemption naming a file that no longer exists, fails the gate.

Rule 3 is the one that keeps this honest. Without it, `debt` becomes a
permanent amnesty; with it, paying a file off forces you to delete its entry
and subject it to the 80% minimum from then on.

**Every threshold ratchets upward only.** Raise a floor when coverage
improves. Lowering one to make the gate pass defeats the gate — if a change
genuinely cannot keep a file above its floor, say so in the commit rather than
editing the number quietly.

## Working with it

```bash
flutter test --coverage                      # produce coverage/lcov.info
python3 tools/coverage/check_coverage.py     # enforce the policy
./scripts/check.sh                           # both, inside the full gate
```

The gate prints the live figure on success, so the number is visible on every
run rather than only when something breaks.

## Paying down debt

`debt` currently holds eight files. They are ordinary Flutter code with no
platform obstacle — screens, sheets and the tab bar — so each one is
reachable with widget tests. The largest by uncovered lines is
`lib/screens/wayfinding_screen.dart`.
