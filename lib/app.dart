import 'package:flutter/material.dart';

import 'editor/editor_screen.dart';
import 'editor/editor_view_state.dart';
import 'l10n/app_localizations.dart';
import 'theme/cutcap_theme.dart';

/// Root widget. Strings come from gen-l10n and follow the system locale,
/// falling back to English. The editor has one dark scheme and ignores the
/// system light/dark setting.
class CutcapApp extends StatelessWidget {
  const CutcapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CutcapTheme.data,
      home: const EditorScreen(state: EditorViewState(), actions: _unwired),
    );
  }
}

// The editor is not wired to a session yet (CUTCAP-5); until then every
// action is a no-op.
const _unwired = EditorActions(
  onAddVideo: _ignore,
  onExport: _ignore,
  onPlayPause: _ignore,
  onStepBackward: _ignore,
  onStepForward: _ignore,
  onSplit: _ignore,
  onDelete: _ignore,
  onUndo: _ignore,
  onRedo: _ignore,
  onSelectClip: _ignoreValue,
  onSeek: _ignoreValue,
  onCancelExport: _ignore,
  onOpenExport: _ignore,
  onShareExport: _ignore,
  onRetryExport: _ignore,
  onDismissExport: _ignore,
);

void _ignore() {}
void _ignoreValue(Object? _) {}
