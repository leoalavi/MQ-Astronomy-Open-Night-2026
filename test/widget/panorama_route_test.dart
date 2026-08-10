import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/screens/panorama_screen.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, String location) async {
    final router = buildRouter();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(theme: AonTheme.build(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('deep-link to an unknown venue -> unavailable, no crash, no asset read', (tester) async {
    await pumpAt(tester, '/panorama/does-not-exist');
    expect(tester.takeException(), isNull);
    expect(find.byType(PanoramaScreen), findsOneWidget);
    expect(find.textContaining('unavailable'), findsOneWidget);
  });

  testWidgets('deep-link to a real tour venue renders the panorama screen, no crash', (tester) async {
    await pumpAt(tester, '/panorama/macquarie-theatre');
    expect(tester.takeException(), isNull);
    expect(find.byType(PanoramaScreen), findsOneWidget);
  });
}
