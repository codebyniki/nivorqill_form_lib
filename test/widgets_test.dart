import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';

void main() {
  testWidgets('text, checkbox and custom fields bind, validate and reset', (
    tester,
  ) async {
    final title = NivorquillField(
      id: 'title',
      initialValue: '',
      codec: NivorquillCodec.text,
      persist: true,
      validator: NivorquillValidators.requiredText(),
    );
    final consent = NivorquillField(
      id: 'consent',
      initialValue: false,
      codec: NivorquillCodec.boolean,
      validator: NivorquillValidators.accepted,
    );
    final rating = NivorquillField(
      id: 'rating',
      initialValue: 0.0,
      codec: NivorquillCodec.decimal,
    );
    final form = NivorquillFormController(
      key: const DraftKey(namespace: 'test', userId: '1', formId: 'f'),
      store: MemoryDraftStore(),
      fields: [title, consent, rating],
    );
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillForm(
            controller: form,
            child: Column(
              children: [
                NivorquillTextField(
                  controller: form,
                  field: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                NivorquillCheckboxField(
                  controller: form,
                  field: consent,
                  title: const Text('Accept'),
                ),
                NivorquillFieldBuilder<double>(
                  controller: form,
                  field: rating,
                  builder: (context, value, error, changed) =>
                      Slider(value: value, onChanged: changed),
                ),
                NivorquillSaveIndicator(controller: form),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(form.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'New listing');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(form.get(title), 'New listing');
    expect(form.get(consent), isTrue);
    expect(form.validate(), isTrue);
    await form.discard();
    await tester.pump();
    expect(find.text('New listing'), findsNothing);
    expect(form.get(consent), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('recovery is offered before the form is editable', (
    tester,
  ) async {
    final field = NivorquillField(
      id: 'text',
      initialValue: '',
      codec: NivorquillCodec.text,
      persist: true,
    );
    final store = MemoryDraftStore();
    const key = DraftKey(namespace: 'test', userId: '1', formId: 'f');
    final first = NivorquillFormController(
      key: key,
      store: store,
      fields: [field],
    );
    await first.initialize();
    first.set(field, 'Recovered');
    await first.flush();
    first.dispose();
    final second = NivorquillFormController(
      key: key,
      store: store,
      fields: [field],
    );
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillForm(
            controller: second,
            child: NivorquillTextField(controller: second, field: field),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restore draft'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Restore draft'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('nullable dropdown forwards a cleared selection', (tester) async {
    final field = NivorquillField<String?>(
      id: 'optional',
      initialValue: 'a',
      codec: NivorquillCodec.text.nullable(),
    );
    final form = NivorquillFormController(
      key: const DraftKey(namespace: 'test', userId: '1', formId: 'optional'),
      store: MemoryDraftStore(),
      fields: [field],
    );
    addTearDown(form.dispose);
    await form.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillDropdownField<String?>(
            controller: form,
            field: field,
            items: const [
              DropdownMenuItem(value: 'a', child: Text('Alpha')),
              DropdownMenuItem<String?>(value: null, child: Text('None')),
            ],
          ),
        ),
      ),
    );
    tester
        .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
        .onChanged!(null);
    await tester.pump();
    expect(form.get(field), isNull);
    await form.flush();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dropdown follows restored and programmatically changed values', (
    tester,
  ) async {
    final category = NivorquillField(
      id: 'category',
      initialValue: 'a',
      codec: NivorquillCodec.text,
    );
    final form = NivorquillFormController(
      key: const DraftKey(namespace: 'test', userId: '1', formId: 'f'),
      store: MemoryDraftStore(),
      fields: [category],
    );
    addTearDown(form.dispose);
    await form.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillDropdownField(
            controller: form,
            field: category,
            items: const [
              DropdownMenuItem(value: 'a', child: Text('Alpha')),
              DropdownMenuItem(value: 'b', child: Text('Beta')),
            ],
          ),
        ),
      ),
    );
    form.set(category, 'b');
    await tester.pump();
    expect(form.get(category), 'b');
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'b',
    );
    await form.discard();
    await tester.pump();
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'a',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
