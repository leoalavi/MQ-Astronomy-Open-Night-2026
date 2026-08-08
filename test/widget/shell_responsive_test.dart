import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(414, 896)]) {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('shell no-overflow @ ${size.width.toInt()} x scale$scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(ProviderScope(
          child: MaterialApp.router(
            theme: AonTheme.build(),
            routerConfig: buildRouter(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidTabBar), findsOneWidget);
      });
    }
  }
}
