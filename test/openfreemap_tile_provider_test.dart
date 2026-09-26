import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:osm_location_picker/src/tiles/openfreemap_tile_provider.dart';
import 'package:osm_location_picker/src/tiles/tile_cache.dart';

const String _tileJson = 'https://tiles.openfreemap.org/planet';
const String _tileUrl = 'https://tiles.openfreemap.org/planet/test';
final Uint8List _fixture = File('test/fixtures/14_12825_8037.pbf').readAsBytesSync();

/// Serves the TileJSON and the fixture tile, failing the first [failures] tile requests.
MockClient _server(List<String> requests, {int failures = 0}) => MockClient((http.Request request) async {
  final String url = request.url.toString();
  if (url == _tileJson) {
    return http.Response(
      jsonEncode({
        'tiles': ['$_tileUrl/{z}/{x}/{y}.pbf'],
      }),
      200,
    );
  }
  requests.add(url);
  if (failures-- > 0) return http.Response('', 503);
  return http.Response.bytes(_fixture, 200);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // A package's own tests bundle its assets without the `packages/<name>/` prefix the provider asks for.
    final ByteData style = ByteData.sublistView(File('assets/styles/positron.json').readAsBytesSync());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
      return key == 'packages/osm_location_picker/assets/styles/positron.json' ? style : null;
    });
  });

  testWidgets('paints a native tile at the requested pixel ratio', (WidgetTester tester) async {
    final List<String> requests = [];
    final OpenFreeMapTileProvider provider = OpenFreeMapTileProvider(
      pixelRatio: 2,
      httpClient: _server(requests),
      cache: TileCache.none,
    );

    final ui.Image image = (await tester.runAsync(() => provider.renderTile(const TileCoordinates(12825, 8037, 14))))!;

    expect(requests, ['$_tileUrl/14/12825/8037.pbf']);
    expect((image.width, image.height), (512, 512));
    expect(await _distinctColours(tester, image), greaterThan(1), reason: 'the tile should show map features');
  });

  testWidgets('deeper tiles share one download of their zoom 14 tile', (WidgetTester tester) async {
    final List<String> requests = [];
    final OpenFreeMapTileProvider provider = OpenFreeMapTileProvider(
      pixelRatio: 1,
      httpClient: _server(requests),
      cache: TileCache.none,
    );

    final List<ui.Image> images =
        (await tester.runAsync(
          () => Future.wait([
            for (final (int dx, int dy) in [(0, 0), (1, 0), (0, 1), (1, 1)])
              provider.renderTile(TileCoordinates(2 * 12825 + dx, 2 * 8037 + dy, 15)),
          ]),
        ))!;

    expect(requests, ['$_tileUrl/14/12825/8037.pbf']);
    expect(images.map((ui.Image image) => image.width), everyElement(256));
  });

  testWidgets('a failed download is retried on the next request', (WidgetTester tester) async {
    final List<String> requests = [];
    final OpenFreeMapTileProvider provider = OpenFreeMapTileProvider(
      pixelRatio: 1,
      httpClient: _server(requests, failures: 1),
      cache: TileCache.none,
    );
    const TileCoordinates tile = TileCoordinates(12825, 8037, 14);

    await tester.runAsync(() => expectLater(provider.renderTile(tile), throwsA(isA<http.ClientException>())));
    final ui.Image? image = await tester.runAsync(() => provider.renderTile(tile));

    expect(requests, hasLength(2));
    expect(image?.width, 256);
  });

  testWidgets('tiles and the tile URL come from the cache when offline', (WidgetTester tester) async {
    final _MemoryCache cache = _MemoryCache();
    final List<String> online = [];
    const TileCoordinates tile = TileCoordinates(12825, 8037, 14);
    await tester.runAsync(
      () => OpenFreeMapTileProvider(pixelRatio: 1, httpClient: _server(online), cache: cache).renderTile(tile),
    );

    final List<Uri> offline = [];
    final OpenFreeMapTileProvider provider = OpenFreeMapTileProvider(
      pixelRatio: 1,
      cache: cache,
      httpClient: MockClient((http.Request request) async {
        offline.add(request.url);
        throw http.ClientException('offline', request.url);
      }),
    );
    final ui.Image? image = await tester.runAsync(() => provider.renderTile(tile));

    expect(image?.width, 256);
    expect(offline, [Uri.parse(_tileJson)], reason: 'only the TileJSON refresh is tried; the tile is not');
  });
}

Future<int> _distinctColours(WidgetTester tester, ui.Image image) async {
  final ByteData? bytes = await tester.runAsync<ByteData?>(() => image.toByteData());
  return {for (int i = 0; i < bytes!.lengthInBytes; i += 4) bytes.getUint32(i)}.length;
}

/// A [TileCache] kept in memory, shared between providers in one test.
class _MemoryCache implements TileCache {
  final Map<String, Uint8List> _entries = {};

  @override
  Future<Uint8List?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, Uint8List bytes) async => _entries[key] = bytes;
}
