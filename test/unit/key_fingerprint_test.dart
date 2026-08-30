import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/nav_trace.dart';

/// The on-device Routes 401 (a key valid here, rejected there) is pinned to a
/// KEY MISMATCH without ever printing key material, via a one-way fingerprint.
void main() {
  group('keyFingerprint is a safe, discriminating fingerprint', () {
    test('the same key always fingerprints the same (stable across calls)', () {
      const key = 'AIzaSyA1234567890abcdefghijklmnopqrstuv';
      expect(keyFingerprint(key), keyFingerprint(key));
    });

    test('a different key fingerprints differently (catches a stale key)', () {
      const a = 'AIzaSyA1234567890abcdefghijklmnopqrstuv';
      const b = 'AIzaSyB1234567890abcdefghijklmnopqrstuv'; // one char differs
      expect(keyFingerprint(a), isNot(keyFingerprint(b)));
    });

    test('it never contains the key itself (no secret leak)', () {
      const key = 'AIzaSyA1234567890abcdefghijklmnopqrstuv';
      final fp = keyFingerprint(key);
      expect(fp.contains(key), isFalse);
      expect(fp.contains(key.substring(4)), isFalse);
      // Only the length and an 8-hex-digit hash are exposed.
      expect(fp, matches(RegExp(r'^len=\d+ fp=[0-9a-f]{8}$')));
    });

    test('an empty key is reported as absent, not hashed', () {
      expect(keyFingerprint(''), 'len=0 fp=none');
    });

    test('the length is the real key length (a truncated key is visible)', () {
      expect(keyFingerprint('abc'), startsWith('len=3 '));
    });
  });
}
