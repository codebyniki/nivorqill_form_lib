import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';

class ControlledStore implements DraftStore {
  final data = <String, String>{};
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();
  Object? readError, writeError, deleteError;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (readError != null) throw readError!;
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    ++writes;
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (writeGate != null) await writeGate!.future;
    if (writeError != null) throw writeError!;
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (deleteError != null) throw deleteError!;
    data.remove(key);
  }
}

void main() {
  const key = DraftKey(namespace: 'app', userId: 'alice', formId: 'profile');
  final name = NivorquillField(
    id: 'name',
    initialValue: '',
    codec: NivorquillCodec.text,
    persist: true,
    validator: NivorquillValidators.requiredText(),
  );
  final secret = NivorquillField(
    id: 'secret',
    initialValue: '',
    codec: NivorquillCodec.text,
  );
  late ControlledStore store;
  late NivorquillFormController form;
  var now = DateTime.utc(2026, 11, 2);
  NivorquillFormController create({
    DraftKey identity = key,
    int version = 1,
    DraftMigration? migrate,
  }) => NivorquillFormController(
    key: identity,
    store: store,
    fields: [name, secret],
    schemaVersion: version,
    migrate: migrate,
    debounce: const Duration(days: 1),
    clock: () => now,
  );
  setUp(() {
    now = DateTime.utc(2026, 11, 2);
    store = ControlledStore();
    form = create();
  });
  tearDown(() => form.dispose());
  Future<void> seed() async {
    await form.initialize();
    form.set(name, 'Alice');
    await form.flush();
    form.dispose();
    form = create();
  }

  test('nonpersisted edits do not create drafts; mixed edits do', () async {
    await form.initialize();
    form.set(secret, 'private');
    await form.flush();
    expect(store.writes, 0);
    form.set(name, 'Alice');
    await form.flush();
    expect(store.writes, 1);
    form.dispose();
    form = create();
    await form.initialize();
    expect(form.hasPendingRestore, isTrue);
    form.restore();
    expect(form.get(name), 'Alice');
    expect(form.get(secret), '');
    form.set(secret, 'another');
    await form.flush();
    expect(store.writes, 1);
  });

  test('date-only draft round trips local date near midnight', () async {
    final date = NivorquillField(
      id: 'date',
      initialValue: DateTime(2020),
      codec: NivorquillCodec.dateOnly,
      persist: true,
    );
    final first = NivorquillFormController(
      key: key,
      store: store,
      fields: [date],
    );
    await first.initialize();
    first.set(date, DateTime(2026, 1, 1, 0, 5));
    await first.flush();
    first.dispose();
    final second = NivorquillFormController(
      key: key,
      store: store,
      fields: [date],
    );
    await second.initialize();
    second.restore();
    final result = second.get(date);
    expect([result.year, result.month, result.day], [2026, 1, 1]);
    second.dispose();
  });

  test('empty legacy draft is not offered', () async {
    store.data[key.storageKey] = jsonEncode({
      'format': 1,
      'schemaVersion': 1,
      'expiresAt': now.add(const Duration(days: 1)).toIso8601String(),
      'values': <String, Object?>{},
    });
    await form.initialize();
    expect(form.hasPendingRestore, isFalse);
    expect(store.data, isNotEmpty);
  });

  test('date-only keeps calendar components and rejects invalid dates', () {
    final codec = NivorquillCodec.dateOnly;
    final local = DateTime(2026, 1, 1, 0, 5);
    expect(codec.encode(local), '2026-01-01');
    expect(codec.encode(DateTime.utc(2026, 1, 1, 23, 59)), '2026-01-01');
    final restored = codec.decode('2026-01-01');
    expect([restored.year, restored.month, restored.day], [2026, 1, 1]);
    expect(() => codec.decode('2026-02-30'), throwsFormatException);
  });

  test(
    'edits are blocked until initialization and schemas reject duplicate IDs',
    () async {
      expect(() => form.set(name, 'x'), throwsStateError);
      expect(
        () => NivorquillFormController(
          key: key,
          store: store,
          fields: [name, name],
        ),
        throwsArgumentError,
      );
      await form.initialize();
      form.set(name, 'Alice');
      expect(form.get(name), 'Alice');
    },
  );
  test('a different field object cannot access a registered ID', () async {
    await form.initialize();
    final impostor = NivorquillField(
      id: 'name',
      initialValue: '',
      codec: NivorquillCodec.text,
    );
    expect(() => form.get(impostor), throwsArgumentError);
    expect(() => form.set(impostor, 'x'), throwsArgumentError);
  });
  test(
    'persistence is opt-in and snapshots cannot mutate controller data',
    () async {
      await form.initialize();
      form.set(name, 'Alice');
      form.set(secret, 'never-on-disk');
      await form.flush();
      expect(store.data[key.storageKey], isNot(contains('never-on-disk')));
      expect((jsonDecode(store.data[key.storageKey]!) as Map)['values'], {
        'name': 'Alice',
      });
      expect(() => form.values.asMap['name'] = 'other', throwsUnsupportedError);
      expect(form.get(name), 'Alice');
    },
  );
  test(
    'recovery requires consent and restores only persisted values',
    () async {
      await seed();
      await form.initialize();
      expect(form.hasPendingRestore, isTrue);
      expect(form.get(name), '');
      expect(() => form.set(name, 'new'), throwsStateError);
      form.restore();
      expect(form.get(name), 'Alice');
      expect(form.get(secret), '');
      expect(form.isDirty, isFalse);
    },
  );
  test(
    'discarding a recovery candidate deletes storage and resets state',
    () async {
      await seed();
      await form.initialize();
      await form.discard();
      expect(store.data, isEmpty);
      expect(form.hasPendingRestore, isFalse);
      expect(form.get(name), '');
      expect(form.canEdit, isTrue);
    },
  );
  test(
    'identity keys avoid separator collisions and isolate users and records',
    () async {
      expect(
        const DraftKey(namespace: 'a:b', userId: 'c', formId: 'd').storageKey,
        isNot(
          const DraftKey(namespace: 'a', userId: 'b:c', formId: 'd').storageKey,
        ),
      );
      await seed();
      final other = create(
        identity: const DraftKey(
          namespace: 'app',
          userId: 'bob',
          formId: 'profile',
        ),
      );
      addTearDown(other.dispose);
      await other.initialize();
      expect(other.hasPendingRestore, isFalse);
      expect(
        key.storageKey,
        isNot(
          const DraftKey(
            namespace: 'app',
            userId: 'alice',
            formId: 'profile',
            recordId: '2',
          ).storageKey,
        ),
      );
    },
  );
  test('expired drafts are removed before editing', () async {
    await seed();
    now = now.add(const Duration(days: 8));
    await form.initialize();
    expect(form.hasPendingRestore, isFalse);
    expect(store.data, isEmpty);
  });
  test('corrupt storage fails visibly and can be discarded', () async {
    store.data[key.storageKey] = '{bad json';
    await expectLater(form.initialize(), throwsFormatException);
    expect(form.status, DraftStatus.error);
    expect(form.canEdit, isFalse);
    await form.discard();
    expect(form.canEdit, isTrue);
  });
  test(
    'read failures can be retried and concurrent initialization is shared',
    () async {
      store.readError = StateError('offline');
      final a = form.initialize(), b = form.initialize();
      expect(identical(a, b), isTrue);
      await expectLater(a, throwsStateError);
      store.readError = null;
      await form.initialize();
      expect(form.canEdit, isTrue);
    },
  );
  test('newer schemas cannot be silently restored', () async {
    await seed();
    form.dispose();
    form = create(version: 2);
    await expectLater(form.initialize(), throwsA(isA<DraftReadException>()));
    expect(store.data, isNotEmpty);
  });
  test('explicit migration restores renamed values', () async {
    await seed();
    form.dispose();
    form = create(
      version: 2,
      migrate: (version, values) {
        expect(version, 1);
        return {'name': '${values['name']} migrated'};
      },
    );
    await form.initialize();
    form.restore();
    expect(form.get(name), 'Alice migrated');
  });
  test('wrong persisted types fail atomically', () async {
    await seed();
    final payload =
        jsonDecode(store.data[key.storageKey]!) as Map<String, dynamic>;
    payload['values'] = {'name': 123};
    store.data[key.storageKey] = jsonEncode(payload);
    await expectLater(form.initialize(), throwsA(isA<TypeError>()));
    expect(form.get(name), '');
    expect(form.hasPendingRestore, isFalse);
  });
  test('write failures leave data dirty and explicit retry succeeds', () async {
    await form.initialize();
    form.set(name, 'Alice');
    store.writeError = StateError('full');
    await expectLater(form.flush(), throwsStateError);
    expect(form.isDirty, isTrue);
    expect(form.status, DraftStatus.error);
    store.writeError = null;
    await form.flush();
    expect(form.isDirty, isFalse);
    expect(form.lastError, isNull);
  });
  test('older active saves cannot mark later edits saved', () async {
    await form.initialize();
    store.writeGate = Completer<void>();
    form.set(name, 'first');
    final first = form.flush();
    await store.writeStarted.future;
    form.set(name, 'second');
    store.writeGate!.complete();
    await first;
    expect(form.isDirty, isTrue);
    await form.flush();
    expect(store.data[key.storageKey], contains('second'));
  });
  test(
    'writes stay ordered and discard wins over active and queued writes',
    () async {
      await form.initialize();
      store.writeGate = Completer<void>();
      form.set(name, 'first');
      final first = form.flush();
      await store.writeStarted.future;
      form.set(name, 'second');
      final second = form.flush();
      final discarded = form.discard();
      expect(() => form.set(name, 'third'), throwsStateError);
      store.writeGate!.complete();
      await Future.wait([first, second, discarded]);
      expect(store.data, isEmpty);
      expect(store.writes, 1);
      expect(form.isDirty, isFalse);
    },
  );
  test('invalid forms never invoke submission and show errors', () async {
    await form.initialize();
    var calls = 0;
    expect(
      await form.submit((_) async {
        ++calls;
      }),
      isFalse,
    );
    expect(calls, 0);
    expect(form.errorFor(name), 'Required');
    form.set(name, 'Alice');
    expect(form.errorFor(name), isNull);
  });
  test(
    'cross-field validators revalidate when another field changes',
    () async {
      final confirm = NivorquillField(
        id: 'confirm',
        initialValue: '',
        codec: NivorquillCodec.text,
        validator: (value, values) =>
            value == values.get(name) ? null : 'Mismatch',
      );
      final other = NivorquillFormController(
        key: key,
        store: store,
        fields: [name, confirm],
      );
      addTearDown(other.dispose);
      await other.initialize();
      other.set(name, 'one');
      other.set(confirm, 'one');
      expect(other.validate(), isTrue);
      other.set(name, 'two');
      expect(other.errorFor(confirm), 'Mismatch');
    },
  );
  test(
    'submission freezes input, prevents duplicates and clears after success',
    () async {
      await form.initialize();
      form.set(name, 'Alice');
      await form.flush();
      final gate = Completer<void>();
      final submission = form.submit((values) async {
        expect(values.get(name), 'Alice');
        await gate.future;
      });
      await expectLater(form.submit((_) async {}), throwsStateError);
      expect(() => form.set(name, 'other'), throwsStateError);
      gate.complete();
      expect(await submission, isTrue);
      expect(store.data, isEmpty);
      expect(form.get(name), '');
    },
  );
  test(
    'reentrant submission listeners cannot start a second request',
    () async {
      await form.initialize();
      form.set(name, 'Alice');
      Future<bool>? duplicate;
      form.addListener(() {
        if (form.isBusy && duplicate == null) {
          duplicate = form.submit((_) async {});
        }
      });
      final assertion = Completer<void>();
      var calls = 0;
      final result = form.submit((_) async {
        ++calls;
        await assertion.future;
      });
      await expectLater(duplicate, throwsStateError);
      assertion.complete();
      await result;
      expect(calls, 1);
    },
  );
  test('failed submission retains input and existing draft', () async {
    await form.initialize();
    form.set(name, 'Alice');
    await form.flush();
    await expectLater(
      form.submit((_) async {
        throw StateError('server failed');
      }),
      throwsStateError,
    );
    expect(form.get(name), 'Alice');
    expect(store.data, isNotEmpty);
    expect(form.canEdit, isTrue);
  });
  test(
    'cleanup failure reports success separately and blocks resubmission',
    () async {
      await form.initialize();
      form.set(name, 'Alice');
      await form.flush();
      store.deleteError = StateError('disk');
      var calls = 0;
      await expectLater(
        form.submit((_) async {
          ++calls;
        }),
        throwsA(isA<DraftCleanupException>()),
      );
      expect(form.submissionNeedsCleanup, isTrue);
      await expectLater(
        form.submit((_) async {
          ++calls;
        }),
        throwsStateError,
      );
      expect(calls, 1);
      store.deleteError = null;
      await form.discard();
      expect(store.data, isEmpty);
      expect(form.canEdit, isTrue);
    },
  );
  test(
    'disposal cancels queued writes and ignores late active write state',
    () async {
      await form.initialize();
      store.writeGate = Completer<void>();
      form.set(name, 'Alice');
      final save = form.flush();
      await store.writeStarted.future;
      form.dispose();
      store.writeGate!.complete();
      await save;
      expect(() => form.set(name, 'x'), throwsStateError);
    },
  );
  testWidgets('debounce coalesces edits and disposal cancels timers', (
    tester,
  ) async {
    form.dispose();
    form = NivorquillFormController(
      key: key,
      store: store,
      fields: [name],
      debounce: const Duration(milliseconds: 100),
    );
    await form.initialize();
    form.set(name, 'A');
    await tester.pump(const Duration(milliseconds: 50));
    form.set(name, 'AB');
    await tester.pump(const Duration(milliseconds: 90));
    expect(store.writes, 0);
    await tester.pump(const Duration(milliseconds: 20));
    expect(store.writes, 1);
    form.set(name, 'ABC');
    form.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.writes, 1);
  });
  test(
    'mutable defaults and returned snapshots cannot change controller state',
    () async {
      final defaults = <String>['one'];
      final items = NivorquillField<List<String>>(
        id: 'items',
        initialValue: defaults,
        codec: NivorquillCodec<List<String>>(
          encode: (v) => v,
          decode: (v) => List<String>.from(v! as List),
        ),
      );
      defaults.add('two');
      final other = NivorquillFormController(
        key: key,
        store: store,
        fields: [items],
      );
      addTearDown(other.dispose);
      await other.initialize();
      expect(other.get(items), ['one']);
      final snapshot = other.get(items);
      snapshot.add('changed');
      expect(other.get(items), ['one']);
      other.set(items, ['new']);
      await other.discard();
      expect(other.get(items), ['one']);
    },
  );

  test('codecs support nullable numbers, dates and reject invalid data', () {
    expect(NivorquillCodec.integer.nullable().decode(null), isNull);
    expect(NivorquillCodec.decimal.decode(3), 3.0);
    expect(
      NivorquillCodec.dateTime.decode(NivorquillCodec.dateTime.encode(now)),
      now,
    );
    expect(
      () => NivorquillCodec.boolean.decode('true'),
      throwsA(isA<TypeError>()),
    );
    expect(() => NivorquillValidators.minLength(-1), throwsArgumentError);
  });
}
