#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"
echo "Running Swift tests..."
swift test

echo "Running JavaScript tests..."
(cd js/sentinel-sdk-js && node --test)

echo "Running Android Java tests..."
(cd android/sentinel-sdk-android-java && ./run-tests.sh)

echo "All SDK tests passed"
