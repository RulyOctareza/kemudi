import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/platform_bridge.dart';
import '../theme/car_theme.dart';

/// A category chip and the query it searches; a null query means trending.
typedef FeedCategory = ({String label, String? query});

/// Search field and category chips of the YouTube menu.
class SearchHeader extends StatefulWidget {
  const SearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.categories,
    required this.activeQuery,
    required this.onSearch,
    required this.onCategory,
    required this.onClear,
    this.recentQueries = const [],
    this.voice,
  });

  /// The driver's last searches, offered as chips in front of the categories.
  final List<String> recentQueries;

  /// Speech input for the field; no mic button without it.
  final VoiceInput? voice;

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<FeedCategory> categories;

  /// Query the grid shows, to highlight the matching chip.
  final String activeQuery;
  final ValueChanged<String> onSearch;
  final ValueChanged<FeedCategory> onCategory;
  final VoidCallback onClear;

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    final has = widget.controller.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _submit(String query) {
    widget.controller.text = query;
    widget.onSearch(query);
  }

  Future<void> _listen() async {
    final heard = await widget.voice?.listen();
    if (heard != null && mounted) _submit(heard);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A search that equals a category is already one tap away as that chip.
    final recents = [
      for (final query in widget.recentQueries)
        if (!widget.categories.any((c) => c.query == query || c.label == query))
          query,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: CarTheme.body,
            onSubmitted: widget.onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari musik, lagu anak, kajian…',
              prefixIcon: const Icon(
                LucideIcons.search,
                size: 20,
                color: CarTheme.textMuted,
              ),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      color: CarTheme.textMuted,
                      onPressed: widget.onClear,
                    )
                  : widget.voice == null
                      ? null
                      : MicButton(voice: widget.voice!, onPressed: _listen),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recents.length + widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index < recents.length) {
                final query = recents[index];
                return _Chip(
                  label: query,
                  icon: LucideIcons.history,
                  selected: query == widget.activeQuery,
                  onTap: () => _submit(query),
                );
              }
              final category = widget.categories[index - recents.length];
              final selected = category.query == widget.activeQuery ||
                  (category.query == null && widget.activeQuery.isEmpty);
              return _Chip(
                label: category.label,
                selected: selected,
                onTap: () => widget.onCategory(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CarTheme.bg : CarTheme.text;
    return Material(
      color: selected ? CarTheme.text : CarTheme.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? CarTheme.text : CarTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
              ],
              // A long search must not take the whole row from the categories.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CarTheme.body.copyWith(fontSize: 14, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mic in a search field: opens the platform's speech recognizer. Hidden once the phone
/// turns out to have none.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.voice, required this.onPressed});

  final VoiceInput voice;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: voice.available,
      builder: (context, available, _) => available
          ? IconButton(
              tooltip: 'Cari dengan suara',
              icon: const Icon(LucideIcons.mic, size: 22),
              color: CarTheme.accent,
              onPressed: onPressed,
            )
          : const SizedBox.shrink(),
    );
  }
}
