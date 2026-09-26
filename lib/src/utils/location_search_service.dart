import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'place_search_result.dart';

/// The User-Agent sent to the free OpenStreetMap services, which ask every app to identify itself.
const String osmUserAgent = 'osm_location_picker/1.0 (+https://github.com/steven-sie-workspace/osm_location_picker)';

/// Thrown when no search service could be reached, as opposed to a search that found nothing.
class LocationSearchException implements Exception {
  /// The underlying error.
  final Object cause;

  /// Creates a [LocationSearchException] wrapping [cause].
  const LocationSearchException(this.cause);

  @override
  String toString() => 'LocationSearchException: $cause';
}

/// Free, key-less place search over OpenStreetMap data.
///
/// - [suggest] runs as the user types, on [Photon](https://photon.komoot.io), which matches
///   partial words ("sunway pyr") and is built for autocomplete.
/// - [search] runs when the user submits: Photon first, then [Nominatim](https://nominatim.org)
///   when Photon finds nothing or is down. Nominatim only matches whole words and its usage
///   policy forbids autocomplete, so it is never called per keystroke.
///
/// Both rank places near [near] (usually the map centre) first.
class LocationSearchService {
  /// Creates the service; [dio] is injectable for tests.
  LocationSearchService({Dio? dio, this.language = 'en', this.limit = 8}) : _dio = dio ?? Dio();

  static const String _photonUrl = 'https://photon.komoot.io/api/';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';

  /// The language place names are returned in; Photon supports `en`, `de`, `fr` (else local names).
  final String language;

  /// The most results returned.
  final int limit;

  final Dio _dio;

  /// Suggestions for a partly typed [query], nearest to [near] first.
  ///
  /// Returns an empty list for queries shorter than 2 characters. Throws [LocationSearchException]
  /// when Photon cannot be reached.
  Future<List<PlaceSearchResult>> suggest(String query, {LatLng? near, CancelToken? cancelToken}) async {
    final String q = query.trim();
    if (q.length < 2) return const [];
    try {
      return await _photon(q, near, cancelToken);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw LocationSearchException(error);
    }
  }

  /// Results for a submitted [query]: Photon's, or Nominatim's when Photon has none or fails.
  ///
  /// Throws [LocationSearchException] only when both services fail.
  Future<List<PlaceSearchResult>> search(String query, {LatLng? near, CancelToken? cancelToken}) async {
    final String q = query.trim();
    if (q.isEmpty) return const [];

    Object? photonError;
    try {
      final List<PlaceSearchResult> results = await _photon(q, near, cancelToken);
      if (results.isNotEmpty) return results;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      photonError = error;
    }

    try {
      return await _nominatim(q, near, cancelToken);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      if (photonError != null) throw LocationSearchException(error);
      return const [];
    }
  }

  Future<List<PlaceSearchResult>> _photon(String q, LatLng? near, CancelToken? cancelToken) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      _photonUrl,
      queryParameters: {
        'q': q,
        'limit': limit + 4, // headroom for duplicates dropped below
        if (language.isNotEmpty) 'lang': language,
        if (near != null) ...{'lat': near.latitude, 'lon': near.longitude, 'location_bias_scale': 0.3},
      },
      options: _options,
      cancelToken: cancelToken,
    );
    final Object? features = (response.data as Map<String, dynamic>?)?['features'];
    if (features is! List) return const [];
    return _distinct(features.whereType<Map<String, dynamic>>().map(PlaceSearchResult.fromPhoton));
  }

  Future<List<PlaceSearchResult>> _nominatim(String q, LatLng? near, CancelToken? cancelToken) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      _nominatimUrl,
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'limit': limit,
        if (language.isNotEmpty) 'accept-language': language,
        // Prefer (but don't restrict to) a ~1° box around the map centre.
        if (near != null)
          'viewbox': [
            near.longitude - 1,
            near.latitude + 1,
            near.longitude + 1,
            near.latitude - 1,
          ].map((double degrees) => degrees.toStringAsFixed(4)).join(','),
      },
      options: _options,
      cancelToken: cancelToken,
    );
    final Object? list = response.data;
    if (list is! List) return const [];
    return _distinct(list.whereType<Map<String, dynamic>>().map(PlaceSearchResult.fromNominatim));
  }

  Options get _options => Options(
    headers: {'User-Agent': osmUserAgent},
    responseType: ResponseType.json,
    receiveTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 8),
  );

  /// Drops unusable and repeated results (Photon lists one place per OSM object, so "KLCC" can appear
  /// three times) and caps the list at [limit].
  List<PlaceSearchResult> _distinct(Iterable<PlaceSearchResult?> results) {
    final Set<String> seen = {};
    return [
      for (final PlaceSearchResult? result in results)
        if (result != null && seen.add(result.address.toLowerCase())) result,
    ].take(limit).toList(growable: false);
  }
}
