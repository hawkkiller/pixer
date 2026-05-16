## 0.0.8

- Provide example and improve pubdev points.

## 0.0.7

- Added externalSize to the NativeFinalizer, which significantly improves Garbage Collection performance.

## 0.0.6

- **Breaking:** Merged `Pixer.encodeWith(PixerEncoder)` into `Pixer.encode(PixerEncoder)`; the old `encode(ImageFormatEnum)` overload is gone. Use `image.encode(const PixerPngEncoder())` etc.
- **Breaking:** Renamed `ColorType.l` / `ColorType.la` to `ColorType.luminance` / `ColorType.luminanceAlpha`. `ColorType.fromValue` now throws `ArgumentError` on unknown codes instead of defaulting to `rgba`.
- **Breaking:** Removed unused `LoadException` (load failures already throw specific exceptions).
- **Fixed:** `Pixer.contrast` docs: `0.0` is the neutral value (not `1.0`).
- **Docs:** Clarified `Pixer.resize` semantics (fits within the bounds; use `resizeExact` for exact sizes).
- **Docs:** Documented `Pixer.brightness` clamping and practical range.
- **Docs:** Added doc comments to all generated `FilterTypeEnum`, `ImageFormatEnum`, and `ImageErrorCode` variants via the Rust source.
- **Refactor:** Replaced `native_toolchain_rs` with `native_toolchain_rust`.
- **Refactor:** Simplified Rust code, removed `api.rs`.
- **Refactor:** Simplified encoder API and native implementation to keep only JPEG quality as a configurable encoding option.
- **Refactor:** Marked `PixerMetadata` `final`.

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
