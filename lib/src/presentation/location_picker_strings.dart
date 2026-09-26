import 'package:flutter/material.dart';

/// Localised UI strings used by [LocationPickerView].
///
/// [LocationPickerStrings.en] is the built-in (English) set; supply your own
/// translations by constructing this class directly.
class LocationPickerStrings {
  /// Title displayed in the app bar.
  final String title;

  /// Shown while the device GPS position is being acquired.
  final String fetchingLocation;

  /// Shown when fetching the GPS position fails.
  final String locationFetchFailed;

  /// Placeholder address when reverse geocoding returns nothing.
  final String unknownLocation;

  /// Label for the confirm-location action button.
  final String confirmLocation;

  /// Label for the "my location" / GPS button.
  final String currentLocation;

  /// Shown when the device has no internet connection.
  final String noInternet;

  /// Shown when the device location service is disabled.
  final String serviceDisabled;

  /// Shown when location permission has been denied.
  final String permissionDenied;

  /// Shown when location permission has been permanently denied.
  final String permissionPermanentlyDenied;

  /// Placeholder hint inside the address search field.
  final String searchHint;

  /// Shown when an address search returns no results.
  final String noResults;

  /// Shown when the address search services cannot be reached.
  final String searchFailed;

  /// Label of the button that repeats a failed search or location lookup.
  final String retry;

  /// Heading of the full-screen error shown when the device is offline.
  final String noInternetTitle;

  /// Heading of the full-screen error shown for any other failure.
  final String errorTitle;

  /// Creates a [LocationPickerStrings]; the optional fields default to English.
  const LocationPickerStrings({
    required this.title,
    required this.fetchingLocation,
    required this.locationFetchFailed,
    required this.unknownLocation,
    required this.confirmLocation,
    required this.currentLocation,
    required this.noInternet,
    required this.serviceDisabled,
    required this.permissionDenied,
    required this.permissionPermanentlyDenied,
    required this.searchHint,
    required this.noResults,
    this.searchFailed = "Couldn't search right now. Check your connection.",
    this.retry = 'Try again',
    this.noInternetTitle = 'No internet connection',
    this.errorTitle = 'Something went wrong',
  });

  /// Returns English UI strings.
  factory LocationPickerStrings.en() => const LocationPickerStrings(
    title: 'Select Location',
    fetchingLocation: 'Fetching location...',
    locationFetchFailed: 'Failed to fetch location',
    unknownLocation: 'Unknown location',
    confirmLocation: 'Confirm Location',
    currentLocation: 'Current Location',
    noInternet: 'No internet connection, please try again!',
    serviceDisabled: 'Location services are disabled',
    permissionDenied: 'Location permission denied',
    permissionPermanentlyDenied: 'Location permission permanently denied',
    searchHint: 'Search for a location...',
    noResults: 'No results found',
  );

  /// The default strings when none are passed to [LocationPickerView]: always [LocationPickerStrings.en].
  factory LocationPickerStrings.of(BuildContext context) => LocationPickerStrings.en();
}
