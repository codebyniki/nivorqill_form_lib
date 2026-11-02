# Feature guide

| Feature | Support and limits |
| --- | --- |
| Typed fields and snapshots | JSON-compatible codecs, nullable values and detached snapshots. |
| Validation | Synchronous field and cross-field rules; remote checks remain application-owned. |
| Material and custom fields | Text, dropdown, checkbox and a typed builder; applications can build additional widgets. |
| Drafts | Opt-in fields, debounce, explicit recovery, expiration and schema migration. Empty recovery candidates are ignored. |
| Storage | Memory and unencrypted shared preferences; custom `DraftStore` for stronger requirements. |
| Submission | Editing is frozen; failed callbacks retain input; cleanup failure is reported separately. |
| Calendar dates | Date-only calendar components and UTC-instant DateTime codecs have distinct semantics. |
| Lifecycle | Explicit awaited flush; backgrounding and disposal do not guarantee a final write. |
| Coordination | One active controller per key; cross-process conflict resolution is application-owned. |
| Native persistence | Integration tests exist; device and full process-restart checks are tracked in [validation](VALIDATION.md). |

See the [API guide](API.md) and [README](../README.md) for details and examples.
