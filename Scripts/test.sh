#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${HUE_BUILD_DIR:-$PROJECT_DIR/build}"
TEST_ARCH="${HUE_TEST_ARCH:-$(uname -m)}"
case "$TEST_ARCH" in
    arm64|x86_64) ;;
    *) echo "Unsupported test architecture: $TEST_ARCH" >&2; exit 1 ;;
esac
if ! /usr/bin/arch "-$TEST_ARCH" /usr/bin/true >/dev/null 2>&1; then
    echo "Cannot run $TEST_ARCH on this Mac. Intel tests on Apple Silicon require Rosetta to be installed." >&2
    exit 1
fi
TEST_DIR="$BUILD_DIR/tests/$TEST_ARCH"
mkdir -p "$BUILD_DIR/module-cache/$TEST_ARCH" "$TEST_DIR"
run_test() { /usr/bin/arch "-$TEST_ARCH" "$@"; }
xcrun swiftc -swift-version 5 -target "$TEST_ARCH-apple-macos13.0" \
    -module-cache-path "$BUILD_DIR/module-cache/$TEST_ARCH" \
    "$PROJECT_DIR/Sources/ImagePipeline.swift" "$PROJECT_DIR/Tests/ImagePipelineTests.swift" \
    -o "$TEST_DIR/image-pipeline-tests"
run_test "$TEST_DIR/image-pipeline-tests"
xcrun swiftc -swift-version 5 -target "$TEST_ARCH-apple-macos13.0" \
    -module-cache-path "$BUILD_DIR/module-cache/$TEST_ARCH" \
    "$PROJECT_DIR/Sources/DockGeometry.swift" "$PROJECT_DIR/Tests/DockGeometryTests.swift" \
    -o "$TEST_DIR/dock-geometry-tests"
run_test "$TEST_DIR/dock-geometry-tests"
xcrun swiftc -swift-version 5 -target "$TEST_ARCH-apple-macos13.0" \
    -module-cache-path "$BUILD_DIR/module-cache/$TEST_ARCH" \
    "$PROJECT_DIR/Sources/ImagePipeline.swift" "$PROJECT_DIR/Sources/CameraEngine.swift" \
    "$PROJECT_DIR/Sources/AppModel.swift" "$PROJECT_DIR/Sources/DockGeometry.swift" \
    "$PROJECT_DIR/Tests/CaptureFlowTests.swift" -o "$TEST_DIR/capture-flow-tests"
CAPTURE_TEST_DIR="$(mktemp -d "$TEST_DIR/capture-flow.XXXXXX")"
trap 'rm -rf "$CAPTURE_TEST_DIR"' EXIT
run_test "$TEST_DIR/capture-flow-tests" --demo --capture-directory "$CAPTURE_TEST_DIR"
echo "Tests passed for $TEST_ARCH (macOS 13 target)."
