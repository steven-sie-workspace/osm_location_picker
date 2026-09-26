import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osm_location_picker/osm_location_picker.dart';
import 'package:osm_location_picker/src/presentation/view/widgets/location_picker_error_widget.dart';
import 'package:osm_location_picker/src/utils/location_picker_failure.dart';

const LocationPickerStrings _chinese = LocationPickerStrings(
  title: '选择位置',
  fetchingLocation: '正在获取位置…',
  locationFetchFailed: '获取位置失败',
  unknownLocation: '未知位置',
  confirmLocation: '确认位置',
  currentLocation: '当前位置',
  noInternet: '网络连接失败，请稍后再试。',
  serviceDisabled: '定位服务已关闭',
  permissionDenied: '未获得定位权限',
  permissionPermanentlyDenied: '定位权限已关闭',
  searchHint: '搜索地点或地址',
  noResults: '未找到结果',
  retry: '重试',
  noInternetTitle: '无网络连接',
  errorTitle: '出了点问题',
);

Future<void> _pump(WidgetTester tester, Exception error) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: LocationPickerErrorWidget(theme: const LocationPickerTheme(), strings: _chinese, message: error),
    ),
  ),
);

void main() {
  testWidgets('an offline failure shows the offline heading, whatever language its message is in', (tester) async {
    await _pump(tester, const OfflineFailure('网络连接失败，请稍后再试。'));

    expect(find.text('无网络连接'), findsOneWidget);
    expect(find.text('出了点问题'), findsNothing);
  });

  testWidgets('any other failure shows the general heading', (tester) async {
    await _pump(tester, const GpsFailure('获取位置失败'));

    expect(find.text('出了点问题'), findsOneWidget);
  });

  test('the built-in strings are English', () {
    expect(LocationPickerStrings.en().noInternetTitle, 'No internet connection');
    expect(LocationPickerStrings.en().errorTitle, 'Something went wrong');
  });
}
