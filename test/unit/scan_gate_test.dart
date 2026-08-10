import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/scan_gate.dart';

void main() {
  test('accepts first decode only, resumes after reset', () {
    final g = ScanGate();
    expect(g.accept(), isTrue);
    expect(g.accept(), isFalse);
    g.reset();
    expect(g.accept(), isTrue);
  });
}
