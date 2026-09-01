import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external URL (e.g. the hosted Privacy Policy) in the platform
/// browser.
///
/// A seam, so the Settings privacy-policy link can be driven in tests without
/// launching a real browser, and so the one place that touches `url_launcher`
/// is overridable. Returns `false` when the URL cannot be opened, so the caller
/// tells the visitor honestly rather than crashing (spec: nothing may throw into
/// the UI from a link that fails to open).
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>(
  (_) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);
