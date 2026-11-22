import 'package:flutter/widgets.dart';

/// Rebuilds [builder] only when [selector]'s value changes, not on every notification
/// of [listenable]. For views that need one fact of a broad ChangeNotifier such as the
/// playback controller, which also notifies on play, pause, loading and quality.
class ListenableSelector<T> extends StatefulWidget {
  const ListenableSelector({
    super.key,
    required this.listenable,
    required this.selector,
    required this.builder,
  });

  final Listenable listenable;
  final T Function() selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<ListenableSelector<T>> createState() => _ListenableSelectorState<T>();
}

class _ListenableSelectorState<T> extends State<ListenableSelector<T>> {
  late T _value = widget.selector();

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChange);
  }

  @override
  void didUpdateWidget(ListenableSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
    }
    _value = widget.selector();
  }

  void _onChange() {
    final value = widget.selector();
    if (value != _value) setState(() => _value = value);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
