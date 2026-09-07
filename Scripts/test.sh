#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${HUE_BUILD_DIR:-$PROJECT_DIR/build}"
mkdir -p "$BUILD_DIR/module-cache"
xcrun swiftc -swift-version 5 -target arm64-apple-macos26.0 \
    -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR/Sources/ImagePipeline.swift" "$PROJECT_DIR/Tests/ImagePipelineTests.swift" \
    -o "$BUILD_DIR/image-pipeline-tests"
"$BUILD_DIR/image-pipeline-tests"
xcrun swiftc -swift-version 5 -target arm64-apple-macos26.0 \
    -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR/Sources/DockGeometry.swift" "$PROJECT_DIR/Tests/DockGeometryTests.swift" \
    -o "$BUILD_DIR/dock-geometry-tests"
"$BUILD_DIR/dock-geometry-tests"
xcrun swiftc -swift-version 5 -target arm64-apple-macos26.0 \
    -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR/Sources/ImagePipeline.swift" "$PROJECT_DIR/Sources/CameraEngine.swift" \
    "$PROJECT_DIR/Sources/AppModel.swift" "$PROJECT_DIR/Sources/DockGeometry.swift" \
    "$PROJECT_DIR/Tests/CaptureFlowTests.swift" -o "$BUILD_DIR/capture-flow-tests"
CAPTURE_TEST_DIR="$(mktemp -d "$BUILD_DIR/capture-flow.XXXXXX")"
trap 'rm -rf "$CAPTURE_TEST_DIR"' EXIT
"$BUILD_DIR/capture-flow-tests" --demo --capture-directory "$CAPTURE_TEST_DIR"
