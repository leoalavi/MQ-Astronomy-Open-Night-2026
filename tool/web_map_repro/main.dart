// Web-only reproduction / verification harness for the Google Directions map.
//
// NOT shipped. Run with:
//   flutter run -d web-server --web-port 8099 \
//     --target tool/web_map_repro/main.dart --dart-define-from-file=.env.web
// or build + serve build/web.
//
// It reproduces the nav-screen sequence that blanks the web map: the map is
// shown first with no route, then a moment later the info panel appears (the map
// shrinks) AND the route arrives (a camera fit). Query flags isolate the causes:
//   ?surface=plugin|web   which EmbeddedMapSurface to use (default plugin)
//   ?fit=on|off           whether the surface fits the camera (web surface only)
//   ?dest=1|2             which destination (multi-destination test)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:aon2026/services/maps_js_loader.dart';
import 'package:aon2026/widgets/embedded_map.dart';

const _key = String.fromEnvironment('MAPS_API_KEY');

// Central Courtyard (preview origin) → 11 Wally's Walk, with an L-shaped path
// that visibly connects the two markers.
const _origin = (-33.7737, 151.1134);
const _dest1 = (-33.7746267, 151.1151193); // 11 Wally's Walk
const _route1 = <(double, double)>[
  (-33.7737, 151.1134),
  (-33.7737, 151.11465),
  (-33.77435, 151.11475),
  (-33.7746267, 151.1151193),
];
// A second, LONGER destination (Mason Theatre-ish, east) for the multi-dest test
// — deliberately a different number of points AND a different span.
const _dest2 = (-33.7748, 151.1128);
const _route2 = <(double, double)>[
  (-33.7737, 151.1134),
  (-33.7742, 151.1131),
  (-33.7748, 151.1128),
];

void main() {
  runApp(const _App());
}

Uri get _uri => Uri.parse(web.window.location.href);
String _flag(String k, String fallback) => _uri.queryParameters[k] ?? fallback;

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const _Harness(),
  );
}

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _ready = false;
  bool _panelShown = false; // false = map full height, route empty
  int _dest = 1;

  @override
  void initState() {
    super.initState();
    _dest = _flag('dest', '1') == '2' ? 2 : 1;
    _boot();
  }

  Future<void> _boot() async {
    final ok = await loadGoogleMapsJs(_key);
    if (!mounted) return;
    setState(() => _ready = ok);
    // Reproduce the real sequence: 1.4s after the map exists, the route arrives
    // and the info panel appears (map shrinks + camera fit) — the exact moment
    // the real screen blanked.
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _panelShown = true);
    });
  }

  (double, double) get _dst => _dest == 1 ? _dest1 : _dest2;
  List<(double, double)> get _routePts => _dest == 1 ? _route1 : _route2;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: Text('Loading Google Maps JS…')),
      );
    }
    final surfaceFlag = _flag('surface', 'plugin');
    final EmbeddedMapSurface surface = surfaceFlag == 'web'
        ? const GoogleEmbeddedMapSurface() // replaced below once web surface lands
        : const GoogleEmbeddedMapSurface();
    final route = _panelShown ? _routePts : const <(double, double)>[];

    return Scaffold(
      appBar: AppBar(title: Text('repro dest=$_dest surface=$surfaceFlag')),
      body: Column(
        children: [
          Expanded(
            child: EmbeddedMap(
              origin: _origin,
              destination: _dst,
              route: route,
              surface: surface,
            ),
          ),
          if (_panelShown)
            Container(
              width: double.infinity,
              color: const Color(0xFF101418),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(child: Text('227 m · 3 min — walking steps…')),
                  TextButton(
                    onPressed: () => setState(() => _dest = _dest == 1 ? 2 : 1),
                    child: const Text('Swap destination'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
