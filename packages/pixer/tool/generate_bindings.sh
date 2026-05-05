#!/bin/bash
# Generate FFI bindings from Rust code
# Usage: ./tool/generate_bindings.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
NATIVE_DIR="$PROJECT_ROOT/native"
HEADER_FILE="$PACKAGE_DIR/native/include/pixer.h"

echo "Generating C header from Rust code..."

# Run cbindgen from the native directory
cd "$NATIVE_DIR"
cbindgen --config cbindgen.toml --crate pixer --output "$HEADER_FILE"

echo "Header generated: $HEADER_FILE"

echo "Generating Dart FFI bindings..."

# Run ffigen from the package directory
cd "$PACKAGE_DIR"
if SDK_PATH=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null); then
  dart run ffigen --config ffigen.yaml --compiler-opts "-isysroot $SDK_PATH"
else
  dart run ffigen --config ffigen.yaml
fi

echo "Done! Bindings generated successfully."
