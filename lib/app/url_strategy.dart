/// Selects the web URL strategy, via a conditional import so mobile never links
/// `package:flutter_web_plugins`.
///
/// The app is served at clean paths (`/program`, `/map`, `/privacy`, …) rather
/// than hash routes (`/#/privacy`). That is what makes the privacy page a
/// shareable `…/astronomy-open-night/privacy` URL and keeps QR/link shares
/// tidy. The trade-off is that the **host must rewrite unknown paths to
/// `index.html`** so a deep link or refresh resolves — see
/// `docs/web-deployment.md`. On native this is a no-op.
library;

export 'url_strategy_noop.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
