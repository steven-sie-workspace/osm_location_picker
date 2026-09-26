import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

/// OpenFreeMap serves vector tiles up to this zoom; deeper tiles are cut from a tile at this zoom.
const int openFreeMapMaxNativeZoom = 14;

/// The vector tile that holds the data for a requested map tile, and which part of it to draw.
///
/// At or below [openFreeMapMaxNativeZoom] the requested tile is its own source. Deeper, the
/// requested tile is a square region of its ancestor at [openFreeMapMaxNativeZoom], drawn
/// [scale] times larger.
@immutable
final class SourceTile {
  /// The tile to download and decode.
  final TileCoordinates coordinates;

  /// The part of [coordinates] covered by the requested tile, in 256-unit tile space.
  final Rect region;

  /// How many times larger than native the region is drawn: `2^(requested zoom - source zoom)`.
  final double scale;

  const SourceTile._(this.coordinates, this.region, this.scale);

  /// Maps [requested] to the tile that carries its data.
  factory SourceTile.of(TileCoordinates requested, {int maxNativeZoom = openFreeMapMaxNativeZoom}) {
    final int levels = requested.z - maxNativeZoom;
    if (levels <= 0) return SourceTile._(requested, const Rect.fromLTWH(0, 0, 256, 256), 1);

    final int factor = 1 << levels;
    final double size = 256 / factor;
    return SourceTile._(
      TileCoordinates(requested.x ~/ factor, requested.y ~/ factor, maxNativeZoom),
      Rect.fromLTWH((requested.x % factor) * size, (requested.y % factor) * size, size, size),
      factor.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SourceTile && other.coordinates == coordinates && other.region == region && other.scale == scale;

  @override
  int get hashCode => Object.hash(coordinates, region, scale);

  @override
  String toString() => 'SourceTile($coordinates, $region, x$scale)';
}
