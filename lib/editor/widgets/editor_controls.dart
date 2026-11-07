import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../editor_view_state.dart';
import 'control_button.dart';

/// Builds each editor control once, wired to state and actions, so the
/// desktop and phone layouts only decide where controls go.
///
/// [touch] selects the phone sizing: 48 dp targets and no shortcut hints.
final class EditorControls {
  EditorControls(
    BuildContext context, {
    required this.state,
    required this.actions,
    required this.touch,
  }) : _l10n = AppLocalizations.of(context);

  final EditorViewState state;
  final EditorActions actions;
  final bool touch;
  final AppLocalizations _l10n;

  double get _size => touch ? 48 : 40;
  String? _key(String key) => touch ? null : key;
  VoidCallback? _when(bool enabled, VoidCallback action) =>
      enabled ? action : null;

  Widget stepBackward() => ControlButton(
    icon: Icons.skip_previous_sharp,
    label: _l10n.previousFrame,
    shortcut: _key('←'),
    onPressed: _when(!state.isEmpty, actions.onStepBackward),
    size: 48,
  );

  Widget playPause() => ControlButton(
    icon: state.isPlaying ? Icons.pause_sharp : Icons.play_arrow_sharp,
    label: state.isPlaying ? _l10n.pause : _l10n.play,
    shortcut: _key(_l10n.keySpace),
    onPressed: _when(!state.isEmpty, actions.onPlayPause),
    kind: ControlKind.filled,
    size: touch ? 48 : 64,
    iconSize: touch ? 26 : 32,
  );

  Widget stepForward() => ControlButton(
    icon: Icons.skip_next_sharp,
    label: _l10n.nextFrame,
    shortcut: _key('→'),
    onPressed: _when(!state.isEmpty, actions.onStepForward),
    size: 48,
  );

  Widget split({bool showLabel = false}) => ControlButton(
    icon: Icons.content_cut_sharp,
    label: _l10n.split,
    shortcut: _key('S'),
    onPressed: _when(state.canSplit, actions.onSplit),
    showLabel: showLabel,
    size: _size,
  );

  Widget delete({bool showLabel = false}) => ControlButton(
    icon: Icons.delete_outline_sharp,
    label: _l10n.deleteClip,
    shortcut: _key(_l10n.keyDelete),
    onPressed: _when(state.canDelete, actions.onDelete),
    showLabel: showLabel,
    size: _size,
  );

  Widget undo({ControlKind kind = ControlKind.outlined}) => ControlButton(
    icon: Icons.undo_sharp,
    label: _l10n.undo,
    shortcut: _key('Ctrl+Z'),
    onPressed: _when(state.canUndo, actions.onUndo),
    kind: kind,
    size: _size,
  );

  Widget redo({ControlKind kind = ControlKind.outlined}) => ControlButton(
    icon: Icons.redo_sharp,
    label: _l10n.redo,
    shortcut: _key('Ctrl+Shift+Z'),
    onPressed: _when(state.canRedo, actions.onRedo),
    kind: kind,
    size: _size,
  );

  /// The top bar shows words only; the empty state adds the plus.
  Widget addVideo({
    ControlKind kind = ControlKind.plain,
    bool withIcon = false,
  }) => ControlButton(
    icon: withIcon ? Icons.add_sharp : null,
    label: _l10n.addVideo,
    onPressed: actions.onAddVideo,
    kind: kind,
    showLabel: true,
    size: _size,
  );

  Widget export() => ControlButton(
    label: _l10n.export,
    onPressed: _when(state.canExport, actions.onExport),
    kind: ControlKind.filled,
    showLabel: true,
    size: _size,
  );
}
