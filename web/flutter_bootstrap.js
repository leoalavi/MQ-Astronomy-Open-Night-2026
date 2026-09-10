{{flutter_js}}
{{flutter_build_config}}

// CanvasKit widget defaults can request font fallbacks outside the app theme.
// Keep those requests on this origin, including the bundled Persian subset.
_flutter.loader.load({
  config: { fontFallbackBaseUrl: 'fonts/' }
});
