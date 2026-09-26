import 'package:latlong2/latlong.dart';

/// One place found by a location search, shown as a two-line suggestion.
class PlaceSearchResult {
  /// The place's own name, or its street address when it has none (e.g. "Sunway Pyramid").
  final String title;

  /// Where the place is, from street up to country (e.g. "Subang Jaya, Selangor, 47500, Malaysia").
  final String subtitle;

  /// The place's coordinates.
  final LatLng latLng;

  /// Creates a [PlaceSearchResult].
  const PlaceSearchResult({required this.title, required this.subtitle, required this.latLng});

  /// The full one-line address handed back when the place is picked.
  String get address => subtitle.isEmpty ? title : '$title, $subtitle';

  /// Reads one GeoJSON feature from the [Photon](https://photon.komoot.io) API.
  ///
  /// Returns `null` when the feature has no usable coordinates.
  static PlaceSearchResult? fromPhoton(Map<String, dynamic> feature) {
    final Object? coordinates = (feature['geometry'] as Map<String, dynamic>?)?['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final num? lon = coordinates[0] as num?;
    final num? lat = coordinates[1] as num?;
    if (lat == null || lon == null) return null;

    final Map<String, dynamic> p = (feature['properties'] as Map<String, dynamic>?) ?? const {};
    String? read(String key) {
      final Object? value = p[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final String? street = _join([read('housenumber'), read('street')], ' ');
    final String? name = read('name');
    final String title = name ?? street ?? read('city') ?? read('state') ?? read('country') ?? '';
    if (title.isEmpty) return null;

    final List<String?> parts = [
      if (name != null) street,
      read('district'),
      read('locality'),
      read('city'),
      read('county'),
      read('state'),
      read('postcode'),
      read('country'),
    ];
    return PlaceSearchResult(
      title: title,
      subtitle: _join(parts, ', ', exclude: title) ?? '',
      latLng: LatLng(lat.toDouble(), lon.toDouble()),
    );
  }

  /// Reads one result from the [Nominatim](https://nominatim.org) search API (`format=jsonv2`).
  ///
  /// Returns `null` when the result has no usable coordinates.
  static PlaceSearchResult? fromNominatim(Map<String, dynamic> json) {
    final double? lat = double.tryParse('${json['lat']}');
    final double? lon = double.tryParse('${json['lon']}');
    final String displayName = (json['display_name'] as String? ?? '').trim();
    if (lat == null || lon == null || displayName.isEmpty) return null;

    final String name = (json['name'] as String? ?? '').trim();
    final List<String> parts = displayName.split(', ');
    final String title = name.isNotEmpty ? name : parts.first;
    final String subtitle = (parts.isNotEmpty && parts.first == title ? parts.skip(1) : parts).join(', ');
    return PlaceSearchResult(title: title, subtitle: subtitle, latLng: LatLng(lat, lon));
  }

  /// Joins the non-empty [parts] with [separator], dropping repeats and [exclude]; `null` when nothing is left.
  static String? _join(List<String?> parts, String separator, {String? exclude}) {
    final List<String> kept = [];
    for (final String? part in parts) {
      if (part == null || part == exclude || kept.contains(part)) continue;
      kept.add(part);
    }
    return kept.isEmpty ? null : kept.join(separator);
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceSearchResult && other.title == title && other.subtitle == subtitle && other.latLng == latLng;

  @override
  int get hashCode => Object.hash(title, subtitle, latLng);

  @override
  String toString() => 'PlaceSearchResult($address @ ${latLng.latitude},${latLng.longitude})';
}
