import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemudi/services/platform_bridge.dart';
import 'package:kemudi/theme/car_theme.dart';
import 'package:kemudi/widgets/search_header.dart';

void main() {
  Future<List<String>> pumpHeader(
    WidgetTester tester, {
    List<String> recents = const [],
    VoiceInput? voice,
  }) async {
    final searched = <String>[];
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CarTheme.darkTheme,
        home: Scaffold(
          body: SearchHeader(
            controller: controller,
            focusNode: focus,
            categories: const [
              (label: 'Trending', query: null),
              (label: 'Musik', query: 'Musik Indonesia'),
            ],
            activeQuery: '',
            recentQueries: recents,
            voice: voice,
            onSearch: searched.add,
            onCategory: (_) {},
            onClear: () {},
          ),
        ),
      ),
    );
    return searched;
  }

  testWidgets('a recent search is a chip that searches again', (tester) async {
    final searched = await pumpHeader(
      tester,
      // A search equal to a category is that category's chip already.
      recents: ['tulus', 'Musik Indonesia'],
    );
    expect(find.text('Musik Indonesia'), findsNothing);
    await tester.tap(find.text('tulus'));
    await tester.pump();
    expect(searched, ['tulus']);
    expect(find.widgetWithText(TextField, 'tulus'), findsOneWidget);
  });

  testWidgets('the mic searches what was heard and hides without a recognizer',
      (tester) async {
    final available = ValueNotifier(true);
    addTearDown(available.dispose);
    final searched = await pumpHeader(
      tester,
      voice: (available: available, listen: () async => 'kajian subuh'),
    );
    await tester.tap(find.byTooltip('Cari dengan suara'));
    await tester.pump();
    expect(searched, ['kajian subuh']);

  });

  testWidgets('no mic once the phone has no recognizer', (tester) async {
    final available = ValueNotifier(false);
    addTearDown(available.dispose);
    await pumpHeader(tester, voice: (available: available, listen: () async => null));
    expect(find.byTooltip('Cari dengan suara'), findsNothing);
  });
}
