import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'maps_nav_providers.dart';

/// The Google-required security headers identifying THIS app to an
/// app-restricted Routes key (design §0b.A). The restriction is the security
/// boundary (the key is extractable), so these headers are load-bearing.
class RoutesClientIdentity {
  final Map<String, String> headers;
  const RoutesClientIdentity(this.headers);
}

/// The app's package id / bundle id — identical on Android and iOS (verified in
/// build.gradle.kts `applicationId` and project.pbxproj `PRODUCT_BUNDLE_IDENTIFIER`).
const String _appId = 'au.edu.mq.astronomy.aon2026';

const MethodChannel _identityChannel =
    MethodChannel('au.edu.mq.astronomy.aon2026/routes_identity');

/// The Android signing-certificate SHA-1, read at runtime from the native
/// [MainActivity] channel so it always matches the shipped APK signature.
/// Returns '' off Android or if the channel is unavailable. Overridable in tests.
final androidCertSha1Provider = FutureProvider<String>((ref) async {
  try {
    final sha1 = await _identityChannel.invokeMethod<String>('getSigningCertSha1');
    return sha1 ?? '';
  } on PlatformException {
    return '';
  } on MissingPluginException {
    return '';
  }
});

/// Google rejects a colon-separated SHA-1 in `X-Android-Cert` even though
/// keytool and the Cloud console display it that way. Verified live on
/// 2026-09-07 against an Android-restricted key: `A4:26:...` -> 403, `A426...`
/// -> 200. Normalising here means the header is correct regardless of what the
/// native seam emits.
String normaliseAndroidCert(String cert) =>
    cert.replaceAll(':', '').trim().toUpperCase();

/// Assembles the per-platform identity headers: iOS sends the one bundle-id
/// header; Android sends BOTH package + cert.
///
/// WEB sends NONE, deliberately. A browser key is restricted by HTTP referrer,
/// which the browser attaches itself and which cannot be forged from JS; sending
/// an `X-Ios-Bundle-Identifier`/`X-Android-Package` header from a web page would
/// be both meaningless and rejected by a referrer-restricted key. Desktop sends
/// none because nav is disabled there.
final routesClientIdentityProvider = FutureProvider<RoutesClientIdentity>((ref) async {
  switch (ref.watch(mapsNavPlatformProvider)) {
    case MapsNavPlatform.ios:
      return const RoutesClientIdentity({'X-Ios-Bundle-Identifier': _appId});
    case MapsNavPlatform.android:
      final cert = await ref.watch(androidCertSha1Provider.future);
      return RoutesClientIdentity({
        'X-Android-Package': _appId,
        'X-Android-Cert': normaliseAndroidCert(cert),
      });
    case MapsNavPlatform.web:
    case MapsNavPlatform.unsupported:
      return const RoutesClientIdentity({});
  }
});
