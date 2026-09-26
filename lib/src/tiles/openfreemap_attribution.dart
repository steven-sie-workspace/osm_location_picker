import 'package:flutter/material.dart';

/// The data credit OpenFreeMap tiles must show, as a small translucent pill to lay over the map.
///
/// Place it outside any colour filter applied to the map so it keeps its own colours. It wraps
/// onto a second line when the width it is given is too narrow for one.
class OpenFreeMapAttribution extends StatelessWidget {
  /// Creates the credit pill.
  const OpenFreeMapAttribution({super.key, required this.backgroundColor, required this.textColor});

  /// The credit text, as short as the OpenStreetMap, OpenMapTiles and OpenFreeMap licences allow.
  static const String text = '© OpenStreetMap · OpenMapTiles · OpenFreeMap';

  /// The pill's colour; drawn at 85% opacity so the map shows through.
  final Color backgroundColor;

  /// The credit's text colour; drawn at 60% opacity so it stays unobtrusive.
  final Color textColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: backgroundColor.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        text,
        maxLines: 2,
        style: TextStyle(fontSize: 10, height: 1.2, color: textColor.withValues(alpha: 0.6)),
      ),
    ),
  );
}
