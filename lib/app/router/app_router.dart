import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/screens/event_detail_screen.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/info_screen.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/screens/panorama_screen.dart';
import 'package:aon2026/screens/point_me_screen.dart';
import 'package:aon2026/screens/google_nav_screen.dart';
import 'package:aon2026/screens/passport_reward_screen.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/screens/privacy_screen.dart';
import 'package:aon2026/widgets/app_shell.dart';

/// Route paths, in one place so nothing hard-codes a string literal.
abstract final class Routes {
  // ── Tabs ──
  static String home = '/';
  static String program = '/program';
  static String myNight = '/my-night';
  static String map = '/map';

  /// The Map tab, opened focused on one place ("venue:x" / "building:y").
  ///
  /// "Show on map" used to `go(Routes.map)` and drop the place entirely, which
  /// dumped the visitor on an unchanged campus map with nothing selected and no
  /// clue which pin they came for. The focus key is what lets the Map tab
  /// select the place, move the camera to it and open its sheet.
  static String mapFocus(String placeKey) =>
      '/map?focus=${Uri.encodeComponent(placeKey)}';

  static String info = '/info';

  /// Full-screen pages pushed above the tab shell.
  static String eventDetail = '/event/:id';
  static String wayfinding = '/wayfinding';
  static String settings = '/settings';

  /// Standalone Privacy page. On web this is the canonical, shareable
  /// `…/astronomy-open-night/privacy` address; it is a full-screen route above
  /// the shell so a deep link or refresh lands straight on it.
  static String privacy = '/privacy';

  /// Astronomy Passport (Phase 6). Builders are registered in the tasks that
  /// create each screen, so no builder imports a screen before it exists.
  static String passport = '/passport';
  static String passportScan = '/passport/scan';
  static String passportReward = '/passport/reward';

  static String eventDetailFor(String id) => '/event/$id';

  /// Wayfinding, pre-seeded with a destination.
  static String wayfindingTo(String venueId) => '/wayfinding?to=$venueId';

  /// Immersive 360° panorama for a venue.
  static String panorama = '/panorama/:venueId';
  static String panoramaFor(String venueId) => '/panorama/$venueId';

  /// "Point me there" heading screen for a venue or parking id. The helper owns
  /// URL-encoding of the id (Map Parity Phase B).
  static String pointMe = '/point-me/:id';
  static String pointMeTo(String id) => '/point-me/${Uri.encodeComponent(id)}';

  /// Embedded Google walking-nav for a M3 place key ("venue:x" / "building:y").
  /// The helper URL-encodes the key (it contains a colon). M4.
  static String googleNav = '/google-nav/:placeKey';
  static String googleNavTo(String placeKey) =>
      '/google-nav/${Uri.encodeComponent(placeKey)}';
}

/// The app's navigator.
///
/// Uses a `StatefulShellRoute` so each of the six tabs keeps its own
/// navigation stack and scroll position. That matters more here than in most
/// apps: an attendee routinely bounces between the map and the programme, and
/// losing your place in a 35-item programme every time you check the map would
/// be maddening while walking.
///
/// Structure follows MQ Journey's `go_router` setup (REUSE WITH MODIFICATION);
/// the routes themselves are entirely this product's.
GoRouter buildRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.program,
                builder: (context, state) => const ProgramScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.myNight,
                builder: (context, state) => const MyNightScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (context, state) => MapScreen(
                  // Set by Routes.mapFocus — "Show on map" hands the place over
                  // so the tab opens ON it rather than merely switching tabs.
                  focusPlaceKey: state.uri.queryParameters['focus'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.info,
                builder: (context, state) => const InfoScreen(),
              ),
            ],
          ),
          // Settings is a primary destination, not a gear icon buried in a
          // header: Info answers "about the event", Settings answers "how the
          // app behaves", and ordinary visitors must be able to tell them apart
          // at a glance. Appended last so Map stays branch index 3 (the GPS
          // lifecycle in AppShell keys off that index).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Pushed above the shell — these hide the tab bar, because they are
      // tasks you complete and back out of rather than places you browse.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.eventDetail,
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.wayfinding,
        builder: (context, state) => WayfindingScreen(
          initialDestinationId: state.uri.queryParameters['to'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.panorama,
        builder: (context, state) =>
            PanoramaScreen(venueId: state.pathParameters['venueId']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.pointMe,
        builder: (context, state) =>
            PointMeScreen(venueId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.googleNav,
        builder: (context, state) =>
            GoogleNavScreen(placeKey: state.pathParameters['placeKey']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passportScan,
        builder: (context, state) => const PassportScanScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passportReward,
        builder: (context, state) => const PassportRewardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passport,
        builder: (context, state) => const PassportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      // `/night` is a friendly alias for the My Night tab (`/my-night`), kept so
      // a shared `…/night` link resolves rather than 404-ing. Redirect-only, so
      // the canonical tab URL stays `/my-night`.
      GoRoute(
        path: '/night',
        redirect: (context, state) => Routes.myNight,
      ),
    ],
  );
}
