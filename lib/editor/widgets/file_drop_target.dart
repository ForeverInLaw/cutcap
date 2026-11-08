import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../theme/cutcap_tokens.dart';

/// Takes files dragged from the desktop (Explorer) onto [child] and hands
/// their paths to [onDrop] in the order Explorer hands them over (its own
/// order, not the order they were selected in).
///
/// While files hover over it the whole window gets the hover overlay (ink
/// at 6 %) inside a 1 px ink hairline, the empty state's drop-target
/// language, fading at the short duration. With [enabled] off it neither
/// highlights nor takes drops.
class FileDropTarget extends StatefulWidget {
  const FileDropTarget({
    required this.enabled,
    required this.onDrop,
    required this.child,
    super.key,
  });

  final bool enabled;
  final ValueChanged<List<String>> onDrop;
  final Widget child;

  @override
  State<FileDropTarget> createState() => _FileDropTargetState();
}

class _FileDropTargetState extends State<FileDropTarget> {
  var _hovering = false;

  void _hover(bool hovering) {
    if (hovering != _hovering) setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CutcapTokens.of(context);
    final motion = CutcapTokens.motion;
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => _hover(true),
      // Also called just before a drop.
      onDragExited: (_) => _hover(false),
      onDragDone: (details) =>
          widget.onDrop([for (final file in details.files) file.path]),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _hovering ? 1 : 0,
              duration: motion.of(context, motion.short),
              curve: motion.curve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).hoverColor,
                  border: Border.all(color: tokens.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
