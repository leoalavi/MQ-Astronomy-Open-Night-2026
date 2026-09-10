import 'package:flutter/material.dart';

import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_web_view.dart' show PanoramaUnavailable;

/// Mobile placeholder for [buildPanoramaWebViewer].
///
/// Never rendered on native — the caller only reaches the web viewer under
/// `kIsWeb` — but it must exist and compile so the conditional import in
/// `panorama_web_viewer.dart` resolves on every platform. If it somehow *were*
/// shown, the honest "preview unavailable" state is the right thing to draw.
Widget buildPanoramaWebViewer({
  required IndoorManifest manifest,
  required String? sceneId,
  required ValueChanged<String> onSceneChanged,
  required bool reduceMotion,
}) => const PanoramaUnavailable();
