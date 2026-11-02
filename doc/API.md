# Nivorquill Form Lib API guide

Import `package:nivorquill_form_lib/nivorquill_form_lib.dart`. See the
[README](../README.md) for a complete setup and navigation-save example.

## Fields and values

`NivorquillField<T>(id:, initialValue:, codec:, persist: false, validator:)`
defines a stable, non-empty ID, its default and optional synchronous validator.
IDs must be unique in the controller. Persistence is opt-in. The constructor
snapshots the default through JSON; mutable values must round-trip through the codec.
The validator receives the typed value and a detached `NivorquillFormValues`.
`values.get(field)` returns the typed value; `values.asMap` returns an immutable
top-level map. Nested mutable values belong to the snapshot.

`NivorquillCodec<T>(encode:, decode:)` converts values to and from JSON-compatible
data. `nullable()` adds null support. Built-ins are `text`, `boolean`, `integer`,
`decimal`, `dateTime` and `dateOnly`. `dateTime` converts to a UTC ISO instant.
`dateOnly` saves calendar components as `YYYY-MM-DD` and restores local midnight;
it discards time and zone, accepts years 1–9999, and cannot represent a skipped
local civil date. Supply a custom codec for other semantics.

`NivorquillFieldDefinition` is the type-erased extension boundary. Its `id`,
`persist`, `initial()`, `encodeValue(value)`, `decodeValue(value)` and
`validateValue(value, values)` expose the same operations used by the controller.
Applications normally use `NivorquillField<T>` instead.

## Validators

Each validator returns a message or null. `requiredText(message:)` rejects trimmed
empty strings; `minLength(length, message:)` counts Unicode runes and rejects a
negative length. `requiredValue<T>(message:)` rejects null. `range(min:, max:,
message:)` checks inclusive bounds and rejects non-finite input and invalid bounds.
`pattern(expression, message:)` uses the supplied regular expression.
`accepted(value, values)` requires true. `all<T>(validators)` evaluates in order
and returns the first error. Validators are synchronous; see the README for an
application-level asynchronous pattern.

## Controller

Create `NivorquillFormController(key:, store:, fields:, schemaVersion: 1,
debounce: 400ms, expiration: 7 days, migrate:, clock:)` once per form and
storage key. `migrate` is a `DraftMigration`: it receives the old version and
persisted map and returns the current map, synchronously or asynchronously.
`clock` supports deterministic expiry tests. Invalid durations, versions, and
duplicate IDs throw. The controller is a `ChangeNotifier`.

| Operation | Behavior |
| --- | --- |
| `initialize()` | Reads the draft; concurrent calls share initialization. A read or migration error is thrown and can be retried. |
| `restore()` | Applies a pending candidate's current persistable fields; other values remain defaults. |
| `discard()` | Waits for active writes, invalidates queued writes, deletes the draft and resets all values. A deletion error is thrown. |
| `get(field)` | Returns a detached typed value for the exact registered field. |
| `set(field, value, touch: true)` | Copies and updates the value, optionally marks it touched, revalidates after validation and schedules persistence for persisted fields. |
| `validate()` | Marks all fields touched, runs synchronous validation and returns whether all fields are valid. |
| `flush()` | Cancels the timer and awaits storage of the current persistable snapshot; errors are thrown. Edits during the await require another flush. |
| `submit(action)` | Validates, freezes edits and awaits `action(values)`. Returns false if invalid; on success deletes the draft and resets. Callback failures retain values. |
| `errorFor(field)` / `isTouched(field)` | Return the current error or touched state for a field. |
| `dispose()` | Cancels timers and queued writes; an active write may complete. It cannot await a final save. |

Read `values`, `errors`, `status`, `lastError`, `savedAt`, `isInitialized`,
`canEdit`, `hasPendingRestore`, `isBusy`, `submissionNeedsCleanup`, and
`isDirty` to build UI. `isDirty` tracks all edits; draft status tracks
persistable edits. `DraftStatus` is `loading`, `ready`, `dirty`, `saving`,
`saved`, or `error`. Empty or unrecognized persisted maps do not offer recovery
and are not automatically deleted. Resolve a recovery candidate before editing.
Keep the controller alive while awaiting operations and stop editing during a
navigation flush. `DraftReadException` describes unreadable or incompatible
drafts. `DraftCleanupException.cause` reports cleanup failure after successful
submission: retry `discard()`, not the remote action.

## Storage

`DraftKey(namespace:, userId:, formId:, recordId: 'new')` produces the
`storageKey` for a user, form and record. Use one active controller per key.
`DraftStore.read(key)`, `write(key, value)` and `delete(key)` are asynchronous;
custom stores must propagate errors and replace a value atomically.
`MemoryDraftStore()` is ephemeral. `PreferencesDraftStore([preferences])`
uses `SharedPreferencesAsync` and is unencrypted and best effort. It is unsuitable
for secrets or critical data without an appropriate application-owned adapter.

## Widgets

- `NivorquillForm(controller:, child:, loadingBuilder:, recoveryBuilder:,
  errorBuilder:)` initializes a caller-owned controller and displays recovery or
  initialization errors before the child. Custom recovery must call `restore()`
  or await and handle errors from `discard()`.
- `NivorquillFieldBuilder<T>(controller:, field:, builder:)` passes the context,
  detached value, error, and nullable change callback for custom inputs.
- `NivorquillTextField(controller:, field:, decoration:, obscureText:, maxLines:,
  keyboardType:, focusNode:, autofillHints:, inputFormatters:, textInputAction:,
  onSubmitted:)` binds a Material text field. The caller owns any focus node.
- `NivorquillDropdownField<T>(controller:, field:, items:, decoration:)` and
  `NivorquillCheckboxField(controller:, field:, title:)` bind Material inputs.
- `NivorquillSaveIndicator(controller:)` displays draft status and retries saves
  after errors. Application-specific error UI may inspect `lastError`.

Fields update when restored or reset. Remove dependent widgets and dispose the
caller-owned controller at the end of its lifetime.
