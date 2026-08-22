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

*Last audited: 2026-08-22, against `pubspec.yaml` at `ee54342`.*
