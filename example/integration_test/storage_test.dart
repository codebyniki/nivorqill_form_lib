import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('platform preferences recover a draft and discard deletes it', (
    tester,
  ) async {
    final key = DraftKey(
      namespace: 'integration-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'test',
      formId: 'listing',
    );
    final field = NivorquillField(
      id: 'title',
      initialValue: '',
      codec: NivorquillCodec.text,
      persist: true,
    );
    final first = NivorquillFormController(
      key: key,
      store: PreferencesDraftStore(),
      fields: [field],
    );
    final second = NivorquillFormController(
      key: key,
      store: PreferencesDraftStore(),
      fields: [field],
    );
    addTearDown(() async {
      first.dispose();
      second.dispose();
      await PreferencesDraftStore().delete(key.storageKey);
    });
    await first.initialize();
    first.set(field, 'Persisted on the platform');
    await first.flush();
    first.dispose();
    await second.initialize();
    expect(second.hasPendingRestore, isTrue);
    second.restore();
    expect(second.get(field), 'Persisted on the platform');
    await second.discard();
    expect(await PreferencesDraftStore().read(key.storageKey), isNull);
  });
}
