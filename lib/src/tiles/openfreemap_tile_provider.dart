import 'dart:collection';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'source_tile.dart';
import 'tile_cache.dart';

/// A [TileProvider] that draws OpenFreeMap vector tiles on the device in the Positron style,
/// the light grey look of CARTO's `light_all` basemap.
///
/// Needs no API key. Tiles are downloaded as vector data (the server only has vector data up to
/// zoom 14), decoded off the UI isolate and painted to images at [pixelRatio], so any zoom
/// stays sharp. Everything is pure Dart, so it runs on every platform Flutter runs on,
/// HarmonyOS included.
///
/// Show an `OpenFreeMapAttribution` over the map, as required by the data licences.
///
/// ```dart
/// TileLayer(
///   tileProvider: OpenFreeMapTileProvider(),
///   userAgentPackageName: 'com.example.app',
///   maxZoom: 20,
/// )
/// ```
class OpenFreeMapTileProvider extends TileProvider {
  /// Creates a provider that renders at [pixelRatio] (defaults to the device's, clamped to 1–3).
  ///
  /// [httpClient] is closed on [dispose] only when this provider created it. Downloaded tiles are
  /// kept in [cache] (default [TileCache.platformDefault]) and reused offline and on later runs.
  OpenFreeMapTileProvider({
    double? pixelRatio,
    http.Client? httpClient,
    this.tileJsonUrl = defaultTileJsonUrl,
    this.maxCachedSourceTiles = 16,
    TileCache? cache,
    super.headers,
  }) : cache = cache ?? TileCache.platformDefault(),
       pixelRatio =
           (pixelRatio ?? ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2)
               .clamp(1.0, 3.0)
               .toDouble(),
       _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// The OpenFreeMap TileJSON that names the current tile URL template.
  static const String defaultTileJsonUrl = 'https://tiles.openfreemap.org/planet';

  static const String _styleAsset = 'packages/osm_location_picker/assets/styles/positron.json';

  /// The vector source id the Positron style's layers read from.
  static const String _sourceId = 'openmaptiles';

  static Future<vtr.Theme>? _positron;

  /// Device pixels per logical pixel the tiles are painted at.
  final double pixelRatio;

  /// The TileJSON URL the tile URL template is read from.
  final String tileJsonUrl;

  /// How many decoded zoom ≤ 14 tiles are kept in memory for reuse by deeper zooms.
  final int maxCachedSourceTiles;

  /// Where downloaded tiles and the tile URL template are kept between runs.
  final TileCache cache;

  static const String _urlTemplateKey = 'tilejson-url-template';

  final http.Client _client;
  final bool _ownsClient;
  Future<String>? _urlTemplate;
  final LinkedHashMap<TileCoordinates, Future<vtr.Tileset>> _tilesets = LinkedHashMap();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => OpenFreeMapTileImage(this, coordinates);

  /// Paints the map tile at [coordinates], downloading its data unless already cached.
  Future<ui.Image> renderTile(TileCoordinates coordinates) async {
    final vtr.Theme theme = await _loadPositron();
    final SourceTile source = SourceTile.of(coordinates);
    final vtr.Tileset tileset = await _tileset(source.coordinates, theme);

    final int pixels = (256 * pixelRatio).round();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas =
        ui.Canvas(recorder)
          ..scale(pixelRatio * source.scale)
          ..translate(-source.region.left, -source.region.top);
    vtr.Renderer(theme: theme).render(
      canvas,
      vtr.TileSource(tileset: tileset),
      clip: source.region,
      zoomScaleFactor: source.scale,
      zoom: coordinates.z.toDouble(),
      rotation: 0,
    );
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(pixels, pixels);
    } finally {
      picture.dispose();
    }
  }

  @override
  void dispose() {
    _tilesets.clear();
    if (_ownsClient) _client.close();
    super.dispose();
  }

  static Future<vtr.Theme> _loadPositron() =>
      _positron ??= rootBundle
          .loadString(_styleAsset)
          .then((String json) => vtr.ThemeReader().read(jsonDecode(json) as Map<String, dynamic>))
          .catchError((Object error, StackTrace stackTrace) {
            _positron = null;
            return Future<vtr.Theme>.error(error, stackTrace);
          });

  /// Returns the decoded tile, sharing one download between every deeper tile cut from it.
  Future<vtr.Tileset> _tileset(TileCoordinates coordinates, vtr.Theme theme) {
    final Future<vtr.Tileset>? cached = _tilesets.remove(coordinates);
    if (cached != null) return _tilesets[coordinates] = cached;

    final Future<vtr.Tileset> loading = _downloadTileset(coordinates, theme);
    _tilesets[coordinates] = loading;
    while (_tilesets.length > maxCachedSourceTiles) {
      _tilesets.remove(_tilesets.keys.first);
    }
    loading.catchError((Object _) {
      if (identical(_tilesets[coordinates], loading)) _tilesets.remove(coordinates);
      return vtr.Tileset(const {});
    });
    return loading;
  }

  Future<vtr.Tileset> _downloadTileset(TileCoordinates coordinates, vtr.Theme theme) async {
    final String url = (await _loadUrlTemplate())
        .replaceAll('{z}', '${coordinates.z}')
        .replaceAll('{x}', '${coordinates.x}')
        .replaceAll('{y}', '${coordinates.y}');
    // Tile URLs carry OpenFreeMap's data version, so a cached tile is never stale for its URL.
    Uint8List? bytes = await cache.read(url);
    if (bytes == null) {
      bytes = await _get(url);
      await cache.write(url, bytes);
    }
    if (bytes.isEmpty) return vtr.Tileset(const {});

    final vtr.TileData data = await compute(_decode, (theme, bytes));
    return vtr.Tileset({_sourceId: data.toTile()});
  }

  /// Reads the tile URL template from the TileJSON; OpenFreeMap versions it with each data release.
  ///
  /// Offline, the template from the last successful read is used, so cached tiles still load.
  Future<String> _loadUrlTemplate() =>
      _urlTemplate ??= _fetchUrlTemplate().catchError((Object error, StackTrace stackTrace) {
        _urlTemplate = null;
        return Future<String>.error(error, stackTrace);
      });

  Future<String> _fetchUrlTemplate() async {
    try {
      final Object? tiles = (jsonDecode(utf8.decode(await _get(tileJsonUrl))) as Map<String, dynamic>)['tiles'];
      if (tiles is! List || tiles.isEmpty || tiles.first is! String) {
        throw FormatException('No tile URL in $tileJsonUrl');
      }
      final String template = tiles.first as String;
      await cache.write(_urlTemplateKey, Uint8List.fromList(utf8.encode(template)));
      return template;
    } catch (_) {
      final Uint8List? cached = await cache.read(_urlTemplateKey);
      if (cached == null) rethrow;
      return utf8.decode(cached);
    }
  }

  Future<Uint8List> _get(String url) async {
    final http.Response response = await _client.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', Uri.parse(url));
    }
    return response.bodyBytes;
  }
}

vtr.TileData _decode((vtr.Theme, Uint8List) input) {
  final (vtr.Theme theme, Uint8List bytes) = input;
  return vtr.TileFactory(theme, const vtr.Logger.noop()).createTileData(vtr.VectorTileReader().read(bytes));
}

/// The image of one map tile from an [OpenFreeMapTileProvider].
@immutable
final class OpenFreeMapTileImage extends ImageProvider<OpenFreeMapTileImage> {
  /// Creates the image of the tile at [coordinates] painted by [provider].
  const OpenFreeMapTileImage(this.provider, this.coordinates);

  /// The provider that downloads and paints the tile.
  final OpenFreeMapTileProvider provider;

  /// The map tile to paint.
  final TileCoordinates coordinates;

  @override
  Future<OpenFreeMapTileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(OpenFreeMapTileImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(
    provider.renderTile(coordinates).then((ui.Image image) => ImageInfo(image: image, debugLabel: '$this')),
    informationCollector: () => [DiagnosticsProperty<TileCoordinates>('Tile', coordinates)],
  );

  @override
  bool operator ==(Object other) =>
      other is OpenFreeMapTileImage && identical(other.provider, provider) && other.coordinates == coordinates;

  @override
  int get hashCode => Object.hash(identityHashCode(provider), coordinates);

  @override
  String toString() => 'OpenFreeMapTileImage(${coordinates.z}/${coordinates.x}/${coordinates.y})';
}
