import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';

/// The black preview field. [child] is the player surface, which letterboxes
/// its own frame; the field stays plain black without one.
class PreviewField extends StatelessWidget {
  const PreviewField({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).preview,
    container: true,
    child: ColoredBox(
      color: CutcapTokens.preview,
      child: SizedBox.expand(child: child),
    ),
  );
}
