import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import 'control_button.dart';
import 'editor_controls.dart';

/// The workspace before any clip exists: says what the editor does and puts
/// Add video where the track will appear. On desktop the track area is also
/// marked as a drop target.
class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({
    required this.controls,
    required this.acceptsFileDrop,
    super.key,
  });

  final EditorControls controls;
  final bool acceptsFileDrop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = CutcapTokens.of(context);
    final text = Theme.of(context).textTheme;
    final space = CutcapTokens.space;
    final touch = controls.touch;
    final addVideo = controls.addVideo(
      kind: ControlKind.filled,
      withIcon: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.emptyTitle,
            style: touch ? text.headlineSmall : text.headlineLarge,
          ),
        ),
        SizedBox(height: space.s),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            l10n.emptyBody,
            style: text.bodyLarge?.copyWith(color: tokens.inkSecondary),
          ),
        ),
        SizedBox(height: touch ? space.xl : space.xxl),
        if (touch)
          SizedBox(width: double.infinity, child: addVideo)
        else
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: tokens.ink)),
            child: SizedBox(
              height: 128,
              width: double.infinity,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    addVideo,
                    if (acceptsFileDrop) ...[
                      SizedBox(width: space.l),
                      Text(
                        l10n.dropHint,
                        style: text.bodyMedium?.copyWith(
                          color: tokens.inkSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
