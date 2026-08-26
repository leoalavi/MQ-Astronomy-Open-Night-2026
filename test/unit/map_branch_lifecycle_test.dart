import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/services/map_branch_lifecycle.dart';
import 'package:aon2026/services/search_providers.dart';

/// Map-tab lifecycle, ported from MQ Journey (Open Day).
///
/// ## The bug this file exists to prevent
///
/// The Map tab lives in a `StatefulShellRoute.indexedStack`. Switching tabs does
/// not dispose it — it goes offstage and `dispose()` never runs — so a venue
/// opened via "Show on map" stayed selected, with its sheet open, minutes later
/// on a different errand. Open Day hit exactly this and solved it with a pure
/// branch-change predicate plus a selection TOKEN; this is the same contract.
void main() {
  group('when to clear transient map state', () {
    test('leaving the Map tab clears', () {
      expect(
        shouldResetMapExplorationOnBranchChange(
            wasVisible: true, isVisible: false, isPushedEntry: false),
        isTrue,
      );
    });

    test('arriving at the Map tab does NOT clear', () {
      // Clearing on the way in would wipe a selection a "Show on map" just set.
      expect(
        shouldResetMapExplorationOnBranchChange(
            wasVisible: false, isVisible: true, isPushedEntry: false),
        isFalse,
      );
    });

    test('staying on the tab does not clear', () {
      expect(
        shouldResetMapExplorationOnBranchChange(
            wasVisible: true, isVisible: true, isPushedEntry: false),
        isFalse,
      );
    });

    test('the first emission cannot be a departure', () {
      // No prior state — we cannot know the user is leaving.
      expect(
        shouldResetMapExplorationOnBranchChange(
            wasVisible: null, isVisible: false, isPushedEntry: false),
        isFalse,
      );
    });

    test('a PUSHED map keeps its selection (Open Day exemption)', () {
      // The selection is the whole point of the detour; wiping it on a tab
      // switch would strand the user when they press Back.
      expect(
        shouldResetMapExplorationOnBranchChange(
            wasVisible: true, isVisible: false, isPushedEntry: true),
        isFalse,
      );
    });
  });

  group('the selection token makes repeats distinguishable', () {
    ProviderContainer c() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('selecting the SAME place twice still bumps the token', () {
      // Without this, re-tapping "Show on map" for a venue whose sheet you
      // dismissed is a no-op and the sheet never comes back.
      final container = c();
      final n = container.read(mapSelectionProvider.notifier);
      n.select('venue:observatory');
      final first = container.read(mapSelectionProvider);
      n.select('venue:observatory');
      final second = container.read(mapSelectionProvider);

      expect(second.placeKey, first.placeKey);
      expect(second.token, greaterThan(first.token),
          reason: 'a repeat request must be distinguishable from a no-op');
    });

    test('selecting a different place replaces, never accumulates', () {
      final container = c();
      final n = container.read(mapSelectionProvider.notifier);
      n.select('venue:a');
      n.select('venue:b');
      expect(container.read(mapSelectionProvider).placeKey, 'venue:b',
          reason: 'B must REPLACE A — stacked selections are the reported bug');
    });

    test('clear empties the selection but keeps the token moving', () {
      final container = c();
      final n = container.read(mapSelectionProvider.notifier);
      n.select('venue:a');
      final before = container.read(mapSelectionProvider).token;
      n.clear();
      final after = container.read(mapSelectionProvider);
      expect(after.placeKey, isNull);
      expect(after.isEmpty, isTrue);
      expect(after.token, greaterThan(before));
    });

    test('the derived key provider never drifts from the canonical state', () {
      // One source of truth: selectedPlaceKeyProvider is derived, not a copy.
      final container = c();
      container.read(mapSelectionProvider.notifier).select('venue:x');
      expect(container.read(selectedPlaceKeyProvider), 'venue:x');
      container.read(mapSelectionProvider.notifier).clear();
      expect(container.read(selectedPlaceKeyProvider), isNull);
    });
  });
}
