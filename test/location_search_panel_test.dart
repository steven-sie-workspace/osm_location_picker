import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_location_picker/osm_location_picker.dart';
import 'package:osm_location_picker/src/presentation/view/widgets/location_search_panel.dart';

/// Answers from [answers] by query; a query with no answer waits on its completer.
class _FakeSearch extends LocationSearchService {
  final Map<String, Completer<List<PlaceSearchResult>>> pending = {};
  final List<String> suggested = [];
  final List<String> submitted = [];
  Object? failWith;

  Future<List<PlaceSearchResult>> _answer(String query, CancelToken? token) {
    if (failWith != null) return Future.error(failWith!);
    final Completer<List<PlaceSearchResult>> completer = pending.putIfAbsent(query, Completer.new);
    token?.whenCancel.then((error) {
      if (!completer.isCompleted) completer.completeError(error);
    });
    return completer.future;
  }

  @override
  Future<List<PlaceSearchResult>> suggest(String query, {LatLng? near, CancelToken? cancelToken}) {
    suggested.add(query);
    return _answer(query, cancelToken);
  }

  @override
  Future<List<PlaceSearchResult>> search(String query, {LatLng? near, CancelToken? cancelToken}) {
    submitted.add(query);
    return _answer(query, cancelToken);
  }
}

PlaceSearchResult _place(String title) =>
    PlaceSearchResult(title: title, subtitle: 'Kuala Lumpur, Malaysia', latLng: const LatLng(3.1, 101.6));

void main() {
  late _FakeSearch search;
  late List<PlaceSearchResult> picked;

  Future<void> pumpPanel(WidgetTester tester) async {
    search = _FakeSearch();
    picked = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationSearchPanel(
            theme: const LocationPickerTheme(),
            strings: LocationPickerStrings.en(),
            searchService: search,
            onSelected: picked.add,
          ),
        ),
      ),
    );
  }

  testWidgets('suggests after a pause in typing, not on every keystroke', (WidgetTester tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'kl');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'klcc');
    await tester.pump(const Duration(milliseconds: 400));

    expect(search.suggested, ['klcc']);
    search.pending['klcc']!.complete([_place('KLCC')]);
    await tester.pump();

    expect(find.text('KLCC'), findsOneWidget);
    expect(find.text('Kuala Lumpur, Malaysia'), findsOneWidget);
  });

  testWidgets('tapping a suggestion hands back the place', (WidgetTester tester) async {
    await pumpPanel(tester);
    await tester.enterText(find.byType(TextField), 'klcc');
    await tester.pump(const Duration(milliseconds: 400));
    search.pending['klcc']!.complete([_place('KLCC')]);
    await tester.pump();

    await tester.tap(find.text('KLCC'));

    expect(picked.single.address, 'KLCC, Kuala Lumpur, Malaysia');
  });

  testWidgets('a slow older answer never replaces a newer one', (WidgetTester tester) async {
    await pumpPanel(tester);
    await tester.enterText(find.byType(TextField), 'sun');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'sunway');
    await tester.pump(const Duration(milliseconds: 400));

    search.pending['sunway']!.complete([_place('Sunway Pyramid')]);
    await tester.pump();
    expect(search.pending['sun']!.isCompleted, isTrue, reason: 'the older request was cancelled');

    expect(find.text('Sunway Pyramid'), findsOneWidget);
  });

  testWidgets('submitting runs the full search at once', (WidgetTester tester) async {
    await pumpPanel(tester);
    await tester.enterText(find.byType(TextField), 'mid valley');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(search.submitted, ['mid valley']);
    await tester.pump(const Duration(milliseconds: 400));
    expect(search.suggested, isEmpty, reason: 'the pending suggestion was dropped');
  });

  testWidgets('says when nothing matches', (WidgetTester tester) async {
    await pumpPanel(tester);
    await tester.enterText(find.byType(TextField), 'zzqx');
    await tester.pump(const Duration(milliseconds: 400));
    search.pending['zzqx']!.complete([]);
    await tester.pump();

    expect(find.text(LocationPickerStrings.en().noResults), findsOneWidget);
  });

  testWidgets('a failed search says so and can be retried', (WidgetTester tester) async {
    await pumpPanel(tester);
    search.failWith = LocationSearchException('offline');
    await tester.enterText(find.byType(TextField), 'klcc');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text(LocationPickerStrings.en().searchFailed), findsOneWidget);
    expect(find.text(LocationPickerStrings.en().noResults), findsNothing);

    search.failWith = null;
    await tester.tap(find.text(LocationPickerStrings.en().retry));
    await tester.pump();
    search.pending['klcc']!.complete([_place('KLCC')]);
    await tester.pump();

    expect(search.suggested, ['klcc', 'klcc']);
    expect(find.text('KLCC'), findsOneWidget);
  });
}
