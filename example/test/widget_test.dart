import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';
import 'package:nivorquill_form_lib_example/main.dart';

void main() {
  testWidgets('listing demo validates, submits and clears its fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ListingForm(store: MemoryDraftStore())),
    );
    await tester.pumpAndSettle();
    final submit = find.text('Submit demo');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'A lovely desk');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Solid wood, ready for a new home.',
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      find.text('Demo submission complete. Draft cleared.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
