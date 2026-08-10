import 'dart:convert';

/// Dart->JS command builders. jsonEncode (never string interpolation) keeps a
/// hostile scene id / config inside a single JS string literal — it can never
/// break out into executable code. (The JS runs via evaluateJavascript, not
/// inline in HTML, so `</script>` needs no special handling.)
String buildLoadTourJs(Map<String, dynamic> config) => 'loadTour(${jsonEncode(config)});';
String buildSelectSceneJs(String sceneId) => 'selectScene(${jsonEncode(sceneId)});';

/// JS->Dart trust boundary: an inbound `sceneChanged` payload is accepted only
/// if it is a String naming a KNOWN scene; anything else is rejected.
String? validatedInboundScene(Object? inbound, Set<String> knownScenes) {
  if (inbound is! String) return null;
  return knownScenes.contains(inbound) ? inbound : null;
}
