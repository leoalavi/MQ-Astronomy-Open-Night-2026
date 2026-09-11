# Export compliance — `ITSAppUsesNonExemptEncryption`

**Conclusion: `false`.** Set in `ios/Runner/Info.plist`.

Apple's key covers the app **and its linked third-party libraries**, so "the app
only uses HTTPS" is not sufficient evidence on its own — that is a conclusion, not
the working. This file is the working.

**Exempt:** use of encryption provided by the operating system (Apple's TLS,
Keychain, CommonCrypto) for standard purposes such as HTTPS transport.
**Non-exempt** would be bundling or implementing proprietary cryptography, or
using encryption for purposes beyond standard transport/authentication.

| Dependency | Version | Encryption touched | OS-provided or bundled | Conclusion |
|---|---|---|---|---|
| `http` | 1.6.0 | HTTPS to `routes.googleapis.com` | Dart/Apple TLS stack | exempt |
| `google_maps_flutter` | 2.18.0 | HTTPS to Google Maps endpoints | Google Maps SDK over Apple TLS | exempt |
| `flutter_inappwebview` | 6.1.5 | WKWebView; local HTTP server on `localhost` only | Apple WebKit / no TLS on loopback | exempt |
| `geolocator` | 14.0.3 | none (CoreLocation) | n/a | exempt |
| `sensors_plus` | 7.1.0 | none (CoreMotion) | n/a | exempt |
| `mobile_scanner` | 7.4.0 | none (AVFoundation / Vision) | n/a | exempt |
| `shared_preferences` | 2.5.5 | none — `NSUserDefaults`, unencrypted by design | n/a | exempt |
| `flutter_map` | 8.3.1 | no network after Plan A Task 5 removed the OSM tile layer | n/a | exempt |
| `url_launcher` | 6.3.2 | hands URLs to the OS | n/a | exempt |
| `intl`, `latlong2`, `go_router`, `flutter_riverpod`, `confetti`, `crypto` (test-only) | — | no transport crypto; `crypto` is a dev-dependency used to verify a bundled SHA-256 and is not shipped | n/a | exempt |

**No dependency bundles its own cryptographic implementation for transport.** All
network traffic is HTTPS over the platform TLS stack, which is exempt.

**Re-run this audit if `pubspec.yaml` gains a networked dependency**, and attach
the result to the submission. The declaration is per-version, not per-app.

## Re-audit — 11 September 2026 (Build 4)

`pubspec.yaml` gained three runtime entries since the table above was written.
None changes the conclusion:

| Added | Why it is still exempt |
|---|---|
| `web` ^1.0.0 | Browser JS interop bindings (`package:web`), used only by `maps_js_loader_web.dart` and `panorama_web_viewer_web.dart`. Web platform only, so it is not in the iOS binary at all. Bindings, not an implementation: no cryptography. |
| `pointer_interceptor` ^0.10.1 | Web-only widget over the panorama iframe. No network, no cryptography. |
| `flutter_web_plugins` | Flutter SDK package, web platform only. |

The iOS link set did not change: `ios/Podfile.lock` still resolves exactly
Flutter, `flutter_inappwebview_ios`, `google_maps_flutter_ios`, `GoogleMaps`
8.4.0, `Google-Maps-iOS-Utils` 5.0.0 and `OrderedSet`. Only spec checksums and
the deployment target (14.0 → 15.0) moved.

`crypto` remains a **dev-dependency** — it verifies a bundled SHA-256 in the test
suite and is not shipped. A digest is not encryption in any case, and
`keyFingerprint` in `lib/services/nav_trace.dart` uses non-cryptographic FNV-1a.
No `CryptoKit`, `CommonCrypto` or `SecKey` use anywhere in `ios/`.

**Conclusion unchanged: `ITSAppUsesNonExemptEncryption = false`.**

Because that key is present in `Info.plist`, App Store Connect does not ask the
export-compliance question on upload, and there is nothing to attach. If a build
without the key ever prompts: encryption used = **yes** (HTTPS), qualifies for an
exemption = **yes** (it only calls the encryption the operating system provides,
for standard transport), proprietary or non-standard algorithms = **no**. No
CCATS, ERN or annual self-classification report is required on that path.

*Last audited: 2026-09-11, against `pubspec.yaml` and `ios/Podfile.lock` at `f5be6dd`.*
*Previously audited: 2026-08-22, against `pubspec.yaml` at `ee54342`.*
