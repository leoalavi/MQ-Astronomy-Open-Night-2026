/// Whether the Campus Map's transient exploration state should be cleared
/// because the user has just left the Map tab.
///
/// ## Why this is needed at all
///
/// Ported from MQ Journey (Open Day), `map_branch_lifecycle.dart`. The reason is
/// identical in both apps and worth stating plainly: the Map tab lives inside a
/// `StatefulShellRoute.indexedStack`, so switching tabs does NOT dispose the Map
/// branch — it only goes offstage and `dispose()` never runs. **Nothing clears
/// itself.** That is why a venue opened via "Show on map" was still selected,
/// with its sheet still open, minutes later on a different errand.
///
/// Clearing on the way OUT (rather than on the way back in) means the map is
/// already clean before it is next shown, so there is no flash of stale state.
///
/// [isPushedEntry] is the exception that matters, and it is the same exception
/// Open Day makes: when the map was PUSHED on top of a source page, its
/// selection is the entire point of the detour and the user is expected to press
/// Back and land where they came from. Wiping it on a tab switch would strand
/// them. A normal tab entry or a deep link selects once on arrival, so a later
/// reset is correct for those.
bool shouldResetMapExplorationOnBranchChange({
  required bool? wasVisible,
  required bool isVisible,
  required bool isPushedEntry,
}) {
  // No known prior state (first emission) — we cannot tell the user is leaving,
  // so there is nothing to reset.
  if (wasVisible == null) return false;
  if (isPushedEntry) return false;
  return wasVisible && !isVisible;
}
