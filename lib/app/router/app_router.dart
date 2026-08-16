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
import 'package:aon2026/screens/whats_on_screen.dart';
import 'package:aon2026/widgets/app_shell.dart';

/// Route paths, in one place so nothing hard-codes a string literal.
abstract final class Routes {
  // ── Tabs ──
  static String home = '/';
  static String program = '/program';
  static String myNight = '/my-night';
  static String map = '/map';
  static String info = '/info';

  /// Full-screen pages pushed above the tab shell.
  static String eventDetail = '/event/:id';
  static String wayfinding = '/wayfinding';
  static String settings = '/settings';

  /// The time-sliced programme view. Home surfaces the same content inline,
  /// so this is a "see everything" push rather than a tab of its own —
  /// keeping the tab bar at five.
  static String whatsOn = '/whats-on';

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
  static String googleNavTo(String placeKey) => '/google-nav/${Uri.encodeComponent(placeKey)}';
}

/// The app's navigator.
///
/// Uses a `StatefulShellRoute` so each of the five tabs keeps its own
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
                builder: (context, state) => const MapScreen(),
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
        ],
      ),

      // Pushed above the shell — these hide the tab bar, because they are
      // tasks you complete and back out of rather than places you browse.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.eventDetail,
        builder: (context, state) => EventDetailScreen(
          eventId: state.pathParameters['id']!,
        ),
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
        path: Routes.whatsOn,
        builder: (context, state) => const WhatsOnScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.panorama,
        builder: (context, state) => PanoramaScreen(
          venueId: state.pathParameters['venueId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.pointMe,
        builder: (context, state) => PointMeScreen(
          venueId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.googleNav,
        builder: (context, state) => GoogleNavScreen(
          placeKey: state.pathParameters['placeKey']!,
        ),
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
    ],
  );
}
