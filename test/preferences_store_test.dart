import 'package:flutter_test/flutter_test.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePreferences extends Fake implements SharedPreferencesAsync {
  FakePreferences({this.error});
  final values = <String, String>{};
  final Object? error;
  @override
  Future<String?> getString(String key) async {
    if (error != null) throw error!;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (error != null) throw error!;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (error != null) throw error!;
    values.remove(key);
  }
}

void main() {
  test(
    'preferences store forwards exact keys and supports recovery and deletion',
    () async {
      final preferences = FakePreferences();
      final first = PreferencesDraftStore(preferences);
      final reopened = PreferencesDraftStore(preferences);
      await first.write('account-a', '{"value":"hello"}');
      await first.write('account-b', 'separate');
      expect(await reopened.read('account-a'), '{"value":"hello"}');
      await reopened.delete('account-a');
      expect(await first.read('account-a'), isNull);
      expect(await first.read('account-b'), 'separate');
    },
  );
  test('preferences errors propagate to callers', () async {
    final preferences = FakePreferences(error: StateError('platform failed'));
    final store = PreferencesDraftStore(preferences);
    await expectLater(store.read('a'), throwsStateError);
    await expectLater(store.write('a', 'b'), throwsStateError);
    await expectLater(store.delete('a'), throwsStateError);
  });
}
