import 'package:cutcap/domain/edit_list.dart' show ClipId;
import 'package:cutcap/editor/editor_screen.dart';
import 'package:cutcap/editor/editor_view_state.dart';
import 'package:cutcap/l10n/app_localizations.dart';
import 'package:cutcap/theme/cutcap_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundled Golos Text, so the bar is measured with the widths it ships
/// with.
Future<void> _loadGolos() async {
  final golos = FontLoader('GolosText');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    golos.addFont(
      rootBundle.load('assets/fonts/golos_text/GolosText-$weight.ttf'),
    );
  }
  await golos.load();
}

void main() {
  late List<String> intents;

  setUpAll(_loadGolos);

  EditorActions actions() {
    void none() {}
    return EditorActions(
      onAddVideo: none,
      onExport: none,
      onPlayPause: none,
      onStepBackward: none,
      onStepForward: none,
      onSplit: none,
      onDelete: none,
      onUndo: none,
      onRedo: none,
      onSelectClip: (_) {},
      onScrub: (_, _) {},
      onZoom: (_, _, _) {},
      onScrollTimeline: (_) {},
      onClear: () => intents.add('clear'),
      onTrimStart: (_, _) {},
      onTrimUpdate: (_) {},
      onTrimEnd: none,
      onReorderStart: (_) {},
      onReorderUpdate: (_) {},
      onReorderEnd: none,
      onDismissNotice: none,
      onCancelExport: none,
      onOpenExport: none,
      onShareExport: none,
      onRetryExport: none,
      onDismissExport: none,
    );
  }

  /// The narrowest common phone, in Russian (the longer labels).
  Future<void> pumpPhone(
    WidgetTester tester, {
    required bool canClear,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: CutcapTheme.data,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(
          actions: actions(),
          state: EditorViewState(
            clips: const [
              ClipView(
                id: ClipId(0),
                name: 'a.mp4',
                duration: Duration(seconds: 4),
              ),
            ],
            canClear: canClear,
            canExport: true,
          ),
        ),
      ),
    );
  }

  setUp(() => intents = []);

  testWidgets('the phone bar clears the track from its overflow menu', (
    tester,
  ) async {
    await pumpPhone(tester, canClear: true);
    final more = find.bySemanticsLabel('Ещё');
    expect(tester.getSize(more), const Size(48, 48));

    await tester.tap(more);
    await tester.pumpAndSettle();
    final clear = find.text('Очистить дорожку');
    expect(
      tester
          .getSize(
            find.ancestor(of: clear, matching: find.byType(MenuItemButton)),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(intents, ['clear']);
    expect(clear, findsNothing);
  });

  testWidgets('the overflow is off while there is nothing to clear', (
    tester,
  ) async {
    await pumpPhone(tester, canClear: false);
    await tester.tap(find.bySemanticsLabel('Ещё'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Очистить дорожку'), findsNothing);
  });

  testWidgets('the phone bar fits at 130 % text', (tester) async {
    await pumpPhone(tester, canClear: true, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.bySemanticsLabel('Ещё')), const Size(48, 48));
  });
}
