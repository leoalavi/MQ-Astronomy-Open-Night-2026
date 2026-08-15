import 'dart:async';
import 'package:aon2026/services/heading_service.dart';

class FakeHeadingService implements HeadingService {
  final _c = StreamController<HeadingSample>.broadcast();
  void emit(HeadingSample s) => _c.add(s);
  void emitError(Object e) => _c.addError(e);
  @override
  Stream<HeadingSample> watch() => _c.stream;
}
