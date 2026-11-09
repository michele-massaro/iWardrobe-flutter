#!/usr/bin/env bash
# Commit gate for iWardrobe (Docs/architecture.md, §Code quality).
#
# Runs the checklist in order and exits non-zero on the first failure:
#   1. dart run build_runner build --delete-conflicting-outputs
#   2. dart format lib test
#   3. dart analyze
#   4. flutter test
set -euo pipefail

# Flutter is not on the default PATH on this machine; fall back to the known
# SDK location so the gate can be invoked from any shell.
if ! command -v flutter >/dev/null 2>&1; then
  export PATH="$PATH:/Users/michele/Development/Flutter/SDK/flutter/bin"
fi

cd "$(dirname "$0")/.."

dart run build_runner build --delete-conflicting-outputs
dart format lib test
dart analyze
flutter test
