import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_location_picker/osm_location_picker.dart';

/// Answers each request with the reply registered for its host, recording every request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  /// Host → (status code, JSON body); a missing host fails like a dropped connection.
  final Map<String, (int, Object)> replies;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    final (int, Object)? reply = replies[options.uri.host];
    if (reply == null) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    return ResponseBody.fromString(
      jsonEncode(reply.$2),
      reply.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Object _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Object;

const String _photon = 'photon.komoot.io';
const String _nominatim = 'nominatim.openstreetmap.org';
const LatLng _kl = LatLng(3.139, 101.6869);

(LocationSearchService, _FakeAdapter) _service(Map<String, (int, Object)> replies) {
  final _FakeAdapter adapter = _FakeAdapter(replies);
  return (LocationSearchService(dio: Dio()..httpClientAdapter = adapter), adapter);
}

void main() {
  group('PlaceSearchResult', () {
    test('reads a Photon feature as name over street and area', () {
      final List<dynamic> features = (_fixture('photon_sunway_pyr.json') as Map)['features'] as List;

      final PlaceSearchResult? first = PlaceSearchResult.fromPhoton(features.first as Map<String, dynamic>);

      expect(first?.title, 'Sunway Pyramid');
      expect(
        first?.subtitle,
        '3 Jalan PJS 11/15, Sunway City, Subang Jaya City Council, Petaling, Selangor, 47500, Malaysia',
      );
      expect(first?.address, startsWith('Sunway Pyramid, 3 Jalan PJS 11/15,'));
    });

    test('uses the street address as the title of a place with no name', () {
      final PlaceSearchResult? house = PlaceSearchResult.fromPhoton({
        'geometry': {
          'coordinates': [111.85, 2.31],
        },
        'properties': {'housenumber': '12', 'street': 'Lorong Deshon 18A', 'city': 'Sibu', 'country': 'Malaysia'},
      });

      expect(house?.title, '12 Lorong Deshon 18A');
      expect(house?.subtitle, 'Sibu, Malaysia');
      expect(house?.latLng, const LatLng(2.31, 111.85));
    });

    test('skips a Photon feature without coordinates', () {
      expect(
        PlaceSearchResult.fromPhoton({
          'properties': {'name': 'Nowhere'},
        }),
        isNull,
      );
    });

    test('reads a Nominatim result as name over the rest of the display name', () {
      final PlaceSearchResult? mall = PlaceSearchResult.fromNominatim(
        (_fixture('nominatim_mid_valley.json') as List).first as Map<String, dynamic>,
      );

      expect(mall?.title, 'Mid Valley Megamall');
      expect(mall?.subtitle, startsWith('Mid Valley City, Lingkaran Syed Putra'));
      expect(mall?.subtitle, endsWith('Malaysia'));
    });
  });

  group('LocationSearchService', () {
    test('suggests from Photon, biased to the map centre, in English', () async {
      final (service, adapter) = _service({_photon: (200, _fixture('photon_sunway_pyr.json'))});

      final List<PlaceSearchResult> results = await service.suggest('sunway pyr', near: _kl);

      expect(results.first.title, 'Sunway Pyramid');
      expect(adapter.requests.single.queryParameters, containsPair('lat', '3.139'));
      expect(adapter.requests.single.queryParameters, containsPair('lon', '101.6869'));
      expect(adapter.requests.single.queryParameters, containsPair('lang', 'en'));
    });

    test('drops repeated places and caps the list', () async {
      final Map<String, dynamic> photon = _fixture('photon_sunway_pyr.json') as Map<String, dynamic>;
      final List<dynamic> doubled = [...photon['features'] as List, ...photon['features'] as List];
      final LocationSearchService service = LocationSearchService(
        limit: 3,
        dio:
            Dio()
              ..httpClientAdapter = _FakeAdapter({
                _photon: (200, {'features': doubled}),
              }),
      );

      final List<PlaceSearchResult> results = await service.suggest('sunway pyr');

      expect(results, hasLength(3));
      expect(results.map((r) => r.address).toSet(), hasLength(3));
    });

    test('does not call any service for a one-letter suggestion', () async {
      final (service, adapter) = _service({_photon: (200, _fixture('photon_sunway_pyr.json'))});

      expect(await service.suggest(' s '), isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('never falls back to Nominatim while typing, and reports Photon being down', () async {
      final (service, adapter) = _service({_nominatim: (200, _fixture('nominatim_mid_valley.json'))});

      await expectLater(service.suggest('mid valley'), throwsA(isA<LocationSearchException>()));
      expect(adapter.requests.map((u) => u.host), [_photon]);
    });

    test('on submit, falls back to Nominatim when Photon finds nothing', () async {
      final (service, adapter) = _service({
        _photon: (200, {'features': <Object>[]}),
        _nominatim: (200, _fixture('nominatim_mid_valley.json')),
      });

      final List<PlaceSearchResult> results = await service.search('mid valley megamall', near: _kl);

      expect(results.first.title, 'Mid Valley Megamall');
      expect(adapter.requests.map((u) => u.host), [_photon, _nominatim]);
      expect(adapter.requests.last.queryParameters['viewbox'], '100.6869,4.1390,102.6869,2.1390');
    });

    test('on submit, falls back to Nominatim when Photon is down', () async {
      final (service, _) = _service({_nominatim: (200, _fixture('nominatim_mid_valley.json'))});

      expect(await service.search('mid valley megamall'), isNotEmpty);
    });

    test('on submit, fails only when both services are down', () async {
      final (service, _) = _service({});

      await expectLater(service.search('mid valley megamall'), throwsA(isA<LocationSearchException>()));
    });

    test('on submit, an empty answer from both is no results, not a failure', () async {
      final (service, _) = _service({
        _photon: (200, {'features': <Object>[]}),
        _nominatim: (200, <Object>[]),
      });

      expect(await service.search('zzqx'), isEmpty);
    });
  });
}
