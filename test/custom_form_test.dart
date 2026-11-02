import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';

class GateStore implements DraftStore {
  final gate = Completer<String?>();
  bool failedOnce = false;
  bool failDelete = false;
  String? value;
  @override
  Future<String?> read(String key) async {
    if (!failedOnce) {
      failedOnce = true;
      return gate.future;
    }
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('disk error');
    value = null;
  }
}

void main() {
  const key = DraftKey(namespace: 'tests', userId: 'u', formId: 'f');
  testWidgets('custom loading and error builders can retry initialization', (
    tester,
  ) async {
    final store = GateStore();
    final name = NivorquillField(
      id: 'name',
      initialValue: '',
      codec: NivorquillCodec.text,
    );
    final form = NivorquillFormController(
      key: key,
      store: store,
      fields: [name],
    );
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: NivorquillForm(
          controller: form,
          loadingBuilder: (_) => const Text('Custom loading'),
          errorBuilder: (context, controller, error) => TextButton(
            onPressed: () {
              unawaited(controller.initialize().catchError((Object _) {}));
            },
            child: Text('Retry custom: $error'),
          ),
          child: const Text('Form ready'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Custom loading'), findsOneWidget);
    store.gate.completeError(StateError('read failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retry custom:'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('Form ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('custom recovery builder restores the original saved value', (
    tester,
  ) async {
    final store = MemoryDraftStore();
    final name = NivorquillField(
      id: 'name',
      initialValue: '',
      codec: NivorquillCodec.text,
      persist: true,
    );
    final first = NivorquillFormController(
      key: key,
      store: store,
      fields: [name],
    );
    await first.initialize();
    first.set(name, 'Recovered');
    await first.flush();
    first.dispose();
    final form = NivorquillFormController(
      key: key,
      store: store,
      fields: [name],
    );
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NivorquillForm(
            controller: form,
            recoveryBuilder: (context, controller) => FilledButton(
              onPressed: controller.restore,
              child: const Text('Continue custom'),
            ),
            child: NivorquillTextField(controller: form, field: name),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue custom'), findsOneWidget);
    expect(find.text('Restore draft'), findsNothing);
    await tester.tap(find.text('Continue custom'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('custom recovery UI sees discard failures and can retry', (
    tester,
  ) async {
    final store = GateStore()
      ..value =
          '{"format":1,"schemaVersion":1,"expiresAt":"2099-01-01T00:00:00Z","values":{"name":"saved"}}';
    store.gate.complete(store.value);
    store.failDelete = true;
    final name = NivorquillField(
      id: 'name',
      initialValue: '',
      codec: NivorquillCodec.text,
      persist: true,
    );
    final form = NivorquillFormController(
      key: key,
      store: store,
      fields: [name],
    );
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: NivorquillForm(
          controller: form,
          recoveryBuilder: (context, controller) => Column(
            children: [
              if (controller.lastError != null)
                const Text('Custom deletion error'),
              TextButton(
                onPressed: controller.isBusy
                    ? null
                    : () {
                        unawaited(
                          controller.discard().catchError((Object _) {}),
                        );
                      },
                child: const Text('Start over'),
              ),
            ],
          ),
          child: const Text('Form ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('Custom deletion error'), findsOneWidget);
    expect(form.hasPendingRestore, isTrue);
    store.failDelete = false;
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('Form ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
