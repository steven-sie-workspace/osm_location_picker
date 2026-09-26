import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/location_search_service.dart';
import '../../../utils/place_search_result.dart';
import '../../location_picker_strings.dart';
import '../../location_picker_theme.dart';

/// The search field and its live suggestions, shared by the bottom sheet (mobile) and dialog (wide screens).
///
/// Typing asks [LocationSearchService.suggest] after a short pause; submitting asks
/// [LocationSearchService.search], which also falls back to Nominatim. Only the latest query's
/// results are shown: an older request still in flight is cancelled.
class LocationSearchPanel extends StatefulWidget {
  /// Creates the panel.
  const LocationSearchPanel({
    super.key,
    required this.theme,
    required this.strings,
    required this.onSelected,
    this.near,
    this.scrollController,
    this.searchService,
  });

  /// Colours for the field and results.
  final LocationPickerTheme theme;

  /// Hint, empty and failure texts.
  final LocationPickerStrings strings;

  /// Called with the place the user taps.
  final ValueChanged<PlaceSearchResult> onSelected;

  /// Where results are ranked around, usually the map centre.
  final LatLng? near;

  /// The results list's scroll controller, e.g. from a [DraggableScrollableSheet].
  final ScrollController? scrollController;

  /// The search backend; a default [LocationSearchService] when `null`.
  final LocationSearchService? searchService;

  @override
  State<LocationSearchPanel> createState() => _LocationSearchPanelState();
}

enum _Status { idle, loading, done, failed }

class _LocationSearchPanelState extends State<LocationSearchPanel> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  late final LocationSearchService _service = widget.searchService ?? LocationSearchService();
  Timer? _timer;
  CancelToken? _inFlight;
  List<PlaceSearchResult> _results = const [];
  _Status _status = _Status.idle;

  /// Whether the last request was a submit, so a retry repeats the same kind of search.
  bool _lastWasSubmit = false;

  @override
  void dispose() {
    _timer?.cancel();
    _inFlight?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _timer?.cancel();
    if (query.trim().length < 2) {
      _inFlight?.cancel();
      setState(() {
        _results = const [];
        _status = _Status.idle;
      });
      return;
    }
    setState(() {}); // show the clear button
    _timer = Timer(_debounce, () => _run(query, submit: false));
  }

  void _onSubmitted(String query) {
    _timer?.cancel();
    if (query.trim().isNotEmpty) _run(query, submit: true);
  }

  Future<void> _run(String query, {required bool submit}) async {
    _inFlight?.cancel();
    final CancelToken token = CancelToken();
    _inFlight = token;
    _lastWasSubmit = submit;
    setState(() => _status = _Status.loading);

    try {
      final List<PlaceSearchResult> results =
          submit
              ? await _service.search(query, near: widget.near, cancelToken: token)
              : await _service.suggest(query, near: widget.near, cancelToken: token);
      if (!mounted || token != _inFlight) return;
      setState(() {
        _results = results;
        _status = _Status.done;
      });
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return;
      _fail(token);
    } on LocationSearchException {
      _fail(token);
    }
  }

  void _fail(CancelToken token) {
    if (!mounted || token != _inFlight) return;
    setState(() {
      _results = const [];
      _status = _Status.failed;
    });
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = widget.theme.textDarkColor;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: widget.strings.searchHint,
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: widget.theme.primaryColor),
              suffixIcon:
                  _controller.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        icon: Icon(Icons.clear, color: textColor.withValues(alpha: 0.6)),
                        onPressed: _clear,
                      ),
              filled: true,
              fillColor: isDark ? const Color(0xff121212) : const Color(0xfff5f5f5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 3,
          child:
              _status == _Status.loading
                  ? LinearProgressIndicator(
                    color: widget.theme.primaryColor,
                    backgroundColor: widget.theme.primaryColor.withValues(alpha: 0.2),
                  )
                  : null,
        ),
        Expanded(child: _buildBody(isDark, textColor)),
      ],
    );
  }

  Widget _buildBody(bool isDark, Color textColor) {
    if (_results.isNotEmpty) {
      return ListView.separated(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _results.length,
        separatorBuilder:
            (context, index) => Divider(height: 1, indent: 64, color: isDark ? Colors.grey[900] : Colors.grey[200]),
        itemBuilder: (context, index) {
          final PlaceSearchResult item = _results[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.theme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_rounded, color: widget.theme.primaryColor),
            ),
            title: Text(item.title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle:
                item.subtitle.isEmpty
                    ? null
                    : Text(item.subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13)),
            onTap: () => widget.onSelected(item),
          );
        },
      );
    }

    final String message = switch (_status) {
      _Status.failed => widget.strings.searchFailed,
      _Status.done => widget.strings.noResults,
      _Status.idle || _Status.loading => '',
    };
    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        if (message.isNotEmpty)
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 16),
          ),
        if (_status == _Status.failed) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _run(_controller.text, submit: _lastWasSubmit),
              icon: Icon(Icons.refresh, color: widget.theme.primaryColor),
              label: Text(widget.strings.retry, style: TextStyle(color: widget.theme.primaryColor)),
            ),
          ),
        ],
      ],
    );
  }
}
