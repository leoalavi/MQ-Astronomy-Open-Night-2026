import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/app_settings.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/local_data_eraser.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/services/maps_consent_store.dart';

import 'package:aon2026/widgets/glass_shader.dart';
import 'package:aon2026/app/text_scale.dart';

/// Best-effort passport hydration. NEVER throws — a persistence failure must
/// not block launch (design §3.1). [store] is injectable for tests only;
/// production passes nothing.
Future<(Set<String>, PassportStore)> loadPassport({PassportStore? store}) async {
  final s = store ?? SharedPrefsPassportStore(SharedPreferencesAsync());
  Set<String> snapshot;
  try {
    snapshot = await s.loadSnapshot();
  } catch (_) {
    snapshot = <String>{};
  }
  return (snapshot, s);
}

/// Best-effort favorites hydration (passport-parallel). NEVER throws. Event id
/// comes from the same source `eventConfigProvider` uses, so the venue-scoped
/// key matches. [store] is injectable for tests only.
Future<(Set<String>, FavoritesStore)> loadFavorites({FavoritesStore? store}) async {
  final s = store ??
      SharedPrefsFavoritesStore(
        prefs: SharedPreferencesAsync(),
        eventId: EventConfig.astronomyOpenNight.id,
      );
  Set<String> snapshot;
  try {
    snapshot = await s.loadSnapshot();
  } catch (_) {
    snapshot = <String>{};
  }
  return (snapshot, s);
}

/// Best-effort Google-nav consent hydration (passport-parallel). NEVER throws;
/// a load failure defaults to `unknown` (re-ask). [store] is injectable for tests.
Future<(MapsConsent, MapsConsentStore)> loadMapsConsent({MapsConsentStore? store}) async {
  final s = store ?? SharedPrefsMapsConsentStore(prefs: SharedPreferencesAsync());
  MapsConsent snapshot;
  try {
    snapshot = await s.loadSnapshot();
  } catch (_) {
    snapshot = MapsConsent.unknown;
  }
  return (snapshot, s);
}

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

  final (passportSnapshot, passportStore) = await loadPassport();
  final (favoritesSnapshot, favoritesStore) = await loadFavorites();
  final (mapsConsentSnapshot, mapsConsentStore) = await loadMapsConsent();

  runApp(
    ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(passportSnapshot),
        passportStoreProvider.overrideWithValue(passportStore),
        favoritesSnapshotProvider.overrideWithValue(favoritesSnapshot),
        favoritesStoreProvider.overrideWithValue(favoritesStore),
        mapsConsentSnapshotProvider.overrideWithValue(mapsConsentSnapshot),
        mapsConsentStoreProvider.overrideWithValue(mapsConsentStore),
        // Spec §2b: the SDK is keyed on demand, never at launch. The provider
        // short-circuits on consent before this is ever reached.
        mapsSdkInitializerProvider.overrideWithValue(PlatformMapsSdkInitializer()),
        localDataEraserProvider.overrideWithValue(SharedPrefsLocalDataEraser(
          prefs: SharedPreferencesAsync(),
          // Same id SharedPrefsFavoritesStore is built with, so the per-event
          // favourites key matches.
          eventId: EventConfig.astronomyOpenNight.id,
        )),
        locationServiceProvider.overrideWithValue(GeolocatorLocationService()),
        headingServiceProvider.overrideWithValue(SensorsHeadingService()),
      ],
      child: const AonApp(),
    ),
  );
}

class AonApp extends ConsumerStatefulWidget {
  const AonApp({super.key});

  @override
  ConsumerState<AonApp> createState() => _AonAppState();
}

class _AonAppState extends ConsumerState<AonApp> {
  // Built once and held, rather than rebuilt in build(). A GoRouter carries
  // navigation state; recreating it on every rebuild would reset the user to
  // the home screen at random.
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(eventConfigProvider);
    // The app's own reduce-motion preference. It only ever *adds* to what the
    // OS asks for — the app never re-enables animations the platform has
    // turned off.
    final reduceMotion = ref.watch(reduceMotionProvider);

    return MaterialApp.router(
      title: config.name,
      debugShowCheckedModeBanner: false,
      // Both themes are real; `themeMode` decides. Dark is the event default
      // (see EventConfig.defaultThemeMode) but the visitor can override it.
      theme: AonTheme.light(),
      darkTheme: AonTheme.build(),
      themeMode: ref.watch(themeModeProvider).themeMode,
      // Astronomy ships English + Persian only — see l10n.yaml for why we do
      // not inherit MQ Journey's 35 Open Day locales.
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      locale: ref.watch(localeProvider),
      routerConfig: _router,
      // Keep intl's formatting locale in step with the UI locale, so dates
      // and times are never English inside a Persian screen.
      localeResolutionCallback: (device, supported) {
        // Match by language code, falling back to the first supported locale
        // (English). Mirrors Flutter's own resolution for our simple case.
        final resolved = supported.firstWhere(
          (s) => s.languageCode == device?.languageCode,
          orElse: () => supported.first,
        );
        TimeFormat.locale = resolved.toLanguageTag();
        return resolved;
      },
      builder: (context, child) {
        // Clamp the OS text scale to the app's verified range (see
        // lib/app/text_scale.dart). Every surface is hardened to 2.0; the cap
        // is held there deliberately so the app never exposes an unverified
        // scale. Lifting past 2.0 is future accessibility work.
        final media = MediaQuery.of(context);
        final scale = resolveAppTextScaler(media.textScaler);
        return MediaQuery(
          data: media.copyWith(
            textScaler: scale,
            // AonTactileButton and GlassSurface both read
            // MediaQuery.disableAnimations, so folding the preference in here
            // makes one setting reach every animated surface — and keeps the
            // setting honest rather than decorative.
            disableAnimations: media.disableAnimations || reduceMotion,
          ),
          child: child!,
        );
      },
    );
  }
}
