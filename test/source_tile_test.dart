import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osm_location_picker/src/tiles/source_tile.dart';

void main() {
  test('a tile at or below the native zoom is its own source', () {
    final SourceTile source = SourceTile.of(const TileCoordinates(12825, 8037, 14));

    expect(source.coordinates, const TileCoordinates(12825, 8037, 14));
    expect(source.region, const Rect.fromLTWH(0, 0, 256, 256));
    expect(source.scale, 1);
  });

  test('a deeper tile is a scaled region of its zoom 14 ancestor', () {
    // Zoom 16 splits each zoom 14 tile into 4 x 4; x 51301 = 12825 * 4 + 1, y 32150 = 8037 * 4 + 2.
    final SourceTile source = SourceTile.of(const TileCoordinates(51301, 32150, 16));

    expect(source.coordinates, const TileCoordinates(12825, 8037, 14));
    expect(source.region, const Rect.fromLTWH(64, 128, 64, 64));
    expect(source.scale, 4);
  });

  test('the four children of a tile cover it exactly', () {
    final Set<Rect> regions = {
      for (final (int dx, int dy) in [(0, 0), (1, 0), (0, 1), (1, 1)])
        SourceTile.of(TileCoordinates(2 * 12825 + dx, 2 * 8037 + dy, 15)).region,
    };

    expect(regions, {
      const Rect.fromLTWH(0, 0, 128, 128),
      const Rect.fromLTWH(128, 0, 128, 128),
      const Rect.fromLTWH(0, 128, 128, 128),
      const Rect.fromLTWH(128, 128, 128, 128),
    });
  });
}
