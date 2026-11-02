import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'schema.dart';
import 'store.dart';

/// State of local draft persistence, independent from form submission.
enum DraftStatus { loading, ready, dirty, saving, saved, error }

/// A draft could not be read or interpreted without losing information.
class DraftReadException implements Exception {
  const DraftReadException(this.message);
  final String message;
  @override
  String toString() => 'DraftReadException: $message';
}

/// Submission succeeded remotely, but local cleanup failed. Do not submit again.
class DraftCleanupException implements Exception {
  const DraftCleanupException(this.cause);
  final Object cause;
  @override
  String toString() => 'Submission succeeded; draft cleanup failed: $cause';
}

typedef DraftMigration =
    FutureOr<Map<String, Object?>> Function(
      int oldVersion,
      Map<String, Object?> values,
    );

/// Typed form state, synchronous validation and serialized local draft operations.
/// Await [initialize] before editing. Resolve an offered draft with [restore]
/// or [discard]. Own one controller per storage key and dispose it with its view.
class NivorquillFormController extends ChangeNotifier {
  /// Creates a form with a fixed schema, identity and storage adapter.
  NivorquillFormController({
    required this.key,
    required this.store,
    required List<NivorquillFieldDefinition> fields,
    this.schemaVersion = 1,
    this.debounce = const Duration(milliseconds: 400),
    this.expiration = const Duration(days: 7),
    this.migrate,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (schemaVersion < 1 ||
        debounce.isNegative ||
        expiration <= Duration.zero) {
      throw ArgumentError('Invalid version or durations');
    }
    for (final field in fields) {
      if (_fields.containsKey(field.id)) {
        throw ArgumentError('Duplicate field: ${field.id}');
      }
      _fields[field.id] = field;
    }
    _resetValues();
  }

  /// Stable, account-scoped draft identity.
  final DraftKey key;

  /// Storage used for this controller; one active writer per key is required.
  final DraftStore store;

  /// Version of the current persisted value schema.
  final int schemaVersion;

  /// Quiet interval before an automatic save begins.
  final Duration debounce;

  /// Lifetime of a draft measured from its most recent save.
  final Duration expiration;

  /// Optional conversion of older persisted values into the current schema.
  final DraftMigration? migrate;
  final DateTime Function() _clock;
  final Map<String, NivorquillFieldDefinition> _fields = {};
  final Map<String, Object?> _values = {};
  final Map<String, String> _errors = {};
  final Set<String> _touched = {};
  Future<void> _tail = Future<void>.value();
  Future<void>? _initialization;
  Timer? _timer;
  Map<String, Object?>? _candidate;
  bool _ready = false, _disposed = false, _busy = false, _submitted = false;
  int _revision = 0, _savedRevision = 0, _epoch = 0;
  int _draftRevision = 0, _savedDraftRevision = 0;
  DraftStatus _status = DraftStatus.loading;
  Object? _lastError;
  DateTime? _savedAt;

  /// Latest local persistence state.
  DraftStatus get status => _status;

  /// Most recent storage or recovery failure; never a telemetry event.
  Object? get lastError => _lastError;

  /// Timestamp of the last save accepted by storage in this session.
  DateTime? get savedAt => _savedAt;

  /// Whether initialization or explicit discard completed successfully.
  bool get isInitialized => _ready;

  /// Whether fields may accept edits right now.
  bool get canEdit =>
      _ready && !_disposed && !_busy && !_submitted && !hasPendingRestore;

  /// Whether the user must choose Restore or Discard before editing.
  bool get hasPendingRestore => _candidate != null;

  /// Whether submission or deletion is active.
  bool get isBusy => _busy;

  /// Whether submission succeeded but draft deletion still needs retry.
  bool get submissionNeedsCleanup => _submitted;

  /// Whether values changed since the last accepted save or reset.
  bool get isDirty => _revision != _savedRevision;

  /// Immutable current validation messages keyed by field ID.
  Map<String, String> get errors => Map.unmodifiable(_errors);

  /// Whether a field has been edited or included in validation.
  bool isTouched(NivorquillFieldDefinition field) =>
      _touched.contains(field.id);

  /// The current validation message for a field, if any.
  String? errorFor(NivorquillFieldDefinition field) => _errors[field.id];

  void _alive() {
    if (_disposed) throw StateError('Controller is disposed');
  }

  void _editable() {
    _alive();
    if (!_ready || hasPendingRestore || _busy || _submitted) {
      throw StateError(
        'Form is not editable; initialize, resolve recovery or finish cleanup first',
      );
    }
  }

  void _registered(NivorquillFieldDefinition field) {
    if (!identical(_fields[field.id], field)) {
      throw ArgumentError('Field is not registered with this controller');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _resetValues() {
    _values.clear();
    for (final field in _fields.values) {
      _values[field.id] = field.initial();
    }
  }

  /// Detached typed snapshot of all fields, including nonpersisted fields.
  NivorquillFormValues get values {
    final copy = <String, Object?>{};
    for (final field in _fields.values) {
      copy[field.id] = field.decodeValue(field.encodeValue(_values[field.id]));
    }
    return NivorquillFormValues(copy);
  }

  /// Returns a detached value for the exact registered field definition.
  T get<T>(NivorquillField<T> field) {
    _alive();
    _registered(field);
    return field.decodeValue(field.encodeValue(_values[field.id])) as T;
  }

  /// Updates a registered field and schedules a save. Revalidates cross-field rules
  /// after the first validation; setting values is blocked during submission.
  void set<T>(NivorquillField<T> field, T value, {bool touch = true}) {
    _editable();
    _registered(field);
    final copy = field.decodeValue(field.encodeValue(value));
    if (jsonEncode(field.encodeValue(_values[field.id])) ==
        jsonEncode(field.encodeValue(copy))) {
      return;
    }
    _values[field.id] = copy;
    if (touch) _touched.add(field.id);
    ++_revision;
    if (field.persist) {
      ++_draftRevision;
      _lastError = null;
      _status = DraftStatus.dirty;
      _timer?.cancel();
      _timer = Timer(debounce, () {
        unawaited(flush().catchError((Object _) {}));
      });
    }
    if (_validated) _validateValues();
    _notify();
  }

  bool _validated = false;
  bool _validateValues() {
    final snapshot = values;
    final result = <String, String>{};
    for (final field in _fields.values) {
      final message = field.validateValue(snapshot.asMap[field.id], snapshot);
      if (message != null) result[field.id] = message;
    }
    _errors
      ..clear()
      ..addAll(result);
    return result.isEmpty;
  }

  /// Runs field and cross-field validators. Invalid forms cannot be submitted.
  bool validate() {
    _editable();
    _validated = true;
    _touched.addAll(_fields.keys);
    final result = _validateValues();
    _notify();
    return result;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Reads a recovery candidate without automatically applying it. Failures leave
  /// editing disabled until initialization is retried or [discard] succeeds.
  Future<void> initialize() {
    _alive();
    if (_initialization != null) return _initialization!;
    final done = Completer<void>();
    _initialization = done.future;
    unawaited(
      _initialize().then(
        (_) => done.complete(),
        onError: (Object e, StackTrace st) {
          _initialization = null;
          done.completeError(e, st);
        },
      ),
    );
    return done.future;
  }

  Future<void> _initialize() async {
    _status = DraftStatus.loading;
    _notify();
    try {
      final raw = await store.read(key.storageKey);
      _alive();
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> || decoded['format'] != 1) {
          throw const DraftReadException('Unknown draft format');
        }
        final version = decoded['schemaVersion'];
        final expiry = DateTime.parse(decoded['expiresAt'] as String);
        if (!expiry.isAfter(_clock())) {
          await _enqueue(() => store.delete(key.storageKey));
          _alive();
        } else {
          if (version is! int ||
              version < 1 ||
              decoded['values'] is! Map<String, dynamic>) {
            throw const DraftReadException('Invalid draft envelope');
          }
          var data = Map<String, Object?>.from(
            decoded['values'] as Map<String, dynamic>,
          );
          if (version != schemaVersion) {
            if (version > schemaVersion || migrate == null) {
              throw const DraftReadException(
                'Incompatible schema; supply a migration or discard',
              );
            }
            data = await migrate!(version, data);
            _alive();
          }
          final candidate = <String, Object?>{};
          for (final field in _fields.values.where((f) => f.persist)) {
            if (data.containsKey(field.id)) {
              candidate[field.id] = field.decodeValue(data[field.id]);
            }
          }
          _candidate = candidate.isEmpty ? null : candidate;
        }
      }
      _ready = true;
      _status = DraftStatus.ready;
      _lastError = null;
      _notify();
    } catch (e) {
      _lastError = e;
      _status = DraftStatus.error;
      _notify();
      rethrow;
    }
  }

  /// Applies only current, persistable schema fields. Other fields keep defaults.
  void restore() {
    _alive();
    if (!_ready || _busy || _candidate == null) {
      throw StateError('No recovery candidate');
    }
    _values.addAll(_candidate!);
    _candidate = null;
    _savedRevision = ++_revision;
    _savedDraftRevision = _draftRevision;
    _errors.clear();
    _touched.clear();
    _validated = false;
    _status = DraftStatus.saved;
    _notify();
  }

  /// Waits for the current snapshot to be accepted by storage. Later edits remain
  /// dirty and are saved separately. Disposal cancels queued, not active, writes.
  Future<void> flush() async {
    _editable();
    _timer?.cancel();
    if (_draftRevision == _savedDraftRevision) {
      await _tail;
      return;
    }
    final revision = _revision, draftRevision = _draftRevision, epoch = _epoch;
    final now = _clock().toUtc();
    final encoded = <String, Object?>{};
    try {
      for (final field in _fields.values.where((f) => f.persist)) {
        encoded[field.id] = field.encodeValue(_values[field.id]);
      }
      final raw = jsonEncode({
        'format': 1,
        'schemaVersion': schemaVersion,
        'updatedAt': now.toIso8601String(),
        'expiresAt': now.add(expiration).toIso8601String(),
        'values': encoded,
      });
      await _enqueue(() async {
        if (_disposed || epoch != _epoch) return;
        _status = DraftStatus.saving;
        _notify();
        await store.write(key.storageKey, raw);
        if (_disposed || epoch != _epoch) return;
        _savedRevision = revision;
        _savedDraftRevision = draftRevision;
        _savedAt = now;
        _lastError = null;
        _status = _draftRevision != _savedDraftRevision
            ? DraftStatus.dirty
            : DraftStatus.saved;
        _notify();
      });
    } catch (e) {
      if (!_disposed && epoch == _epoch) {
        _lastError = e;
        _status = DraftStatus.error;
        _notify();
      }
      rethrow;
    }
  }

  /// Invalidates queued saves, waits for active writes, then removes the draft.
  /// Also resets all values, including nonpersisted sensitive values.
  Future<void> discard() async {
    _alive();
    if (_busy || (!_ready && _initialization != null)) {
      throw StateError('An operation is already active');
    }
    _busy = true;
    _notify();
    try {
      await _clear();
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _clear() async {
    ++_epoch;
    _timer?.cancel();
    try {
      await _enqueue(() => store.delete(key.storageKey));
      _alive();
      _resetValues();
      _candidate = null;
      _errors.clear();
      _touched.clear();
      _validated = false;
      _submitted = false;
      _ready = true;
      _initialization = Future<void>.value();
      _savedRevision = ++_revision;
      _savedDraftRevision = _draftRevision;
      _savedAt = null;
      _status = DraftStatus.ready;
      _lastError = null;
    } catch (e) {
      _lastError = e;
      _status = DraftStatus.error;
      rethrow;
    }
  }

  /// Validates, freezes editing and invokes the callback once. Clears the draft
  /// only after success. A failed callback retains input; cleanup failures throw
  /// [DraftCleanupException] and block resubmission until [discard] succeeds.
  Future<bool> submit(
    Future<void> Function(NivorquillFormValues values) action,
  ) async {
    _editable();
    _busy = true;
    _timer?.cancel();
    try {
      _validated = true;
      _touched.addAll(_fields.keys);
      final valid = _validateValues();
      _notify();
      if (!valid) return false;
      final snapshot = values;
      await action(snapshot);
      _alive();
      _submitted = true;
      try {
        await _clear();
      } catch (e) {
        throw DraftCleanupException(e);
      }
      return true;
    } finally {
      _busy = false;
      if (!_disposed && _draftRevision != _savedDraftRevision && !_submitted) {
        _timer = Timer(debounce, () {
          unawaited(flush().catchError((Object _) {}));
        });
      }
      _notify();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _timer?.cancel();
    super.dispose();
  }
}
