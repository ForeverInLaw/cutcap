import 'package:cutcap/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('follows the Russian system locale for title and home text', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ru', 'RU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: CutcapApp()));

    expect(tester.widget<Title>(find.byType(Title)).title, 'cutcap');
    expect(find.text('Добавьте видео, чтобы начать монтаж'), findsOneWidget);
  });
}
