import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/place_search_result.dart';
import '../../location_picker_strings.dart';
import '../../location_picker_theme.dart';
import 'location_search_panel.dart';

/// Address search in a draggable bottom sheet, for narrow (phone) screens.
class LocationSearchBottomSheet extends StatelessWidget {
  final LocationPickerTheme theme;
  final LocationPickerStrings strings;

  /// Where results are ranked around, usually the map centre.
  final LatLng? near;
  final ValueChanged<PlaceSearchResult> onSelected;

  const LocationSearchBottomSheet({
    super.key,
    required this.theme,
    required this.strings,
    required this.onSelected,
    this.near,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      // Keep the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Drag Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LocationSearchPanel(
                    theme: theme,
                    strings: strings,
                    near: near,
                    scrollController: scrollController,
                    onSelected: onSelected,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
