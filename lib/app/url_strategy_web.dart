import 'package:flutter_web_plugins/url_strategy.dart';

/// Web: use real paths instead of the default hash fragment, so routes are
/// clean, shareable URLs. Requires the host to rewrite unknown paths to
/// index.html (see docs/web-deployment.md).
void configureUrlStrategy() => usePathUrlStrategy();
