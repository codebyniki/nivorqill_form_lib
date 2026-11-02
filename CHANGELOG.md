# 1.0.0

- Add a calendar date-only codec and customizable Material text input options.
- Avoid draft writes for edits to non-persisted fields and ignore empty recovery candidates.
- Document the public API, safe navigation saves and application-level async validation.
- Native restart and device verification remain as described in the release checklist.

# 1.0.0-rc.1

- Add customizable loading, draft-recovery and initialization-error builders.
- Add widget coverage for custom recovery, error handling and retry.
- Add preferences-adapter tests and native storage integration CI jobs.
- Prepare the public API for 1.0.0; native device and real-restart checks remain.

# 0.1.0-beta.2

- **Breaking:** rename the public form widgets, controller, fields, codecs,
  validators and values to the `Nivorquill` prefix. Draft-specific storage and
  recovery types retain their existing names, and saved data remains compatible.

# 0.1.0-beta.1

Initial implementation of Nivorquill Form Lib: typed Flutter forms with local draft recovery.

- Typed fields, JSON codecs, field and cross-field validation.
- Text, dropdown, checkbox and arbitrary custom widget bindings.
- Explicit opt-in persistence, debounced autosave and visible save errors.
- Consent-based recovery, expiration, schema migration and user-scoped keys.
- Serialized writes and discard protection against stale pending saves.
- Submission guards and explicit handling of post-submission cleanup failures.
- Memory and asynchronous preferences adapters, example and regression tests.
