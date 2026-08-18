import 'package:flutter/cupertino.dart';

/// Scales its child toward wherever the finger (or pointer) is, for as long
/// as it is held down — release and it settles back. On the web there is no
/// finger, so hovering does the same thing.
///
/// The scale happens *inside* the parent's clip, so a card grows into its own
/// rounded rectangle instead of overflowing it.
class ZoomPress extends StatefulWidget {
  const ZoomPress({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.14,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far the child grows while held.
  final double scale;

  @override
  State<ZoomPress> createState() => _ZoomPressState();
}

class _ZoomPressState extends State<ZoomPress> {
  bool _active = false;
  Alignment _origin = Alignment.center;

  void _focus(Offset local, Size size) {
    if (size.isEmpty) return;
    final next = Alignment(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    if (next != _origin) setState(() => _origin = next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          cursor: widget.onTap == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          onEnter: (event) {
            _focus(event.localPosition, size);
            setState(() => _active = true);
          },
          onHover: (event) => _focus(event.localPosition, size),
          onExit: (_) => setState(() => _active = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (details) {
              _focus(details.localPosition, size);
              setState(() => _active = true);
            },
            onTapUp: (_) => setState(() => _active = false),
            onTapCancel: () => setState(() => _active = false),
            child: AnimatedScale(
              scale: _active ? widget.scale : 1,
              alignment: _origin,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
