## 1.0.9

- Map tiles are cached on disk (app cache directory, 30 days, 50 MB) and reused on later runs and offline, together with the tile URL template. Web uses the browser cache. Falls back to the system temp directory where `path_provider` has no implementation.
- New `LocationPickerView.countryCodes`: limit search results to given countries (Photon filters one country server-side, several client-side; Nominatim gets `countrycodes`).
- New `LocationPickerView.currentLocation`: supply the device position instead of `geolocator`, e.g. on HarmonyOS; `geolocator_ohos` also plugs into `geolocator` directly.
- Removed `internet_connection_checker_plus`: "offline" is now decided from the address lookup's own connection error, instead of pinging third-party hosts before every lookup.
- The error screen shows its Try again button on every platform (was hidden on Android/iOS, which only had pull to refresh).

## 1.0.8

- Breaking: dropped Arabic. `LocationPickerStrings.ar()` is removed and `LocationPickerStrings.of` always returns English; pass your own `LocationPickerStrings` for other languages.
- The full-screen error's headings and retry button come from `LocationPickerStrings` (new `noInternetTitle` and `errorTitle`, plus the existing `retry`), instead of hard-coded English/Arabic text chosen by locale.
- The offline error is recognised by its `OfflineFailure` type, so it works whatever language the message is in (it looked for Arabic or English words).
- The example app no longer lists Arabic as a supported locale.

## 1.0.7

- Search suggests as you type from Photon (free, no key), which matches partial words ("sunway pyr", "lorong desh") that Nominatim could not, ranks places near the map centre first, and drops duplicate entries.
- Pressing search falls back to Nominatim (biased to the map centre) when Photon finds nothing or is down. Nominatim is no longer called per keystroke, which its usage policy forbids.
- Results show the place name with its area underneath; the picked address is the full line.
- A failed search says so with a Try again button, instead of "No results found". New `LocationPickerStrings.searchFailed` and `retry` (default to English).
- Only the latest query's results are shown: an older request still in flight is cancelled.
- Requests identify the package with a proper User-Agent, as the OSM services require.
- The search opens as a bottom sheet on phone-width screens on any OS (HarmonyOS included) and as a dialog on wider ones; it was Android/iOS only.
- Breaking: `NominatimService` / `NominatimSearchResult` are replaced by `LocationSearchService` / `PlaceSearchResult`.

## 1.0.6

- Map labels show English (or Latin-script) names only; a place with neither is left unlabelled instead of showing its local script.
- The map data credit is a small translucent pill at the bottom right, under the Confirm button (was a full-width `flutter_map` strip), and it keeps its colours in dark mode.
- New `LocationPickerView.fallbackLatLng`: where the map is centred until the device location is known (defaults to the previous Baghdad centre).

## 1.0.5

- Fix: the map was covered by "API KEY REQUIRED" because CARTO basemaps now need an API key. The map now uses OpenFreeMap vector tiles in the same Positron style, painted on the device by `vector_tile_renderer` (pure Dart, so it also runs on HarmonyOS), sharp up to zoom 18.
- Added the OpenFreeMap / OpenMapTiles / OpenStreetMap attribution on the map.

## 1.0.4

- Fix: added macOS App Sandbox location entitlements and usage description keys to enable GPS location picking.
- Fix: updated GPS fetching to use a 5-second timeout and fallback to the last known position to prevent indefinite hangs.
- Fix: resolved target warnings in Xcode/CocoaPods builds regarding dependency analysis and deployment target versions.
- Updated documentation and README with troubleshooting steps for macOS application run behaviors.

## 1.0.3

- Fix: added required Android permissions (INTERNET, ACCESS_NETWORK_STATE, location) for release builds.
- Fix: network connectivity check now works in Android release builds (added network security config).
- Fix: SVG icon assets not loading after package rename (wrong `package:` reference).
- Fix: error message no longer shown as search bar hint text on offline/failure state.
- Added network and location permissions for iOS, macOS, and documentation for all platforms.
- Updated README with comprehensive platform-specific setup instructions.

## 1.0.2

- Published to pub.dev.
- Package renamed to `osm_location_picker`.
- Improved error widget: pull-to-refresh on mobile, retry button on web & desktop.
- Replaced `dart:io` Platform checks with `defaultTargetPlatform` for full web support.
- Added dartdoc to all public APIs.
- Switched license to MIT.

## 1.0.1+1

- Initial versioned release.
