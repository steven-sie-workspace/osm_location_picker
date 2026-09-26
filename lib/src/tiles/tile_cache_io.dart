import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'tile_cache.dart';

/// Phones and desktops: a [DiskTileCache] in the app's cache directory.
TileCache createDefaultTileCache() => DiskTileCache(_defaultDirectory());

/// The app cache directory from `path_provider`, or the system temp directory where
/// `path_provider` has no implementation for the platform.
Future<Directory> _defaultDirectory() async {
  Directory base;
  try {
    base = await getApplicationCacheDirectory();
  } catch (_) {
    base = Directory.systemTemp;
  }
  return Directory('${base.path}${Platform.pathSeparator}osm_location_picker_tiles');
}

/// A folder of cached files, one per key, trimmed to [maxBytes] and [maxAge].
///
/// Trimming runs once, the first time the cache is used, deleting expired files and then the
/// least recently written ones until the folder fits [maxBytes]. Every failure (no folder, disk
/// full, a file removed mid-read) makes the cache behave as empty rather than throw.
class DiskTileCache implements TileCache {
  /// Creates a cache in [directory], which is created when missing.
  DiskTileCache(
    Future<Directory> directory, {
    this.maxBytes = 50 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _ready = directory.then(_open).catchError((Object error) {
      debugPrint('osm_location_picker: tile cache disabled ($error)');
      return null;
    });
  }

  /// The most bytes kept on disk.
  final int maxBytes;

  /// How long a file is used after it was written.
  final Duration maxAge;

  final DateTime Function() _now;
  late final Future<Directory?> _ready;

  Future<Directory?> _open(Directory directory) async {
    await directory.create(recursive: true);
    await _trim(directory);
    return directory;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final Directory? directory = await _ready;
    if (directory == null) return null;
    final File file = _file(directory, key);
    try {
      if (_isExpired(await file.lastModified())) {
        await file.delete();
        return null;
      }
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final Directory? directory = await _ready;
    if (directory == null) return;
    final File file = _file(directory, key);
    // Write beside the target and rename, so a reader never sees half a file.
    final File partial = File('${file.path}.${_now().microsecondsSinceEpoch}.part');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
    } on FileSystemException {
      try {
        await partial.delete();
      } on FileSystemException {
        // Nothing was written.
      }
    }
  }

  bool _isExpired(DateTime written) => _now().difference(written) > maxAge;

  Future<void> _trim(Directory directory) async {
    final List<(File, FileStat)> kept = [];
    await for (final FileSystemEntity entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final FileStat stat = await entity.stat();
      if (entity.path.endsWith('.part') || _isExpired(stat.modified)) {
        await _delete(entity);
      } else {
        kept.add((entity, stat));
      }
    }

    int total = kept.fold(0, (int sum, (File, FileStat) entry) => sum + entry.$2.size);
    if (total <= maxBytes) return;
    kept.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final (File file, FileStat stat) in kept) {
      if (total <= maxBytes) break;
      await _delete(file);
      total -= stat.size;
    }
  }

  static Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// A file name that is stable across runs: the 64-bit FNV-1a hash of [key].
  static File _file(Directory directory, String key) {
    int hash = 0xcbf29ce484222325;
    for (final int byte in utf8.encode(key)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    final String hex =
        (hash >>> 32).toRadixString(16).padLeft(8, '0') + (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return File('${directory.path}${Platform.pathSeparator}$hex.bin');
  }
}
