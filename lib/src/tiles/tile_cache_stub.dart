import 'tile_cache.dart';

/// Web: no disk cache; HTTP caching in the browser covers repeat visits.
TileCache createDefaultTileCache() => TileCache.none;
