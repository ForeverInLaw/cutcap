import 'package:flutter/material.dart';

import 'editor/editor_page.dart';
import 'l10n/app_localizations.dart';
import 'theme/cutcap_theme.dart';

/// Root widget, to be run inside a `ProviderScope`. Strings come from
/// gen-l10n and follow the system locale, falling back to English. The
/// editor has one dark scheme and ignores the system light/dark setting.
class CutcapApp extends StatelessWidget {
  const CutcapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CutcapTheme.data,
      home: const EditorPage(),
    );
  }
}
