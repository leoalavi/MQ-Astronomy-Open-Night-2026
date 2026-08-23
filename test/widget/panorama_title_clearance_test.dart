import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_tour_view.dart';

/// `PanoramaScreen` stacks a floating back button over `PanoramaTourView`, and
/// both were positioned at the same `top` and `left`. On a device the button
/// therefore sat on top of the first character of the title: "Macquarie
/// Theatre" rendered as "◄acquarie Theatre".
///
/// Caught by actually opening tour A on a simulator — no unit test could see it,
/// because the overlap only exists once the two Positioned children are
/// composited together at real device metrics.
const _two =
    '{"nodes":[{"id":"a","image":"indoor/a.jpg","description":"Scene A",'
    '"neighbours":[]},{"id":"b","image":"indoor/b.jpg","description":"Scene B",'
    '"neighbours":[]}]}';

Widget _fakeViewer({
  required IndoorManifest manifest,
  required String? sceneId,
  required ValueChanged<String> onSceneChanged,
}) =>
    const SizedBox.expand();

Future<void> _pump(WidgetTester t, {required double inset}) => t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(
          body: PanoramaTourView(
            manifest: IndoorManifest.fromJson(_two),
            title: 'Macquarie Theatre',
            titleLeadingInset: inset,
            viewerBuilder: _fakeViewer,
          ),
        ),
      ),
    );

void main() {
  testWidgets('the title clears a back button of one tap target', (t) async {
    await _pump(t, inset: AonSpacing.minTapTarget);

    final title = _rectOf(t, find.text('Macquarie Theatre'));

    // The back button is drawn from the screen's left padding edge and is at
    // least one minimum tap target wide. The first glyph of the title must
    // start beyond it, or the button covers the title.
    const backButtonRight = AonSpacing.space4 + AonSpacing.minTapTarget;
    expect(
      title.left,
      greaterThanOrEqualTo(backButtonRight),
      reason: 'title starts at ${title.left}, but the back button occupies up '
          'to $backButtonRight — this is the "◄acquarie Theatre" overlap',
    );
  });

  testWidgets('without an inset the title keeps its original position',
      (t) async {
    await _pump(t, inset: 0);

    final title = _rectOf(t, find.text('Macquarie Theatre'));
    // Island left padding only — the widget stays reusable without a back
    // button, so the inset must be opt-in rather than baked in.
    expect(title.left, closeTo(AonSpacing.space4 * 2, 0.5));
  });

  testWidgets('a long venue name still fits and stays on screen', (t) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(
          body: PanoramaTourView(
            manifest: IndoorManifest.fromJson(_two),
            // The longest real one in the A–I legend.
            title: '14 Sir Christopher Ondaatje Avenue',
            titleLeadingInset: AonSpacing.minTapTarget,
            viewerBuilder: _fakeViewer,
          ),
        ),
      ),
    );

    final title = _rectOf(t, find.text('14 Sir Christopher Ondaatje Avenue'));
    final screen = t.view.physicalSize.width / t.view.devicePixelRatio;

    expect(title.left, greaterThanOrEqualTo(
        AonSpacing.space4 + AonSpacing.minTapTarget));
    expect(title.right, lessThanOrEqualTo(screen),
        reason: 'the title island must not run off the right edge');
  });
}

Rect _rectOf(WidgetTester t, Finder f) {
  expect(f, findsOneWidget);
  return t.getRect(f);
}
