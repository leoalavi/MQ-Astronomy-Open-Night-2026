#!/usr/bin/env python3
"""Enforce the coverage policy in tools/coverage/policy.json against lcov.info.

Line coverage only. Flutter's `flutter test --coverage` emits DA (line) records
and *no* FN/FNDA records, so there is no function-level figure available to
gate on — see the policy file's own note.

Three rules, all one-way ratchets:

  1. hand-written lib/ line coverage must not fall below `minimum_total_pct`
  2. every hand-written file must reach `per_file_minimum_pct`, unless it is
     in `platform_exempt` (cannot execute in the test VM) or carries a `debt`
     floor of its own
  3. a debt entry that has been paid off, or an exemption for a file that no
     longer exists, FAILS — so neither list can quietly rot

Exit 0 on pass, 1 on any violation.
"""

from __future__ import annotations

import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LCOV = os.path.join(REPO, "coverage", "lcov.info")
POLICY = os.path.join(REPO, "tools", "coverage", "policy.json")

# Machine-written string tables: covering them means calling every getter,
# which moves the number without testing behaviour.
GENERATED = "/l10n/generated/"


def parse_lcov(path: str) -> dict[str, tuple[int, int]]:
    """{source file: (lines hit, lines found)}"""
    out: dict[str, list[int]] = {}
    current = None
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("SF:"):
                current = line[3:]
                out.setdefault(current, [0, 0])
            elif line.startswith("DA:") and current is not None:
                _, hits = line[3:].rsplit(",", 1)
                out[current][1] += 1
                if int(hits) > 0:
                    out[current][0] += 1
    return {k: (v[0], v[1]) for k, v in out.items()}


def pct(hit: int, found: int) -> float:
    return 100.0 if found == 0 else 100.0 * hit / found


def main() -> int:
    if not os.path.exists(LCOV):
        print(f"no coverage data at {LCOV} — run `flutter test --coverage` first")
        return 1

    with open(POLICY, encoding="utf-8") as fh:
        policy = json.load(fh)

    files = {k: v for k, v in parse_lcov(LCOV).items() if GENERATED not in k}
    if not files:
        print("lcov.info contains no hand-written lib files — coverage run failed?")
        return 1

    failures: list[str] = []

    # 1. the whole-repo floor
    hit = sum(h for h, _ in files.values())
    found = sum(f for _, f in files.values())
    total = pct(hit, found)
    floor = float(policy["minimum_total_pct"])
    if total + 1e-9 < floor:
        failures.append(
            f"total {total:.2f}% is below the {floor:.1f}% floor "
            f"({hit}/{found} lines)"
        )

    # 2/3. per-file floors, and the two ways a list can rot
    per_file_min = float(policy["per_file_minimum_pct"])
    exempt = policy["platform_exempt"]
    debt = policy["debt"]

    for path, reason in sorted(exempt.items()):
        if not os.path.exists(os.path.join(REPO, path)):
            failures.append(
                f"platform_exempt names a file that no longer exists: {path} "
                f"({reason}) — drop the entry"
            )

    for path, (h, f) in sorted(files.items()):
        if path in exempt:
            continue
        p = pct(h, f)
        required = float(debt[path]) if path in debt else per_file_min
        if p + 1e-9 < required:
            where = "debt floor" if path in debt else "per-file minimum"
            failures.append(
                f"{path}: {p:.1f}% is below its {where} of {required:.1f}% "
                f"({h}/{f} lines)"
            )

    for path, required in sorted(debt.items()):
        if path not in files:
            failures.append(
                f"debt names a file with no coverage data: {path} — drop the entry"
            )
            continue
        h, f = files[path]
        if pct(h, f) + 1e-9 >= per_file_min:
            failures.append(
                f"{path} now reaches {pct(h, f):.1f}% — remove it from `debt` "
                f"so the {per_file_min:.0f}% minimum applies from here on"
            )

    print(
        f"hand-written lib coverage {total:.2f}% ({hit}/{found} lines, "
        f"{len(files)} files); floor {floor:.1f}%, per-file {per_file_min:.0f}%, "
        f"{len(debt)} on debt, {len(exempt)} platform-exempt"
    )
    if failures:
        print("\nCOVERAGE POLICY VIOLATIONS:")
        for f_ in failures:
            print(f"  - {f_}")
        print(
            "\nRaise the floors in tools/coverage/policy.json only when coverage "
            "IMPROVES. Never lower one to make this pass."
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
