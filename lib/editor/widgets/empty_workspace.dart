import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import 'editor_controls.dart';

/// The whole workspace before any clip exists; the preview field collapses
/// while there is nothing to show. It says what the editor does and puts
/// Add video in reach: inside a drop target that fills the window on
/// desktop, at the bottom of the screen on the phone.
///
/// Fills the height it is given.
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
    final addVideo = controls.addVideo(inBar: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        if (touch) ...[
          const Spacer(),
          SizedBox(width: double.infinity, child: addVideo),
        ] else
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: tokens.ink)),
              child: Center(
                child: Wrap(
                  spacing: space.l,
                  runSpacing: space.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    addVideo,
                    if (acceptsFileDrop)
                      Text(
                        l10n.dropHint,
                        style: text.bodyMedium?.copyWith(
                          color: tokens.inkSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
