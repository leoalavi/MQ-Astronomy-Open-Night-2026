import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A seam over launching an external URL, so widgets can be tested with a fake
/// instead of mocking `url_launcher`'s plugin globals.
abstract interface class ExternalMapsLauncher {
  Future<bool> open(Uri uri);
}

class UrlLauncherExternalMaps implements ExternalMapsLauncher {
  const UrlLauncherExternalMaps();
  @override
  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}

final externalMapsLauncherProvider =
    Provider<ExternalMapsLauncher>((ref) => const UrlLauncherExternalMaps());
