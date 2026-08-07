import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait. The app is used one-handed while walking; a rotation
  // mid-stride is never intentional here.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: AonApp()));
}

class AonApp extends StatefulWidget {
  const AonApp({super.key});

  @override
  State<AonApp> createState() => _AonAppState();
}

class _AonAppState extends State<AonApp> {
  // Built once and held, rather than rebuilt in build(). A GoRouter carries
  // navigation state; recreating it on every rebuild would reset the user to
  // the home screen at random.
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: EventInfo.fullName,
      debugShowCheckedModeBanner: false,
      theme: AonTheme.build(),
      // Dark only, by design — see AonTheme.
      darkTheme: AonTheme.build(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      builder: (context, child) {
        // Clamp the OS text scale. Users on a large accessibility setting are
        // still respected up to 1.6x, but beyond that the programme cards
        // overflow badly; capping is kinder than clipping.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}
