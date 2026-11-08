import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'state/editor_controller.dart';

/// What a keyboard shortcut asks the editor to do.
enum EditorCommand {
  playPause,
  split,
  delete,
  previousFrame,
  nextFrame,
  playReverse,
  pause,
  playForward,
  undo,
  redo,
}

final class EditorIntent extends Intent {
  const EditorIntent(this.command);

  final EditorCommand command;
}

/// Desktop editor shortcuts, active anywhere inside [child]: Space, S,
/// Delete, Left/Right (one frame), J/K/L, Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y.
/// They take precedence over the keys' usual meaning on a focused button.
class EditorShortcuts extends StatelessWidget {
  const EditorShortcuts({
    required this.controller,
    required this.child,
    super.key,
  });

  final EditorController controller;
  final Widget child;

  static const _bindings = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.space): EditorIntent(
      EditorCommand.playPause,
    ),
    SingleActivator(LogicalKeyboardKey.keyS): EditorIntent(EditorCommand.split),
    SingleActivator(LogicalKeyboardKey.delete): EditorIntent(
      EditorCommand.delete,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): EditorIntent(
      EditorCommand.previousFrame,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): EditorIntent(
      EditorCommand.nextFrame,
    ),
    SingleActivator(LogicalKeyboardKey.keyJ): EditorIntent(
      EditorCommand.playReverse,
    ),
    SingleActivator(LogicalKeyboardKey.keyK): EditorIntent(EditorCommand.pause),
    SingleActivator(LogicalKeyboardKey.keyL): EditorIntent(
      EditorCommand.playForward,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): EditorIntent(
      EditorCommand.undo,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        EditorIntent(EditorCommand.redo),
    SingleActivator(LogicalKeyboardKey.keyY, control: true): EditorIntent(
      EditorCommand.redo,
    ),
  };

  void _run(EditorCommand command) => switch (command) {
    EditorCommand.playPause => controller.togglePlay(),
    EditorCommand.split => controller.split(),
    EditorCommand.delete => controller.deleteSelected(),
    EditorCommand.previousFrame => controller.stepFrame(-1),
    EditorCommand.nextFrame => controller.stepFrame(1),
    EditorCommand.playReverse => controller.playReverse(),
    EditorCommand.pause => controller.pause(),
    EditorCommand.playForward => controller.playForward(),
    EditorCommand.undo => controller.undo(),
    EditorCommand.redo => controller.redo(),
  };

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: _bindings,
    child: Actions(
      actions: {
        EditorIntent: CallbackAction<EditorIntent>(
          onInvoke: (intent) => _run(intent.command),
        ),
      },
      // Holds focus when nothing inside has it, so the keys always arrive.
      child: Focus(autofocus: true, child: child),
    ),
  );
}
