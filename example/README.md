# Example

Generate host projects with your installed Flutter SDK, then run the local demo:

```sh
flutter create --platforms=android,ios,web --project-name=nivorquill_form_lib_example .
flutter pub get
flutter run
```

Enter a listing, wait for Saved locally, restart, and choose Restore. Acceptance
is deliberately not persisted. Submission is simulated locally; no server is used.

To test storage on a real platform, run the integration test with a device ID:
`flutter test integration_test/storage_test.dart -d <device-id>`.
