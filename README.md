# Nivorquill Form Lib

**Let users finish what they started.**

A typed Flutter form library with validation, reusable Material fields, custom
widget bindings and explicit local draft recovery. Version **1.0.0-rc.1**.

## Features

- Typed text, number, boolean, date and custom JSON codecs.
- Field and cross-field validators with reactive error feedback.
- Text, dropdown and checkbox widgets, plus a builder for arbitrary controls.
- Debounced autosave, ordered writes, save status and explicit retry.
- Restore/discard recovery, expiration and application-defined schema migration.
- Isolated draft keys for each namespace, user, form and record.
- Opt-in persistence: registered fields are not saved unless `persist: true`.
- Submission freezes editing and removes a draft only after callback success.

See [validation status](doc/VALIDATION.md) for actual checks and remaining native verification.

## Requirements and local installation

Flutter 3.41+ and Dart 3.11+. The storage adapter supports the platforms supported
by your resolved shared_preferences and Flutter versions.

Before this package is published, use the extracted source directory:

```yaml
dependencies:
  nivorquill_form_lib:
    path: ../nivorquill_form_lib
```

Run `flutter pub get` in your application. After publication, use
`nivorquill_form_lib: ^1.0.0-rc.1` instead.

## Basic use

```dart
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';

final title = NivorquillField<String>(
  id: 'title',
  initialValue: '',
  codec: NivorquillCodec.text,
  persist: true,
  validator: NivorquillValidators.requiredText(),
);

final form = NivorquillFormController(
  key: const DraftKey(
    namespace: 'my-app', userId: 'user-123', formId: 'listing', recordId: 'new',
  ),
  store: PreferencesDraftStore(),
  fields: [title],
);

// In a bounded Flutter layout; create the controller once in initState:
NivorquillForm(
  controller: form,
  child: NivorquillTextField(
    controller: form,
    field: title,
    decoration: const InputDecoration(labelText: 'Title'),
  ),
);

// In an awaited button handler, with your error handling:
await form.submit((values) async {
  // await yourApi.createListing(title: values.get(title));
});
// Dispose the controller in State.dispose after its widgets are removed.
```

`NivorquillForm` initializes the controller and shows built-in Restore/Discard UI.
Without that wrapper, await `form.initialize()`, inspect `hasPendingRestore`,
then call `restore()` or await `discard()` before editing.

`form.set(field, value)` and `form.get(field)` work with the same registered
field object. Keep field definitions stable. `NivorquillFieldBuilder<T>` binds your
own sliders, date pickers and other controls; use its nullable `onChanged`
callback to respect disabled and submitting states.

## Custom recovery screens

`NivorquillForm` accepts `loadingBuilder`, `recoveryBuilder`, and `errorBuilder`
so initialization and recovery can follow your app's design. Each recovery/error
builder receives the controller. Call `restore()` to apply the saved values, or
await `discard()` to remove them. Both initialization and discard can fail; show
`controller.lastError` and offer a retry as appropriate.

```dart
NivorquillForm(
  controller: form,
  loadingBuilder: (_) => const Text('Loading your form…'),
  recoveryBuilder: (context, controller) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Welcome back! Continue where you left off?'),
      FilledButton(
        onPressed: controller.isBusy ? null : controller.restore,
        child: const Text('Continue'),
      ),
      TextButton(
        onPressed: controller.isBusy ? null : () async {
          try {
            await controller.discard();
          } catch (_) {
            // Rebuild and show controller.lastError or your own message.
          }
        },
        child: const Text('Start over'),
      ),
      if (controller.lastError != null)
        const Text('Could not remove the saved draft. Try again.'),
    ],
  ),
  child: yourFormContent,
);
```

The builders are optional; existing defaults remain available. `errorBuilder`
receives the error and controller so an app can provide accessible retry/discard
controls consistent with its design.

## Validation and submission

A validator receives its typed value and a `NivorquillFormValues` snapshot. Compare fields
with `values.get(otherField)` for confirmation, ranges and conditional rules.
Compose validators using `NivorquillValidators.all`. Validation is synchronous;
application/server checks belong in the awaited submission callback. For live remote
checks, keep loading and error state in the app, capture a values snapshot and a
generation number, and ignore results after any field changes or disposal. Cancel
requests where supported. Repeat the check in `submit` against its frozen snapshot;
do not rely on a previous result. This avoids stale cross-field results.

`validate()` reveals errors and revalidates on later edits. `submit()` returns
false for invalid input, freezes editing, prevents simultaneous submission and
resets the form after successful callback and storage cleanup. A callback failure
retains input. Catch errors in your button handler.

If the server succeeds but deletion fails, `DraftCleanupException` is thrown and
`submissionNeedsCleanup` becomes true. Retry cleanup with `discard()`; do not
repeat the server request. For critical transactions, your server must supply
idempotency. A process crash between server success and local deletion cannot be
made exactly-once by a client form library.

## Persistence contract and privacy

`PreferencesDraftStore` uses uncached `SharedPreferencesAsync` for small,
noncritical drafts. It is not encrypted, and successful preference calls do not
guarantee persistence across every crash or OS failure. For stronger requirements,
implement `DraftStore` using your database or encrypted application storage.
`MemoryDraftStore` is for tests and nonpersistent use.

Never opt passwords, authentication tokens, OTPs or payment secrets into saving.
The package does not inspect text to identify sensitive content, encrypt values,
send telemetry or upload drafts. Applications own consent, retention and storage
backup policies. Expired drafts are cleaned when their key is next opened.

Use one active controller per key. Multiple controllers, isolates, browser tabs
or processes editing the same key need application-level coordination. Use a new
user-scoped controller on account switches; dispose the old one and remove its
view. Local drafts are not automatically deleted by logging out of your app.

Autosave can lose changes entered within the debounce window. Call and await
`flush()` before deliberate navigation. A best-effort lifecycle flush is useful,
but background callbacks and dispose cannot guarantee a final write. `dispose()`
cancels timers and queued saves; an already active write may complete. Keep the
controller alive and prevent edits while awaiting a navigation save. Handle failure
before offering retry or an explicit leave-without-saving choice:

```dart
Future<bool> mayLeave(NivorquillFormController form) async {
  try {
    await form.flush();
    return true;
  } catch (error) {
    // Show an error and let the user retry; stay on the form meanwhile.
    return false;
  }
}
```

`flush` saves the snapshot at invocation; edits made while it awaits need another
flush. It must be called after initialization and recovery and before disposal.
Fields with `persist: false` remain in memory only, even after a successful flush.
Editing only those fields does not create a draft; an existing draft with no
recognized persistable values is ignored but not deleted. `isDirty` still tracks
all edits, while save status describes persistable edits.

For a calendar date use `NivorquillCodec.dateOnly` (or `.nullable()`): it stores
`YYYY-MM-DD`, using the supplied DateTime's calendar components, and restores a
local midnight. Use years 1–9999 and do not convert the value to UTC before saving.
It discards time and zone information; `dateTime` continues to store an instant in
UTC. Applications needing dates in zones with skipped civil days should use a
custom calendar-date type and codec.

## Schema changes

Increment `schemaVersion` when persisted field meanings or types change. Provide
`migrate(oldVersion, values)` returning a map in the current schema. Migrations
must be deterministic; they may run again until a new edit is saved. The package
rejects future schema versions and unknown formats. Invalid stored values surface
an error; recovery is atomic. Unknown field IDs are ignored and only currently
persistable fields can restore. Discarding is always an explicit operation.

## Run the example

```sh
cd example
flutter create --platforms=android,ios,web --project-name=nivorquill_form_lib_example .
flutter pub get
flutter run
```

Native/web hosts are included. The create command refreshes missing scaffold files
using your Flutter SDK; it preserves the existing example source. The example uses local
preferences and a simulated submission; it does not contact a server. Type a
listing, wait for “Saved locally”, close/reopen the app, then restore it.

## Development

```sh
flutter pub get
cd example && flutter pub get
cd ..
dart format lib test example/lib example/test example/integration_test
flutter analyze --fatal-infos
flutter test --coverage
cd example && flutter test test
cd ..
flutter pub publish --dry-run
```

Add your real repository/homepage URL to pubspec.yaml before publishing to remove
its optional metadata warning. No source repository or package name is reserved
by this archive. See [architecture](doc/ARCHITECTURE.md) and [release notes](doc/VALIDATION.md).

MIT license. Flutter and shared_preferences retain their upstream licenses.

## Migrating from 0.1.0-beta.1

The form API was renamed to make its general-purpose role clear. Update the
following names; draft-specific storage APIs and existing saved draft keys are
unchanged. This beta intentionally has no deprecated aliases.

| Previous name | New name |
| --- | --- |
| `DraftFormController` | `NivorquillFormController` |
| `DraftForm` | `NivorquillForm` |
| `DraftField` | `NivorquillField` |
| `DraftCodec` | `NivorquillCodec` |
| `DraftValidators` | `NivorquillValidators` |
| `FieldDefinition` | `NivorquillFieldDefinition` |
| `FormValues` | `NivorquillFormValues` |
| `DraftTextField` | `NivorquillTextField` |
| `DraftDropdownField` | `NivorquillDropdownField` |
| `DraftCheckboxField` | `NivorquillCheckboxField` |
| `DraftFieldBuilder` | `NivorquillFieldBuilder` |
| `DraftSaveIndicator` | `NivorquillSaveIndicator` |
