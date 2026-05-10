## Unreleased

- refactor: replace native_toolchain_rs with native_toolchain_rust.
- refactor: simplify Rust code, remove api.rs.
- Simplified encoder API and native implementation to keep only JPEG quality as a configurable encoding option.

## 0.0.5

- **Breaking:** Replaced `Pixer.encode(ImageFormatEnum, {quality})` with encoder objects.
- Added `PixerJpegEncoder(quality: ...)` with validation.

## 0.0.4

- Added JPEG quality support to `Pixer.encode()` via `quality`.
- Improved binding generation to resolve the active macOS SDK with `xcrun`.

## 0.0.3

- Fixed build hook for web platform.

## 0.0.2

- **Breaking:** `invert()` now returns a new `Pixer` instead of mutating in-place.
- **Breaking:** Removed deprecated `resizeToFit()` method (use `resize()` instead).
- **Breaking:** Renamed FFI functions to align with Rust image crate conventions:
  - `encode` -> `write_to`
  - `crop` -> `crop_imm`
  - `rotate_90/180/270` -> `rotate90/180/270`
  - `flip_horizontal/vertical` -> `fliph/flipv`
  - `brightness` -> `brighten`
  - `contrast` -> `adjust_contrast`
- Added metadata caching to avoid redundant FFI calls for `width`, `height`, `colorType`.
- Added bounds validation for `crop()` - now throws `InvalidDimensionsException` if crop rectangle exceeds image bounds.
- Added hash verification for native assets.
- Added `generate_bindings.sh` script to automate cbindgen + ffigen workflow.
- Improved error handling in load functions - now throws specific exceptions (`IoException`, `DecodingException`, `UnsupportedFormatException`) instead of generic `LoadException`.
- Improved documentation for `blur()` method.

## 0.0.1

- Finalized the Dart API with typed exceptions.
- Added context to exceptions for clearer error messages.
- Added a finalizer and `isDisposed` for safer resource handling.
