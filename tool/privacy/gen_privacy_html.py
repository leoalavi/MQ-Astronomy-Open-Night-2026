#!/usr/bin/env python3
"""Generate web/privacy.html from the app's own privacy strings.

SINGLE SOURCE OF TRUTH: the `webPrivacy*` keys in lib/l10n/app_en.arb are the
in-app Privacy Policy (rendered by lib/screens/privacy_screen.dart). This script
emits a static, semantic, JavaScript-free HTML rendering of exactly that content
for the canonical public URL (https://aon.syllabus-sync.app/privacy), so a store
reviewer or a JS-disabled client can read the policy without the Flutter runtime.

There is NO second, independently-maintained policy: edit the ARB, then re-run
this script. `test/unit/privacy_html_sync_test.dart` fails if web/privacy.html
drifts from the ARB source.

Run:  python3 tool/privacy/gen_privacy_html.py
"""
import html
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
ARB = ROOT / "lib/l10n/app_en.arb"
IDENT = ROOT / "lib/config/app_identity.dart"
OUTS = (
    ROOT / "web/privacy.html",
    # Historical release path, now an exact mirror rather than a second policy.
    ROOT / "docs/release/android-privacy-policy.html",
)


def dart_const(name: str) -> str:
    m = re.search(rf"static const String {name} =\s*'([^']*)'", IDENT.read_text("utf-8"))
    if not m:
        raise SystemExit(f"AppIdentity.{name} not found")
    return m.group(1)


def linkify(text: str) -> str:
    """Escape (element content — apostrophes/quotes stay literal), then turn
    emails and https URLs into anchors. Keeping quotes literal lets the drift
    test compare the rendered text against the ARB source verbatim."""
    out = html.escape(text, quote=False)
    out = re.sub(r"(https?://[^\s)]+)", r'<a href="\1">\1</a>', out)
    out = re.sub(r"(?<![\w.])([\w.+-]+@[\w.-]+\.\w+)", r'<a href="mailto:\1">\1</a>', out)
    return out


def main() -> None:
    arb = json.loads(ARB.read_text("utf-8"))
    developers = dart_const("developers")
    for_team = dart_const("forTeam")
    privacy_email = dart_const("privacyContactEmail")
    support_email = dart_const("eventSupportEmail")
    event_website = dart_const("eventWebsiteUrl")
    year = dart_const("copyrightYear")
    holder = dart_const("copyrightHolder")
    copyright_line = f"© {year} {holder}"
    canonical = dart_const("hostedOrigin") + "/privacy"
    last_updated = dart_const("privacyLastUpdated")

    def s(key: str) -> str:
        return (arb[key]
                .replace("{developer}", developers)
                .replace("{forTeam}", for_team)
                .replace("{privacyEmail}", privacy_email)
                .replace("{supportEmail}", support_email)
                .replace("{eventWebsite}", event_website)
                .replace("{privacyUrl}", canonical)
                .replace("{date}", last_updated))

    title = arb["webPrivacyPageTitle"]
    sections = [
        ("webPrivacyStorageHeading", "webPrivacyStorageBody"),
        ("webPrivacyLocationHeading", "webPrivacyLocationBody"),
        ("webPrivacyCameraHeading", "webPrivacyCameraBody"),
        ("webPrivacyMlKitHeading", "webPrivacyMlKitBody"),
        ("webPrivacyMapsHeading", "webPrivacyMapsBody"),
        ("webPrivacyAnalyticsHeading", "webPrivacyAnalyticsBody"),
        ("webPrivacyRetentionHeading", "webPrivacyRetentionBody"),
        ("webPrivacyContactHeading", "webPrivacyContactBody"),
    ]
    body = [
        f"    <h1>{html.escape(title)}</h1>",
        f'    <p class="updated">{linkify(s("webPrivacyLastUpdated"))}</p>',
        f"    <p>{linkify(s('webPrivacyIntro'))}</p>",
        f"    <p>{linkify(s('webPrivacyScope'))}</p>",
    ]
    for hk, bk in sections:
        body.append(f"    <section>\n      <h2>{html.escape(arb[hk])}</h2>"
                    f"\n      <p>{linkify(s(bk))}</p>\n    </section>")
    body.append('    <hr>')
    body.append(f'    <p class="credit">{linkify(s("webPrivacyCredit"))}</p>')
    body.append(f'    <p class="credit">{html.escape(copyright_line)}</p>')
    body_html = "\n".join(body)

    doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#05070F">
  <meta name="description" content="{html.escape(title)}">
  <link rel="canonical" href="{html.escape(canonical)}">
  <title>{html.escape(title)}</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{ margin: 0; background: #05070F; color: #E6E9F2;
      font: 16px/1.6 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }}
    main {{ max-width: 720px; margin: 0 auto; padding: 2rem 1.25rem 4rem; }}
    h1 {{ font-size: 1.7rem; line-height: 1.25; }}
    h2 {{ font-size: 1.15rem; margin-top: 2rem; }}
    p {{ margin: 0.75rem 0; }}
    .updated, .credit {{ color: #B9C0D4; font-size: 0.9rem; }}
    a {{ color: #FFB945; }}
    hr {{ border: none; border-top: 1px solid #2A3350; margin: 2rem 0 1rem; }}
    @media (prefers-color-scheme: light) {{
      body {{ background: #F6F8FC; color: #131722; }}
      .updated, .credit {{ color: #414A5E; }}
      a {{ color: #9A5B00; }} hr {{ border-top-color: #D7DEEC; }}
    }}
  </style>
</head>
<body>
  <main>
{body_html}
  </main>
</body>
</html>
"""
    for out in OUTS:
        out.write_text(doc, "utf-8")
        print(f"wrote {out.relative_to(ROOT)} ({len(doc)} bytes)")


if __name__ == "__main__":
    main()
