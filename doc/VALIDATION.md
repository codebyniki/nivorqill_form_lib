# Validation — 1.0.0

The 1.0.0 release is prepared locally. Native storage and real process restart
checks below remain outstanding; passing local tests is not a production certification.

## Current local checks

On 2 November 2026, Flutter 3.44.8 / Dart 3.12.2 passed formatting, analysis,
38 library tests, the example test, and a clean-tree publication dry run with
zero warnings. Controller tests also passed with `TZ=Pacific/Honolulu` and
`TZ=Pacific/Kiritimati`; these tests save and restore within each time zone, not
across processes or devices. These results preceded the documentation-only release
updates; rerun `bash tool/validate.sh` for the exact release commit.

## Earlier release-candidate checks

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

## Remaining verification

- Run the provided iOS and Android simulator integration jobs. They are configured
  but were not executed here; Xcode and Android emulators are unavailable.
- Test a full app termination and relaunch on iOS and Android. The integration
  test recreates a controller within one process and does not prove OS restart.
- Inspect a fresh `flutter pub publish --dry-run` and complete an actual release
  only through an authorized pub.dev account.

See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for step-by-step device checks.
The built-in preferences adapter is unencrypted and its storage API does not
promise durability for critical data. Applications with stronger requirements
must provide an appropriate store and manage consent and retention.

## Publication dry-run

The dry run validates the archive but does not publish it or reserve the name.
Publishing requires an authorized pub.dev account.
