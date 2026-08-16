import 'package:aon2026/services/compass_controller.dart';

/// A CompassController whose state is fixed — bypasses the real heading
/// subscription so widget tests can pin any [CompassState] (§0R-O). Use via
/// `compassControllerProvider.overrideWith(() => FakeCompassController(state))`.
class FakeCompassController extends CompassController {
  FakeCompassController(this._state);
  final CompassState _state;
  @override
  CompassState build() => _state;
}
