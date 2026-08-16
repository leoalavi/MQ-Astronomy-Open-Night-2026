import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:aon2026/models/building.dart';

const String buildingsAssetPath = 'assets/data/buildings.json';

Future<List<Building>> loadBuildings(AssetBundle bundle) async {
  final raw = await bundle.loadString(buildingsAssetPath);
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map(Building.fromJson).toList(growable: false);
}
