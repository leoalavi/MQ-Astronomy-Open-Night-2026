import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';

void main() {
  testWidgets(
    'server-start failure -> unavailable state (real path), not a crash',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: Scaffold(
            body: PanoramaWebView(
              manifest: IndoorManifest.fromJson(
                '{"nodes":[{"id":"a","image":"indoor/a.jpg","neighbours":[]}]}',
              ),
              ensureServer: () async => throw StateError('no platform'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('unavailable'), findsOneWidget);
    },
  );
}
