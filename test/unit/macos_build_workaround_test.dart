import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the macOS "Flutter Assemble" deployment-target workaround.
///
/// clang 21 (shipped with Xcode 26) started treating *multiple* per-platform
/// `*_DEPLOYMENT_TARGET` environment variables as a hard error rather than a
/// warning. `xcodebuild` leaks a visionOS ('XR') deployment target into the
/// "Flutter Assemble" run-script phase, which then collides with the macOS one
/// when `flutter assemble` compiles `debug_app.cc` into `App.framework`:
///
///   clang: error: conflicting deployment targets, both '26.5' and '25.5' are
///   present in environment
///   clang: warning: using sysroot for 'MacOSX' but targeting 'XR'
///
/// See flutter/flutter#178195. A macOS build needs none of the other platform
/// targets, so the run-script phase drops them before assembling. `flutter
/// create` (re)generates this pbxproj and would silently remove the fix, so
/// this test fails the moment it goes missing — before the next macOS build
/// breaks for real.
void main() {
  final pbxproj = File('macos/Runner.xcodeproj/project.pbxproj');

  test('the macOS project exists (the target was added)', () {
    expect(pbxproj.existsSync(), isTrue,
        reason: 'run `flutter create --platforms=macos .` to add it back');
  });

  test('the Flutter Assemble phase unsets the non-macOS deployment targets', () {
    final src = pbxproj.readAsStringSync();
    // The one that actually collides on Xcode 26; the others are belt-and-braces.
    expect(src, contains('unset XROS_DEPLOYMENT_TARGET'),
        reason: 'flutter/flutter#178195 workaround is missing — `flutter build '
            'macos` will fail with "conflicting deployment targets". Re-add the '
            'unset to the "Flutter Assemble" run-script phase.');
    expect(src, contains('macos_assemble.sh'),
        reason: 'the unset must sit in the same phase that runs '
            'macos_assemble.sh, so it reaches the debug_app.cc clang subprocess');
  });
}
