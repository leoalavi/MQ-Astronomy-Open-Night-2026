{{flutter_js}}
{{flutter_build_config}}

// Two different mechanisms need a Persian face, and only one of them is the
// theme. AonTypography sets Vazirmatn as the fontFamilyFallback, which covers
// text drawn with the app's own styles. CanvasKit ALSO has its own automatic
// fallback for glyphs it cannot resolve, and that one downloads Noto from
// fonts.gstatic.com regardless of the theme — a third-party request on every
// Persian page load, which the deployed connect-src 'self' then blocks, leaving
// the glyphs unrendered. Pointing fontFallbackBaseUrl at the bundled copy keeps
// that request on this origin. tests/aon/app.spec.ts asserts no third-party
// request is made with the app in Persian.
_flutter.loader.load({
  config: { fontFallbackBaseUrl: 'fonts/' }
});
