import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Root widget. Strings come from gen-l10n and follow the system locale,
/// falling back to English when the system language is not supported.
class CutcapApp extends StatelessWidget {
  const CutcapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _HomePlaceholder(),
    );
  }
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).homePlaceholder)),
    );
  }
}
