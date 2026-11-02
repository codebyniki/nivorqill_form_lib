# Validation — 1.0.0-rc.1

This is a release candidate for `1.0.0`, not a production certification. Native
storage and real process restart checks remain before a stable 1.0 release.

## Completed locally on 2 November 2026

| Check | Flutter 3.41.0 / Dart 3.11.0 | Flutter 3.47.8 / Dart 3.13.7 |
| --- | --- | --- |
| Dependency resolution | Passed | Passed |
| Static analysis | No issues | No issues |
| Library unit and widget tests | 34 passed | 34 passed |
| Example UI-flow test | 1 passed | 1 passed |
| Package line coverage | Not measured | 368 / 424 (86.8%) |
| Example web build | Not run | Passed; Wasm dry-run succeeded |

The minimum-SDK checks used an isolated copy with the same library and tests;
the package version field in that copy still identified the earlier beta. The
Flutter 3.47 web build compiled the release-candidate library before the version
metadata changed. Widget tests exercise custom loading, error and recovery views,
including retry and discard failure. Preferences adapter tests use a fake
`SharedPreferencesAsync`; they do not test native disk persistence.

A real Chromium launch was attempted but the browser exited in this restricted
container. No browser interaction or process-restart result is claimed. The web
build emitted a nonfatal optional Cupertino icon font warning; the Material example
built successfully.

The local Linux sandbox required process-metadata compatibility support for Dart,
including forwarding it to dependency build hooks. The package and delivered
source contain no compatibility shim or modified runtime. This is not a benchmark.

## Outstanding before stable 1.0

- Run the provided iOS and Android simulator integration jobs. They are configured
  but were not executed here; Xcode and Android emulators are unavailable.
- Test a full app termination and relaunch on iOS and Android. The integration
  test recreates a controller within one process and does not prove OS restart.
- Review API documentation, published name, license and real repository metadata.
- Inspect a fresh `flutter pub publish --dry-run` and complete an actual release
  only through an authorized pub.dev account.

See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for step-by-step device checks.
The built-in preferences adapter is unencrypted and its storage API does not
promise durability for critical data. Applications with stronger requirements
must provide an appropriate store and manage consent and retention.

## Publication dry-run

A clean copy of `1.0.0-rc.1` was checked with `flutter pub publish --dry-run`.
It reported no package errors and one optional warning for the missing repository
or homepage. Pub exits with code 65 for this warning. The actual publication is
not performed by this command, and the name remains unreserved.
