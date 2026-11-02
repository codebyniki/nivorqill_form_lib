# Try Nivorquill Form Lib

1. Install Flutter 3.41+ (the supplied example hosts were generated with 3.47.8).
2. Extract this ZIP and enter nivorquill_form_lib.
3. Run `flutter pub get`, `flutter analyze`, and `flutter test`.
4. Enter example, run `flutter pub get`, then `flutter run` and choose your device.
5. Enter a listing, wait for Saved locally, close/reopen, and choose Restore.
6. Try Submit with empty fields, then submit valid input. Submission is simulated
   locally; successful submission resets the fields and deletes the saved draft.
7. Run `flutter test test` inside example for its automated UI-flow check.

The API is a 1.0 release candidate. Read README.md for installation in your app, storage privacy,
custom fields, migration, lifecycle and server-idempotency requirements. Actual
executed checks and remaining platform tests are recorded in doc/VALIDATION.md.

For local application installation, use a path dependency pointing at the
extracted package folder. No pub.dev upload has been performed.
