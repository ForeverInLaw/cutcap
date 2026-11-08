import 'package:cutcap/editor/editor_view_state.dart';
import 'package:cutcap/editor/widgets/position_readout.dart';
import 'package:cutcap/l10n/app_localizations.dart';
import 'package:cutcap/theme/cutcap_theme.dart';
import 'package:cutcap/theme/cutcap_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Under the Shrink Whole Rule the 28 px total gets smaller than the size
  // ink-muted is allowed at (DESIGN.md), so it takes ink-secondary then.
  Future<Color?> totalColour(WidgetTester tester, double scale) async {
    // Wide enough for the 80 px readout in the test font.
    tester.view
      ..physicalSize = const Size(3000, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: CutcapTheme.data,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PositionReadout(
          state: const EditorViewState(),
          compact: false,
          geometry: ReadoutGeometry(
            scale: scale,
            timeWidth: 100,
            baselineDrop: 10,
            height: 80,
          ),
        ),
      ),
    );
    final total = tester.widget<Text>(find.textContaining('/ '));
    return total.style?.color;
  }

  testWidgets('the desktop total is ink-muted at full size', (tester) async {
    expect(await totalColour(tester, 1), CutcapTokens.graphite.inkMuted);
  });

  testWidgets('the desktop total turns ink-secondary once the readout '
      'shrinks', (tester) async {
    expect(await totalColour(tester, 0.8), CutcapTokens.graphite.inkSecondary);
  });
}
