import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/widgets/confidence_note.dart';

/// `ConfidenceNote` is the visible half of [DataConfidence]: the promise that a
/// placeholder is never presented as fact. Both of its shapes are live —
/// `event_detail_screen.dart` renders the compact one, the venue and parking
/// sheets render the boxed one — so both are covered here directly rather than
/// incidentally through whichever screen happens to embed one this month. The
/// compact path lost its incidental coverage when the info-screen coordinate
/// callouts were removed (cf1fd18); it is still shipped, so it is still tested.
Widget _host({
  required DataConfidence confidence,
  String? message,
  bool compact = false,
}) => MaterialApp(
  theme: AonTheme.build(),
  localizationsDelegates: AonL10n.localizationsDelegates,
  supportedLocales: AonL10n.supportedLocales,
  home: Scaffold(
    body: ConfidenceNote(
      confidence: confidence,
      message: message,
      compact: compact,
    ),
  ),
);

void main() {
  final fallback = AonL10nEn().infoDetailToBeConfirmed;

  testWidgets('renders nothing for confirmed or derived data', (t) async {
    for (final c in [DataConfidence.confirmed, DataConfidence.derived]) {
      await t.pumpWidget(_host(confidence: c));
      expect(find.byType(Text), findsNothing, reason: '$c must render nothing');
      expect(find.byType(Icon), findsNothing, reason: '$c must render nothing');
    }
  });

  testWidgets('compact form is an unboxed row with the small icon', (t) async {
    await t.pumpWidget(
      _host(confidence: DataConfidence.placeholder, compact: true),
    );

    expect(find.text(fallback), findsOneWidget);
    expect(find.byType(Container), findsNothing);
    final icon = t.widget<Icon>(find.byIcon(Icons.info_outline_rounded));
    expect(icon.size, AonSpacing.iconSm);
  });

  testWidgets('boxed form wraps the note and uses the larger icon', (t) async {
    await t.pumpWidget(_host(confidence: DataConfidence.placeholder));

    expect(find.text(fallback), findsOneWidget);
    expect(find.byType(Container), findsOneWidget);
    final icon = t.widget<Icon>(find.byIcon(Icons.info_outline_rounded));
    expect(icon.size, AonSpacing.iconMd);
  });

  testWidgets('a caller-supplied message replaces the default wording', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        confidence: DataConfidence.placeholder,
        message: 'Start time to be confirmed',
        compact: true,
      ),
    );

    expect(find.text('Start time to be confirmed'), findsOneWidget);
    expect(find.text(fallback), findsNothing);
  });
}
