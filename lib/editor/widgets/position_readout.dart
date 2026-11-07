import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../timecode.dart';
import 'timecode_text.dart';

/// The playhead time set as the screen's headline, followed by the grey
/// sequence total on the same baseline: 80 px on desktop, 44 px when
/// [compact] (phone).
class PositionReadout extends StatelessWidget {
  const PositionReadout({
    required this.state,
    required this.compact,
    super.key,
  });

  final EditorViewState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = CutcapTokens.of(context);
    final position = Timecode.full(state.position, state.frameRate);
    final total = '/ ${Timecode.full(state.duration, state.frameRate)}';

    return Semantics(
      label: AppLocalizations.of(context).position,
      child: FittedBox(
        // Narrow windows and large system font sizes shrink the time
        // instead of clipping it.
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.bottomStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TimecodeText(
              position,
              style: compact ? text.displaySmall : text.displayLarge,
            ),
            SizedBox(
              width: compact ? CutcapTokens.space.s : CutcapTokens.space.m,
            ),
            TimecodeText(
              total,
              style: compact
                  ? text.bodyLarge?.copyWith(color: tokens.inkSecondary)
                  : text.headlineMedium?.copyWith(color: tokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
