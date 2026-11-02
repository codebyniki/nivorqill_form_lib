#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
(cd example && flutter pub get)
dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test
flutter analyze --fatal-infos
flutter test --coverage
(cd example && flutter test test)
log_file=$(mktemp)
trap 'rm -f "$log_file"' EXIT
status=0
flutter pub publish --dry-run > "$log_file" 2>&1 || status=$?
cat "$log_file"
if [ "$status" -ne 0 ]; then
  if [ "$status" -ne 65 ] || ! grep -Fxq 'Package has 1 warning.' "$log_file" || ! grep -Fq 'include a "homepage" or "repository" field' "$log_file"; then
    exit "$status"
  fi
  printf '%s\n' 'No publication errors; repository/homepage is not configured.'
fi
