import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osm_location_picker/src/tiles/tile_cache_io.dart';

void main() {
  late Directory root;
  late DateTime now;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tile_cache_test');
    now = DateTime(2026, 9, 26, 12);
  });
  tearDown(() => root.deleteSync(recursive: true));

  Directory folder() => Directory('${root.path}/tiles');
  DiskTileCache cache({int maxBytes = 1024}) =>
      DiskTileCache(Future.value(folder()), maxBytes: maxBytes, maxAge: const Duration(days: 30), now: () => now);
  Uint8List bytes(int length, [int value = 1]) => Uint8List(length)..fillRange(0, length, value);

  test('reads back what was written, in a later instance too', () async {
    await cache().write('https://tiles.example/14/1/2.pbf', bytes(10, 7));

    expect(await cache().read('https://tiles.example/14/1/2.pbf'), bytes(10, 7));
    expect(await cache().read('https://tiles.example/14/1/3.pbf'), isNull);
  });

  test('an expired entry reads as absent and is removed', () async {
    final DiskTileCache first = cache();
    await first.write('old', bytes(10));
    final File file = folder().listSync().whereType<File>().single;
    file.setLastModifiedSync(now.subtract(const Duration(days: 31)));

    expect(await first.read('old'), isNull);
    expect(file.existsSync(), isFalse);
  });

  test('on opening, the oldest entries are removed until the folder fits', () async {
    final DiskTileCache first = cache();
    folder().createSync(recursive: true);
    for (int i = 0; i < 4; i++) {
      final Set<String> before = {for (final f in folder().listSync()) f.path};
      await first.write('tile $i', bytes(400));
      // Date each file i hours after the first, so tile 0 is the oldest.
      folder()
          .listSync()
          .whereType<File>()
          .singleWhere((f) => !before.contains(f.path))
          .setLastModifiedSync(now.subtract(Duration(hours: 4 - i)));
    }

    final DiskTileCache reopened = cache(maxBytes: 1000);

    expect(await reopened.read('tile 0'), isNull);
    expect(await reopened.read('tile 1'), isNull);
    expect(await reopened.read('tile 2'), isNotNull);
    expect(await reopened.read('tile 3'), isNotNull);
  });

  test('a folder that cannot be created leaves the cache empty instead of throwing', () async {
    final File blocker = File('${root.path}/tiles')..writeAsStringSync('not a folder');
    final DiskTileCache broken = cache();

    await broken.write('key', bytes(3));
    expect(await broken.read('key'), isNull);
    expect(blocker.readAsStringSync(), 'not a folder');
  });
}
