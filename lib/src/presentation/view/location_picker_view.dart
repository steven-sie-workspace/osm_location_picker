import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../location_picker_theme.dart';
import '../location_picker_strings.dart';
import '../view_model/cubit/location_picker_cubit.dart';
import 'widgets/location_picker_body.dart';

/// Full-screen location picker backed by OpenStreetMap.
///
/// Push this widget as a route and `await` the result. Returns a
/// [LocationModel] when the user confirms a location, or `null` when
/// dismissed.
///
/// ```dart
/// final result = await Navigator.of(context).push<LocationModel>(
///   MaterialPageRoute(builder: (_) => const LocationPickerView()),
/// );
/// ```
class LocationPickerView extends StatelessWidget {
  /// Pre-selected coordinates shown on the map when the picker opens.
  ///
  /// When `null` the picker tries to acquire the device's current GPS position.
  final LatLng? initialLatLng;

  /// Pre-selected address label shown in the header.
  final String? initialAddress;

  /// Visual theme. Defaults to [LocationPickerTheme.of] (derived from
  /// the ambient [ThemeData]) when not provided.
  final LocationPickerTheme? theme;

  /// Where the map is centred while the device location is being fetched, and when it can't be found.
  ///
  /// Defaults to [LocationPickerCubit.defaultFallbackLatLng].
  final LatLng fallbackLatLng;

  /// Returns the device position, replacing the built-in `geolocator` lookup.
  ///
  /// Use it where `geolocator` has no implementation for the platform, or to share the app's own
  /// location service. Throw to report failure; the picker then stays at [fallbackLatLng] for
  /// manual picking. When `null`, `geolocator` is used (on HarmonyOS, add an OpenHarmony
  /// implementation of it such as `geolocator_ohos` to the app).
  final Future<LatLng> Function()? currentLocation;

  /// Countries search results are limited to, as ISO 3166-1 alpha-2 codes (e.g. `['my']`);
  /// empty (the default) searches worldwide.
  final List<String> countryCodes;

  /// UI text overrides. Defaults to [LocationPickerStrings.of] (locale-aware)
  /// when not provided.
  final LocationPickerStrings? strings;

  /// Creates a [LocationPickerView].
  const LocationPickerView({
    super.key,
    this.initialLatLng,
    this.initialAddress,
    this.theme,
    this.strings,
    this.fallbackLatLng = LocationPickerCubit.defaultFallbackLatLng,
    this.currentLocation,
    this.countryCodes = const [],
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? LocationPickerTheme.of(context);
    final activeStrings = strings ?? LocationPickerStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) {
        final cubit = LocationPickerCubit(
          initialLatLng: initialLatLng,
          initialAddress: initialAddress,
          strings: activeStrings,
          fallbackLatLng: fallbackLatLng,
          currentLocationProvider: currentLocation,
        );
        final address = initialAddress;
        if (initialLatLng == null) {
          cubit.getCurrentLocation();
        } else if (address == null || address.isEmpty) {
          cubit.getAddressFromLatLng(initialLatLng!);
        }
        return cubit;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: activeTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
            titleSpacing: 0,
            title: Text(
              activeStrings.title,
              style: TextStyle(
                color: activeTheme.appbarForegroundColor ?? activeTheme.textDarkColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: false,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: activeTheme.appbarForegroundColor ?? activeTheme.textDarkColor,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: LocationPickerBody(theme: activeTheme, strings: activeStrings, countryCodes: countryCodes),
        ),
      ),
    );
  }
}
