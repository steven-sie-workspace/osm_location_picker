import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart';

import '../../../tiles/openfreemap_attribution.dart';
import '../../../tiles/openfreemap_tile_provider.dart';
import '../../../utils/location_search_service.dart';
import '../../../utils/place_search_result.dart';
import '../../view_model/cubit/base_state.dart';
import '../../view_model/cubit/location_picker_cubit.dart';
import '../../view_model/cubit/location_picker_states.dart';
import '../../../models/location_model.dart';
import '../../location_picker_theme.dart';
import '../../location_picker_strings.dart';
import 'location_picker_error_widget.dart';
import 'map_address_header.dart';
import 'map_center_marker.dart';
import 'my_location_button.dart';
import 'map_confirm_button.dart';
import 'location_search_bottom_sheet.dart';
import 'location_search_dialog.dart';

class LocationPickerBody extends StatefulWidget {
  final LocationPickerTheme theme;
  final LocationPickerStrings strings;

  /// Countries search results are limited to; empty searches worldwide.
  final List<String> countryCodes;

  const LocationPickerBody({
    super.key,
    required this.theme,
    required this.strings,
    this.countryCodes = const [],
  });

  @override
  State<LocationPickerBody> createState() => _LocationPickerBodyState();
}

class _LocationPickerBodyState extends State<LocationPickerBody> with TickerProviderStateMixin {
  late final MapController _mapController;

  /// Created once so tiles stay cached across rebuilds; the [TileLayer] disposes it.
  late final OpenFreeMapTileProvider _tileProvider;

  /// Shared by every search opened from this picker.
  late final LocationSearchService _searchService = LocationSearchService(countryCodes: widget.countryCodes);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tileProvider = OpenFreeMapTileProvider();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    try {
      final camera = _mapController.camera;

      final controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

      final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
      final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
      final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

      final animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

      controller.addListener(() {
        if (mounted) {
          _mapController.move(
            LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
            zoomTween.evaluate(animation),
          );
        }
      });

      controller.forward().then((_) {
        controller.dispose();
      });
    } catch (_) {
      // Map is not ready yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<LocationPickerCubit, LocationPickerStates>(
      buildWhen:
          (prev, curr) =>
              prev.addressData.state != curr.addressData.state ||
              prev.addressData.data != curr.addressData.data ||
              prev.addressData.exception != curr.addressData.exception ||
              prev.position != curr.position ||
              prev.isMoving != curr.isMoving,
      listenWhen:
          (prev, curr) =>
              prev.addressData.state != curr.addressData.state ||
              prev.position != curr.position ||
              prev.shouldMoveToPosition != curr.shouldMoveToPosition,
      listener: (context, state) async {
        final cubit = context.read<LocationPickerCubit>();

        if (state.shouldMoveToPosition && state.position != null) {
          _animatedMapMove(state.position!, 16.0);
          cubit.updateShouldMoveToPosition(false);
        }
      },
      builder: (context, state) {
        final cubit = context.read<LocationPickerCubit>();
        final hasPosition = state.position != null;

        // The map is always rendered as the base layer, centering on the current resolved position or current center fallback.
        final initialMapCenter = state.position ?? state.currentCenter ?? cubit.fallbackLatLng;

        final addressText =
            (state.addressData.state == StatusState.loading ||
                    state.isMoving ||
                    state.addressData.state == StatusState.initial)
                ? widget.strings.fetchingLocation
                : (state.addressData.state == StatusState.failure)
                ? widget.strings.searchHint
                : (state.addressData.data != null && state.addressData.data!.isNotEmpty)
                ? state.addressData.data!
                : widget.strings.unknownLocation;

        return Stack(
          children: [
            // Map (Always visible as the base layer)
            ColorFiltered(
              colorFilter:
                  isDark
                      ? const ColorFilter.matrix([
                        -0.2126,
                        -0.7152,
                        -0.0722,
                        0,
                        255,
                        -0.2126,
                        -0.7152,
                        -0.0722,
                        0,
                        255,
                        -0.2126,
                        -0.7152,
                        -0.0722,
                        0,
                        255,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                      : const ColorFilter.matrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialMapCenter,
                  initialZoom: 16.0,
                  maxZoom: 18.0,
                  onMapEvent: (event) {
                    if (event.source == MapEventSource.mapController) return;
                    if (event is MapEventMove) {
                      cubit.onCameraMove(event.camera.center);
                    } else if (event is MapEventMoveEnd) {
                      cubit.onCameraIdle();
                    }
                  },
                ),
                children: [
                  TileLayer(tileProvider: _tileProvider, userAgentPackageName: 'com.location_picker.app'),
                ],
              ),
            ),

            // Map data credit, bottom-right under the Confirm button (which starts 30 px up), outside the
            // dark-mode colour filter
            Positioned(
              left: 20,
              right: 20,
              bottom: 8,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OpenFreeMapAttribution(
                  backgroundColor: widget.theme.cardColor,
                  textColor: widget.theme.textDarkColor,
                ),
              ),
            ),

            // My Location Button
            if (hasPosition) MyLocationButton(theme: widget.theme, onTap: () => cubit.getCurrentLocation()),

            // Center Pin Marker (Only active when position is available)
            if (hasPosition) MapCenterMarker(isMoving: state.isMoving, theme: widget.theme),

            // Address Header (Always visible)
            MapAddressHeader(
              addressText: addressText,
              theme: widget.theme,
              onTap: () {
                void onSelected(BuildContext sheetContext, PlaceSearchResult place) {
                  cubit.selectLocation(place.latLng, place.address);
                  Navigator.pop(sheetContext);
                }

                // Bottom sheet on phone-width screens (any OS, HarmonyOS included), dialog on wider ones.
                if (MediaQuery.sizeOf(context).width < 600) {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (ctx) => LocationSearchBottomSheet(
                          theme: widget.theme,
                          strings: widget.strings,
                          near: state.currentCenter,
                          searchService: _searchService,
                          onSelected: (place) => onSelected(ctx, place),
                        ),
                  );
                } else {
                  showDialog<void>(
                    context: context,
                    builder:
                        (ctx) => LocationSearchDialog(
                          theme: widget.theme,
                          strings: widget.strings,
                          near: state.currentCenter,
                          searchService: _searchService,
                          onSelected: (place) => onSelected(ctx, place),
                        ),
                  );
                }
              },
            ),

            // Confirm Button (Only active when position is available)
            if (hasPosition)
              MapConfirmButton(
                theme: widget.theme,
                title: widget.strings.confirmLocation,
                onTap: () {
                  final currentState = context.read<LocationPickerCubit>().state;
                  if (currentState.addressData.state == StatusState.loading || currentState.isMoving) {
                    return;
                  }
                  if (currentState.currentCenter != null) {
                    final resolvedAddress =
                        (currentState.addressData.data != null && currentState.addressData.data!.trim().isNotEmpty)
                            ? currentState.addressData.data!
                            : widget.strings.currentLocation;
                    Navigator.of(
                      context,
                    ).pop(LocationModel(latLng: currentState.currentCenter, address: resolvedAddress));
                  }
                },
              ),

            // Error overlay (rendered as an overlay on the map, transparent/semi-transparent background)
            if (state.addressData.state == StatusState.failure)
              Positioned.fill(
                child: ColoredBox(
                  color: isDark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
                  child: LocationPickerErrorWidget(
                    theme: widget.theme,
                    strings: widget.strings,
                    message: state.addressData.exception,
                    onDismiss: () => cubit.dismissError(),
                    onRetry: () {
                      if (hasPosition) {
                        cubit.getAddressFromLatLng(state.currentCenter ?? state.position!);
                      } else {
                        cubit.getCurrentLocation(position: state.currentCenter);
                      }
                    },
                  ),
                ),
              ),

            // Centered circular loading indicator as a non-blocking overlay on top of the map (only shown on initial load before coordinates are ready)
            if ((state.addressData.state == StatusState.loading || state.addressData.state == StatusState.initial) &&
                !hasPosition)
              Center(
                child:
                    widget.theme.loadingLottieAsset != null
                        ? Lottie.asset(widget.theme.loadingLottieAsset!, width: 80, height: 80, fit: BoxFit.contain)
                        : SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(color: widget.theme.primaryColor, strokeWidth: 3.5),
                        ),
              ),
          ],
        );
      },
    );
  }
}
