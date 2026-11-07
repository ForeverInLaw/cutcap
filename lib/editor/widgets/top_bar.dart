import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_theme.dart';
import '../../theme/cutcap_tokens.dart';
import 'control_button.dart';
import 'editor_controls.dart';

/// The bar on the black preview field: the lowercase wordmark and the
/// bar's controls. It always uses the dark theme so its controls read paper
/// on black in either system scheme.
///
/// Desktop carries Add video and Export; the phone carries Undo, Redo and
/// Export (adding happens from the add tile at the end of the track).
class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    required this.controls,
    this.showAddVideo = true,
    super.key,
  });

  final EditorControls controls;

  /// Off while the empty state shows its own Add video.
  final bool showAddVideo;

  /// Desktop height; the phone bar is 64 dp so its 48 dp targets keep
  /// clear of the edges.
  static const desktopHeight = 56.0;
  static const _phoneHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final touch = controls.touch;
    final space = CutcapTokens.space;
    return Theme(
      data: CutcapTheme.dark,
      child: Builder(
        builder: (context) => SizedBox(
          height: touch ? _phoneHeight : desktopHeight,
          child: Padding(
            padding: EdgeInsets.only(
              left: touch ? space.l : space.xxl,
              right: touch ? space.s : space.xxl,
            ),
            child: Row(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AppLocalizations.of(context).appTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CutcapTokens.onPreview,
                    ),
                  ),
                ),
                const Spacer(),
                if (touch) ...[
                  controls.undo(kind: ControlKind.plain),
                  controls.redo(kind: ControlKind.plain),
                  SizedBox(width: space.s),
                ] else if (showAddVideo) ...[
                  controls.addVideo(),
                  SizedBox(width: space.l),
                ],
                controls.export(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
