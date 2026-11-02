# Architecture

The schema is a list of immutable field definitions with stable IDs, typed codecs,
validators and persistence flags. The controller owns the live values, snapshots,
validation errors, initialization, recovery and submission state. Flutter widgets
observe the controller and never own storage. Applications own controller lifetime.

All writes and deletes share one per-controller future queue. Saves capture both
a revision and a generation. Deletion increments the generation synchronously,
cancels debouncing, waits for active writes and skips stale queued writes before
removing the key. Failure does not poison the queue. Later edits remain dirty when
an older write finishes. A single controller per key is a documented invariant.

Initialization exposes a stored candidate without applying it. Only opted-in
fields are decoded; candidates decode completely before becoming available.
Migrations convert an old schema to the current schema. Reads, migrations, saves
and submissions can fail visibly. No silent reset on corrupt input occurs.

Submission takes a typed snapshot, disables edits and runs an application callback.
Only callback success permits draft deletion and reset. A deletion failure after
success has its own exception and locks resubmission. The package cannot solve
server idempotency or process termination during the submission/cleanup boundary.

The built-in persistent adapter uses shared_preferences and therefore inherits its
best-effort durability and platform requirements. For critical drafts, implement a
transactional database store. JSON encoding snapshots data before storage. Large
attachments and cross-device synchronization are outside this release.

Material bindings cover common inputs; the typed builder supports custom inputs.
Form initialization, recovery and error UI can be replaced with custom builders.
Synchronous cross-field rules revalidate after validation has first been requested.
Async server validation stays in the submit callback, with application-owned errors.

Future candidates: async validation with generation checks; optional encrypted or
transactional storage adapters; arrays/repeating groups; adapters for existing form
libraries. Add these only with lifecycle, migration and concurrency regression tests.
