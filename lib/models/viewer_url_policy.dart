const int kPanoramaServerPort = 8459;

/// The single main-frame page the viewer ever loads.
const String _viewerPath = '/web/indoor_viewer.html';

/// Whether the WebView may perform a MAIN-FRAME navigation to [url].
/// Navigation policy only (NOT a subresource/network firewall — that is the
/// page CSP). Least privilege: `about:blank` exactly, or the exact viewer HTML
/// on the local origin (parsed scheme+host+port+path — never a prefix;
/// `127.0.0.1` is not `localhost`; userinfo cannot spoof the host).
bool isAllowedViewerUrl(Uri? url) {
  if (url == null) return false;
  final scheme = url.scheme.toLowerCase();
  if (scheme == 'about') return url.path == 'blank';
  return scheme == 'http' &&
      url.host == 'localhost' &&
      url.port == kPanoramaServerPort &&
      url.path == _viewerPath;
}
