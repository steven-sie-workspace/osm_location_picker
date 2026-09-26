import 'dart:typed_data';

import 'tile_cache_stub.dart' if (dart.library.io) 'tile_cache_io.dart' as platform;

/// Stores downloaded map data (vector tiles and the tile URL template) between app runs.
///
/// Reads and writes never throw: a cache that can't be used behaves as empty.
abstract interface class TileCache {
  /// The platform default: a size- and age-limited folder in the app's cache directory on
  /// phones and desktops (HarmonyOS included), nothing on the web (the browser caches instead).
  factory TileCache.platformDefault() => platform.createDefaultTileCache();

  /// A cache that stores nothing.
  static const TileCache none = _NoTileCache();

  /// The bytes stored under [key], or `null` when absent, expired or unreadable.
  Future<Uint8List?> read(String key);

  /// Stores [bytes] under [key], replacing any previous value.
  Future<void> write(String key, Uint8List bytes);
}

final class _NoTileCache implements TileCache {
  const _NoTileCache();

  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, Uint8List bytes) async {}
}
