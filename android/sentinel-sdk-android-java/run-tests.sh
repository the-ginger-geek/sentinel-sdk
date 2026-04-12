#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build/manual-test"
mkdir -p "$BUILD_DIR"

find "$ROOT_DIR/src/main/java" -name '*.java' > "$BUILD_DIR/main-sources.txt"
find "$ROOT_DIR/src/test/java" -name '*.java' > "$BUILD_DIR/test-sources.txt"

javac -d "$BUILD_DIR" @"$BUILD_DIR/main-sources.txt" @"$BUILD_DIR/test-sources.txt"
java -cp "$BUILD_DIR" com.thegingergeek.sentinel.SentinelClientTest
