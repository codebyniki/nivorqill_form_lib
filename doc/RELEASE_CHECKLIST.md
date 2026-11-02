# 1.0 release checklist

Version `1.0.0` is prepared locally. The checks below record what still needs
verification before relying on the package for production.

## Automated checks

1. Run `bash tool/validate.sh`, including the publication dry-run.
2. Push this source to your GitHub repository and run **Validate form library**.
   The workflow covers Flutter 3.41/current stable, web build, iOS simulator and
   Android emulator preferences integration. Those CI jobs have not yet run here.
3. Record the Flutter/Xcode/Android versions and attach the successful run to the
   release notes. If any check fails, fix it and rerun rather than skipping it.

## Real restart checks

The integration test creates a second controller in one process; it does **not**
prove that an OS termination and relaunch works. On iOS and Android:

1. Run `example` on a simulator or device. Fill title, description and category;
   wait until the screen shows `Saved locally`.
2. Terminate the app completely and relaunch it. Choose **Restore draft** and
   verify all three values return; confirm the checkbox is unchecked.
3. Edit the form, wait for the saved indicator, close and reopen again. Choose
   **Discard draft**, relaunch, and verify that old values do not return.
4. Fill a valid listing, tick the checkbox and submit. Verify that fields clear,
   then restart and confirm no prior draft is offered.
5. Repeat with airplane mode enabled. The sample does not require a server;
   production apps must test their own submission and idempotency behavior.

If a step fails, capture the first error, device/OS version, and reproduction
steps. Do not include personal form contents or credentials in a public issue.

## Stable release

After the checks pass and you accept the public API, rerun the checks and
`flutter pub publish --dry-run`.
Review the package name, license, real repository/homepage metadata, and generated
file list. Publishing uses your own authorized pub.dev account:

```sh
flutter pub publish
```

A release candidate is a prerelease and pub.dev does not list prereleases in
search results. A stable `1.0.0` release has different discovery behavior.
