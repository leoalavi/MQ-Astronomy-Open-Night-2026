import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// **The app is an independent project. It must not present itself as, or
/// imply endorsement by, a university.**
///
/// The project supervisor instructed on 2026-09-07 that the university's name
/// must not be used for anything, because the university has not approved the
/// project: *"These are your projects."* That is a hard requirement, and this
/// file is its tripwire.
///
/// It deliberately does NOT ban the university's name from engineering
/// provenance comments, from factual venue names printed on physical signage,
/// or from the authorised artwork itself — we have permission to use that
/// artwork. What it bans is **branding, institutional identifiers, and
/// ownership or affiliation claims on visitor-facing surfaces**.
void main() {
  const arbs = ['lib/l10n/app_en.arb', 'lib/l10n/app_fa.arb'];

  /// Shipped strings that may name the university, each with the reason.
  /// Adding a key here is a deliberate act — justify it in review.
  const geographicAllowlist = <String, String>{
    // "Macquarie University" is the registered Transport for NSW name of the
    // Metro station. It is a transport fact visitors navigate by at night, not
    // a claim of affiliation; the next station along is "Macquarie Park", so
    // genericising it would send people to the wrong platform.
    'homeFactMetroBody': 'Transport for NSW station name — wayfinding fact',
  };

  test('no shipped UI string names the university', () async {
    for (final path in arbs) {
      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

      decoded.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        final names = value.toLowerCase().contains('macquarie') ||
            value.contains('مکواری');
        if (!names) return;
        expect(
          geographicAllowlist.containsKey(key),
          isTrue,
          reason: '$path: "$key" names the university in a visitor-facing '
              'string. The app is an independent project with no university '
              'approval — rewrite it, or, if it is an unavoidable geographic '
              'or transport fact, add it to geographicAllowlist with a reason.',
        );
      });
    }
  });

  test('no shipped UI string carries an institutional identifier', () async {
    // These identify the institution itself and cannot appear in an app that
    // is not the institution's: a CRICOS provider code is a government
    // registration number, and the rest are its faculty and social handles.
    const banned = [
      'CRICOS',
      '00002J',
      'Faculty of Science and Engineering',
      'MQPhysAstro',
      'MQAstroOpen',
    ];
    for (final path in arbs) {
      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      // Shipped values only. An "@key" description may name an identifier in
      // order to explain why it is banned.
      decoded.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        for (final b in banned) {
          expect(value.toLowerCase(), isNot(contains(b.toLowerCase())),
              reason: '$path: "$key" carries the institutional '
                  'identifier "$b"');
        }
      });
    }
  });

  test('no Dart source ships an institutional identifier', () async {
    const banned = [
      'CRICOS',
      '00002J',
      'Faculty of Science and Engineering',
      'MQPhysAstro',
      'MQAstroOpen',
    ];
    final offenders = <String>[];
    await for (final e in Directory('lib').list(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final lines = await e.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Provenance comments are the project's audit trail of what is
        // authorised — they are not shipped UI and stay.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        for (final b in banned) {
          if (line.contains(b)) offenders.add('${e.path}:${i + 1}  $b');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'institutional identifiers must not reach shipped code');
  });

  // The most visible branding in the app was never text: the bundled basemap
  // carried the university crest and wordmark in its top-right corner. The
  // artwork is authorised and stays; the lockup was painted out in place, at
  // identical 2048x1448 dimensions so every venue pin and the georeference are
  // untouched. This asserts the corner is still clear — the realistic
  // regression is someone restoring the original PNG.
  test('the bundled basemap carries no university lockup', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final bytes = await File('assets/maps/aon_event_map.png').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    expect(image.width, 2048, reason: 'basemap width drives the georeference');
    expect(image.height, 1448, reason: 'basemap height drives the georeference');

    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(data, isNotNull);
    final px = data!.buffer.asUint8List();

    // The rectangle the crest and wordmark occupied.
    const x0 = 1750, x1 = 1976, y0 = 50, y1 = 265;
    var nonWhite = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * image.width + x) * 4;
        if (px[i] != 255 || px[i + 1] != 255 || px[i + 2] != 255) nonWhite++;
      }
    }
    image.dispose();

    expect(nonWhite, 0,
        reason: 'the basemap top-right corner is not clear — the university '
            'crest/wordmark appears to have been restored. The artwork is '
            'authorised, the university lockup is not.');
  });
}
