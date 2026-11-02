import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Identity for one draft. Use a new controller for every user/form/record tuple.
class DraftKey {
  const DraftKey({
    required this.namespace,
    required this.userId,
    required this.formId,
    this.recordId = 'new',
  });
  final String namespace;
  final String userId;
  final String formId;
  final String recordId;
  String get storageKey =>
      'nivorquill.draft.${base64Url.encode(utf8.encode(jsonEncode([namespace, userId, formId, recordId])))}';
}

/// Implementations must replace a value as one operation and propagate failures.
/// Use one active controller per key. Cross-process conflict resolution is not supplied.
abstract interface class DraftStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Deterministic in-memory storage for tests, demos and custom integrations.
class MemoryDraftStore implements DraftStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// Small, noncritical local drafts using Flutter's uncached preferences API.
/// This adapter is unencrypted; preference writes are not a durable-data guarantee.
/// Use an application database adapter when stronger persistence is required.
class PreferencesDraftStore implements DraftStore {
  PreferencesDraftStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  @override
  Future<String?> read(String key) => _preferences.getString(key);
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> delete(String key) => _preferences.remove(key);
}
