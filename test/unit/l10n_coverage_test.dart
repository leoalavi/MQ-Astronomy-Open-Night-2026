import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

/// Structural guards over the ARB pair.
///
/// `flutter gen-l10n` already fails the build on a key that is missing from a
/// non-template locale, but it says nothing about a key that is *present* and
/// empty, nor about a placeholder that drifted apart between the two files —
/// and a placeholder mismatch is a runtime crash in the locale nobody on the
/// team reads. These assert the parts the generator does not.
void main() {
  final placeholder = RegExp(r'\{(\w+)\}');

  Map<String, dynamic> arb(String name) =>
      json.decode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;

  final en = arb('app_en.arb');
  final fa = arb('app_fa.arb');
  final enKeys = en.keys.where((k) => !k.startsWith('@')).toList();

  test('every English key has a Persian translation', () {
    final missing = enKeys.where((k) => !fa.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'missing from app_fa.arb: $missing');
  });

  test('Persian carries no key English does not', () {
    final extra =
        fa.keys.where((k) => !k.startsWith('@') && !en.containsKey(k)).toList();
    expect(extra, isEmpty, reason: 'orphaned in app_fa.arb: $extra');
  });

  test('no translation is blank in either locale', () {
    for (final k in enKeys) {
      expect((en[k] as String).trim(), isNotEmpty, reason: 'empty EN: $k');
      expect((fa[k] as String).trim(), isNotEmpty, reason: 'empty FA: $k');
    }
  });

  test('placeholders match exactly between English and Persian', () {
    for (final k in enKeys) {
      final e = placeholder.allMatches(en[k] as String).map((m) => m[1]!).toSet();
      final f = placeholder.allMatches(fa[k] as String).map((m) => m[1]!).toSet();
      expect(f, equals(e), reason: 'placeholder drift on "$k"');
    }
  });

  test('every placeholder is declared in the template metadata', () {
    for (final k in enKeys) {
      final used =
          placeholder.allMatches(en[k] as String).map((m) => m[1]!).toSet();
      if (used.isEmpty) continue;
      final meta = en['@$k'] as Map<String, dynamic>?;
      final declared =
          ((meta?['placeholders'] as Map<String, dynamic>?) ?? const {}).keys.toSet();
      // ICU plural bodies name the count placeholder; anything else must be
      // declared or gen-l10n emits a getter instead of a method.
      expect(declared.containsAll(used), isTrue,
          reason: 'undeclared placeholder(s) on "$k": ${used.difference(declared)}');
    }
  });

  test('numeric placeholders are locale-formatted, not raw', () {
    // A bare `{count}` renders Western digits inside an otherwise Persian
    // sentence — "36 دقیقه" instead of "۳۶ دقیقه". decimalPattern is what makes
    // the digits follow the locale.
    for (final k in enKeys) {
      final meta = en['@$k'] as Map<String, dynamic>?;
      final ph = (meta?['placeholders'] as Map<String, dynamic>?) ?? const {};
      ph.forEach((name, spec) {
        final s = spec as Map<String, dynamic>;
        if (s['type'] == 'int') {
          expect(s['format'], 'decimalPattern',
              reason: 'int placeholder "$name" on "$k" needs decimalPattern');
        }
      });
    }
  });

  test('both locales resolve through the generated lookup', () {
    expect(lookupAonL10n(const Locale('en')), isA<AonL10n>());
    expect(lookupAonL10n(const Locale('fa')), isA<AonL10n>());
  });
}
