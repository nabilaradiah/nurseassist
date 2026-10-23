import 'package:flutter/widgets.dart';

/// Disposes [notifiers] (and runs [onDispose]) when this widget leaves the
/// tree.
///
/// Wrap a bottom sheet's content in this instead of disposing its text
/// controllers right after `await showModalBottomSheet(...)` returns: the
/// sheet keeps rebuilding its fields during the closing animation, and a
/// disposed controller then throws "used after being disposed".
class DisposeWith extends StatefulWidget {
  final List<ChangeNotifier> notifiers;
  final VoidCallback? onDispose;
  final Widget child;

  const DisposeWith({
    super.key,
    this.notifiers = const [],
    this.onDispose,
    required this.child,
  });

  @override
  State<DisposeWith> createState() => _DisposeWithState();
}

class _DisposeWithState extends State<DisposeWith> {
  @override
  void dispose() {
    for (final n in widget.notifiers) {
      n.dispose();
    }
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
