import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/place_search_result.dart';
import '../../location_picker_strings.dart';
import '../../location_picker_theme.dart';
import 'location_search_panel.dart';

/// Address search in a centred dialog, for wide (tablet, desktop, web) screens.
class LocationSearchDialog extends StatelessWidget {
  final LocationPickerTheme theme;
  final LocationPickerStrings strings;

  /// Where results are ranked around, usually the map centre.
  final LatLng? near;
  final ValueChanged<PlaceSearchResult> onSelected;

  const LocationSearchDialog({
    super.key,
    required this.theme,
    required this.strings,
    required this.onSelected,
    this.near,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 500,
          height: 600,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 5)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: theme.cardColor,
            child: Column(
              children: [
                // Dialog Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          strings.searchHint.replaceFirst('...', ''),
                          style: TextStyle(color: theme.textDarkColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                        icon: Icon(Icons.close, color: theme.textDarkColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LocationSearchPanel(theme: theme, strings: strings, near: near, onSelected: onSelected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
