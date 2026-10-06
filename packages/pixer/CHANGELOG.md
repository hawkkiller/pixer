## Unreleased

- Added `Pixer.probe(bytes)` and `Pixer.probeFile(path)`, which read an image's width, height, color type, and format without decoding its pixels. Width and height account for EXIF orientation, matching a loaded image. `PixerMetadata` gained a `format` field, set only by probing.
- **Breaking (native ABI 3):** Added `pixer_probe` and `pixer_probe_from_memory`, and appended a `format` field to `ImageMetadata`. Rebuild binaries for this package revision.

## 0.0.12

- Native binaries no longer include image codecs outside the supported formats (AVIF, EXR, HDR, QOI, TGA, DDS, PNM, Farbfeld), shrinking them by roughly 60% (macOS arm64: 4.9 MB to 1.8 MB). Auto-detected loading of those formats now throws `UnsupportedFormatException`.
- Added the `formats` hook user define to compile in only selected formats. Setting it builds the native library from source and requires a Rust toolchain.
- Resizing 8-bit images is 10–15x faster on native platforms: it now uses SIMD and splits large images across CPU cores (Apple M-series: 4K Lanczos3 upscale from 90 ms to 7 ms). 16-bit and floating-point images use the previous resizer.
- Resizing images with alpha now premultiplies alpha, so transparent pixels no longer bleed color into edges. Resized pixel values differ slightly from previous versions.
- **Breaking:** Loaded images are now rotated and flipped upright according to their EXIF orientation, so `width` and `height` are swapped for photos taken in portrait orientation. Malformed EXIF data is ignored.

## 0.0.11

- **Breaking:** Operations on `Pixer` (`resize`, `crop`, `blur`, ...) now return a lazy `PixerPipeline` instead of a new `Pixer`. Chain operations and finish with `encode`, `saveToFile`, or `toImage()`; the whole chain runs in one native call. Add `.toImage()` where a `Pixer` is still needed.
- **Breaking:** Removed `Pixer.batch()` and renamed `PixerBatch` to `PixerPipeline`. Pipelines are now immutable, so branching from a shared prefix no longer leaks operations between branches.
- **Breaking:** Image-dependent errors such as out-of-bounds `crop` are now thrown by the terminal call, not by the operation. Argument validation still happens when an operation is added.
- **Breaking:** Merged `Pixer.fromMemoryWithFormat(data, format)` into `Pixer.fromMemory(data, format: format)`.
- Exported `ImageErrorCode`, the type of `PixerException.code`.
- `encode` and `saveToFile` now run through the pipeline path, so native failures raise specific exceptions (e.g. `InvalidDimensionsException`) instead of `UnknownException`. Out-of-bounds `crop` is now reported by the native engine.
- Pipelines validate every operation before processing any pixels.
- Downloaded binaries are now verified with SHA-256 instead of MD5.
- **Breaking (native ABI 2):** Reduced the C API to `pixer_load`, `pixer_load_from_memory` (format or `PIXER_FORMAT_DETECT`), `pixer_get_metadata`, and the `pixer_batch_*` functions. Every fallible function returns an `ImageErrorCode` and writes results through out-parameters; formats are passed as validated `u32` values. Rebuild binaries for this package revision.

## 0.0.10

- Fixed zero blur changing pixels and rejected subnormal blur values before they can panic in Rust.
- Preserved alpha and bit depth in grayscale conversion and prevented extreme brightness offsets from overflowing.
- Accounted for actual native pixel-buffer bytes, including 16-bit and floating-point images.
- Added native/WASM ABI version checks and compile-time WASM layout checks. Rebuild binaries for this package revision.

- Added a minimal Flutter showcase for Android, iOS, Linux, macOS, Windows, and WebAssembly.
- Added browser support backed by the Rust engine compiled to WebAssembly.
- Added `Pixer.initialize()` for loading the WebAssembly module on web.
- Shared image validation, batching, encoder configuration, and error mapping across native and web backends.
- Encoding now belongs to the image backend; use `Pixer.encode(encoder)` instead of the FFI-only `PixerEncoder.encode(handle)` helper.
- **Breaking:** Renamed the native encoding symbols to `pixer_encode`, `pixer_encode_jpeg`, and `pixer_batch_encode`; the JPEG function no longer takes a redundant format argument.

## 0.0.9

- Fixed the workspace benchmark package path so analysis and publish validation run successfully.
- Added lazy operation batches with `toImage()`, `encode()`, and `saveToFile()` terminals.

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
