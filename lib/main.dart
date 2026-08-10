import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/widgets/glass_shader.dart';
import 'package:aon2026/app/text_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait. The app is used one-handed while walking; a rotation
  // mid-stride is never intentional here.
  await SystemChrome.setPreferredOrientations([
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

  // Preload the glass refraction shader (Impeller only). Non-fatal by
  // construction: on unsupported targets or a load failure the surfaces fall
  // back to frost/solid — this must never block app startup.
  await GlassShaderCache.ensureLoaded();

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
        // Clamp the OS text scale to the app's verified range (see
        // lib/app/text_scale.dart). Every surface is hardened to 2.0; the cap
        // is held there deliberately so the app never exposes an unverified
        // scale. Lifting past 2.0 is future accessibility work.
        final scale = resolveAppTextScaler(MediaQuery.textScalerOf(context));
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}
