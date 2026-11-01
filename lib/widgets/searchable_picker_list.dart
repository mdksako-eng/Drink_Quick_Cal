// widgets/searchable_picker_list.dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/i18n.dart';

/// A short, searchable list of things to pick from.
///
/// WHY THIS EXISTS. Every "choose an existing …" dialog in this app listed ALL of
/// them in a fixed-height box with no way to narrow it down. That is fine with ten
/// accounts and unusable with three hundred: the operator scrolls a small window
/// looking for a name they already know, and gives up by typing a walk-in instead —
/// which is exactly how a tab ends up with no account behind it.
///
/// The fix is the same everywhere, so it lives here once:
///   * a search box that filters as you type,
///   * the matching rule supplied by the caller ([matches]), so a customer can be
///     found by name, number or phone while a container holder is matched by name
///     and number only — and the rule stays a pure, testable function,
///   * a plain "nothing matches" line instead of an empty box.
///
/// [maxHeight] bounds the list inside a dialog. Leave it null when the parent
/// already scrolls (a screen or a tab) so there is ONE scroll, not two nested ones.
class SearchablePickerList<T> extends StatefulWidget {
  const SearchablePickerList({
    super.key,
    required this.items,
    required this.matches,
    required this.itemBuilder,
    this.hintText,
    this.maxHeight,
    this.autofocusSearch = false,
  });

  final List<T> items;

  /// Whether [item] matches the typed [query]. Pure, so the rule can be unit tested
  /// without pumping this widget.
  final bool Function(T item, String query) matches;

  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Defaults to a generic "search by name or number".
  final String? hintText;

  /// Null → the list sizes to its content and the parent scrolls it.
  final double? maxHeight;

  final bool autofocusSearch;

  @override
  State<SearchablePickerList<T>> createState() => _SearchablePickerListState<T>();
}

class _SearchablePickerListState<T> extends State<SearchablePickerList<T>> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final found = query.isEmpty
        ? widget.items
        : widget.items.where((item) => widget.matches(item, query)).toList();

    final list = found.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              t('pickNoMatch'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: widget.maxHeight == null
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: found.length,
            itemBuilder: (context, index) =>
                widget.itemBuilder(context, found[index]),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocusSearch,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: widget.hintText ?? t('pickSearchHint'),
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: OutlineInputBorder(borderRadius: AppRadius.mediumAll),
          ),
        ),
        const SizedBox(height: 6),
        if (widget.maxHeight == null)
          list
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: list,
          ),
      ],
    );
  }
}
