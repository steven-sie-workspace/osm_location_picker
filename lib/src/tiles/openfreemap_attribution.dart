import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'openfreemap_tile_provider.dart';

/// The data credit OpenFreeMap tiles must show, as a [FlutterMap] child placed after the tile layer.
class OpenFreeMapAttribution extends StatelessWidget {
  /// Creates the credit, pinned to [alignment] of the map.
  const OpenFreeMapAttribution({super.key, this.alignment = Alignment.bottomRight, this.backgroundColor});

  /// Where on the map the credit sits.
  final Alignment alignment;

  /// The credit's background; defaults to the theme's surface colour.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => SimpleAttributionWidget(
    source: const Text(OpenFreeMapTileProvider.attribution, style: TextStyle(fontSize: 10)),
    alignment: alignment,
    backgroundColor: backgroundColor,
  );
}
