import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

Widget _map(List<Widget> layers) => MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          options: const MapOptions(initialCenter: MapConfig.campusCentre),
          children: [const _EmptyTiles(), ...layers],
        ),
      ),
    );

class _EmptyTiles extends StatelessWidget {
  const _EmptyTiles();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('normal fix renders a CircleLayer + a MarkerLayer', (t) async {
    final fix =
        UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 10);
    await t.pumpWidget(_map([
      UserLocationCircle(fix: fix),
      UserLocationDot(fix: fix),
    ]));
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(t.takeException(), isNull); // context.aon fell back cleanly
  });

  testWidgets('low-accuracy fix omits the CircleLayer', (t) async {
    final fix =
        UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 500);
    await t.pumpWidget(_map([
      UserLocationCircle(fix: fix),
      UserLocationDot(fix: fix),
    ]));
    expect(find.byType(CircleLayer), findsNothing);
    expect(find.byType(MarkerLayer), findsOneWidget); // dot still shows
  });
}
