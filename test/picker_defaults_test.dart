import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_location_picker/osm_location_picker.dart';
import 'package:osm_location_picker/src/presentation/view_model/cubit/location_picker_cubit.dart';
import 'package:osm_location_picker/src/tiles/openfreemap_attribution.dart';

void main() {
  test('the map starts at the given fallback until a location is known', () {
    const LatLng kualaLumpur = LatLng(3.1390, 101.6869);
    final LocationPickerCubit cubit = LocationPickerCubit(
      strings: LocationPickerStrings.en(),
      fallbackLatLng: kualaLumpur,
    );
    addTearDown(cubit.close);

    expect(cubit.state.currentCenter, kualaLumpur);
  });

  test('map labels use English or Latin names only', () {
    final Map<String, dynamic> style =
        jsonDecode(File('assets/styles/positron.json').readAsStringSync()) as Map<String, dynamic>;
    final List<String> textFields = [
      for (final Map<String, dynamic> layer in (style['layers'] as List).cast<Map<String, dynamic>>())
        if (layer['layout'] case {'text-field': final Object field}) jsonEncode(field),
    ];

    expect(textFields, isNotEmpty);
    for (final String field in textFields) {
      expect(field, isNot(contains('nonlatin')));
      expect(field, isNot(contains('"name"]')), reason: 'plain "name" is in the local script');
      expect(field, isNot(contains('name_en')), reason: 'name_en falls back to the local script');
    }
  });

  testWidgets('the credit fits in the gap under the Confirm button', (WidgetTester tester) async {
    // A 320 dp phone minus the picker's 20 dp side margins.
    const double available = 320 - 20 - 20;

    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: available,
            height: 22, // the Confirm button starts 30 dp up; the credit sits 8 dp up
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OpenFreeMapAttribution(backgroundColor: Colors.white, textColor: Colors.black),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.text(OpenFreeMapAttribution.text), findsOneWidget);
    final Size size = tester.getSize(find.byType(OpenFreeMapAttribution));
    expect(size.width, lessThanOrEqualTo(available));
    expect(size.height, lessThanOrEqualTo(22));
  });
}
