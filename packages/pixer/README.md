# Pixer

Fast, cross-platform image manipulation for Dart, powered by Rust via FFI.

## Installation

```yaml
dependencies:
  pixer: ^0.0.12
```

Native binaries are downloaded automatically via Dart build hooks.

Native and WebAssembly binaries must match the package's ABI version. Pixer
checks this before loading images (or during `initialize`) and throws a
`StateError` for missing or incompatible ABI versions. Rebuild or download the
matching binary when upgrading; replace any cached `pixer.wasm` as well.

## Quick Start

```dart
import 'package:pixer/pixer.dart';

final image = Pixer.fromFile('input.jpg');
image.resize(800, 600).grayscale().saveToFile('output.png');
image.dispose();
```

## WebAssembly

Download `pixer.wasm` from the matching GitHub release into your app's web
root, then initialize Pixer before loading images:

```dart
await Pixer.initialize(); // Fetches pixer.wasm relative to the page.
final image = Pixer.fromMemory(bytes);
```

You can instead pass `wasmUri` or `wasmBytes` to `initialize`. For local
development of this repository, build the module with:

```bash
dart packages/pixer/tool/build_wasm.dart web/pixer.wasm
```

Browser builds support the byte-based API. `fromFile` and `saveToFile` throw
`UnsupportedError`; use `fromMemory` and `encode` instead. The web implementation is compatible with both `dart2js`
and Dart/Flutter Wasm builds.

## Loading Images

```dart
// From file (format auto-detected)
final image = Pixer.fromFile('photo.jpg');

// From memory
final bytes = await File('photo.png').readAsBytes();
final image = Pixer.fromMemory(bytes);

// From memory with explicit format
final image = Pixer.fromMemory(bytes, format: ImageFormatEnum.Png);
```

## Supported Formats

PNG, JPEG, GIF, WebP, BMP, ICO, TIFF

To ship a smaller native binary, list only the formats you need in your app's
`pubspec.yaml`. Pixer then builds the native library from source, which
requires a [Rust toolchain](https://rustup.rs):

```yaml
hooks:
  user_defines:
    pixer:
      formats: [jpeg, png]
```

Using a format that is not enabled throws `UnsupportedFormatException`.
`ico` also enables `bmp` and `png`. This setting does not affect web builds,
which use the prebuilt `pixer.wasm`.

## Pipelines

Operations on a `Pixer` return a lazy `PixerPipeline`. Chain as many
operations as you need, then finish with a terminal:

```dart
final bytes = image
    .resize(800, 600)
    .grayscale()
    .encode(PixerJpegEncoder(quality: 85)); // bytes

image.crop(10, 10, 200, 200).rotate90().saveToFile('crop.png'); // file

final thumb = image.resize(320, 240).toImage(); // new Pixer
thumb.dispose();
```

The whole chain runs in a single native call, intermediates stay inside Rust,
and the source `Pixer` is never modified, so one decoded image can feed many
pipelines. Pipelines are immutable and safe to branch:

```dart
final base = image.resize(800, 600);
final gray = base.grayscale().encode(const PixerPngEncoder());
final blurred = base.blur(2).encode(const PixerPngEncoder()); // no grayscale
```

Arguments are validated as each operation is added. Checks that depend on the
image, such as crop bounds, run against the preceding operation's output when
the terminal is called.

## Image Operations

```dart
// Resize to fit within 800x600, preserving aspect ratio
image.resize(800, 600);

// Resize to exactly 800x600 (may distort)
image.resizeExact(800, 600);

// Crop (x, y, width, height)
image.crop(100, 100, 400, 300);

// Rotate
image.rotate90();
image.rotate180();
image.rotate270();

// Flip
image.flipHorizontal();
image.flipVertical();

// Adjustments
image.blur(2.5);       // Gaussian blur, sigma in pixels
image.brightness(30);  // Add to each channel; clamps to [0, 255]
image.contrast(20);    // 0 = unchanged, positive boosts, negative flattens
image.grayscale();     // Preserves alpha and bit depth
image.invert();
```

Every operation is also available on `PixerPipeline`, so they chain freely.
`blur(0)` leaves the image unchanged. Positive blur values must fit a normal
32-bit float; subnormal values are rejected with `ArgumentError`.

### Resize Filters

```dart
image.resize(800, 600, filter: FilterTypeEnum.Lanczos3);  // Default, high quality
image.resize(800, 600, filter: FilterTypeEnum.Nearest);   // Fastest, pixelated
image.resize(800, 600, filter: FilterTypeEnum.Triangle);  // Bilinear
image.resize(800, 600, filter: FilterTypeEnum.CatmullRom);
image.resize(800, 600, filter: FilterTypeEnum.Gaussian);
```

## Saving & Encoding

`Pixer` and `PixerPipeline` share the same terminals.

```dart
// Save to file (format from extension)
image.saveToFile('output.webp');

// Encode to bytes
final pngBytes = image.encode(const PixerPngEncoder());
final jpegBytes = image.encode(PixerJpegEncoder(quality: 90));
final webpBytes = image.encode(const PixerWebPEncoder());
```

`encode` accepts any [`PixerEncoder`](lib/src/pixer_encoder.dart): `PixerPngEncoder`, `PixerJpegEncoder`, `PixerGifEncoder`, `PixerWebPEncoder`, `PixerBmpEncoder`, `PixerIcoEncoder`, `PixerTiffEncoder`. Only `PixerJpegEncoder` currently has tunable options (`quality`, 1–100).

## Metadata

```dart
final meta = image.getMetadata();
print('${meta.width}x${meta.height}, ${meta.colorType}');

// Or directly:
print('${image.width}x${image.height}');
```

## Resource Management

Every `Pixer` owns a Rust handle: the one you load and every `toImage()` result.
Call `dispose()` when done. Pipelines own no native memory and need no disposal.
Native builds assign a finalizer that frees the handle when the object is garbage collected,
but finalizers are not guaranteed to run. Web builds require explicit disposal.

```dart
final image = Pixer.fromFile('input.jpg');
try {
  image.resize(800, 600).saveToFile('out.jpg');
} finally {
  image.dispose();
}
```

## Error Handling

All errors throw typed `PixerException` subclasses:

| Exception | Cause |
|-----------|-------|
| `InvalidPathException` | Empty or invalid file path |
| `IoException` | File read/write failure |
| `DecodingException` | Cannot decode image data |
| `EncodingException` | Cannot encode to format |
| `UnsupportedFormatException` | Format not supported |
| `InvalidDimensionsException` | Invalid width/height/crop bounds |
| `InvalidPointerException` | Image already disposed |
| `InvalidParameterException` | Scalar out of range (e.g. JPEG quality) |
| `UnknownException` | Unclassified native error |

## Platforms

Linux, macOS, Windows, Android, iOS, Web (WebAssembly)

## Roadmap

### Current (v0.0.x)
- [x] Load/save: PNG, JPEG, GIF, WebP, BMP, ICO, TIFF
- [x] Resize (aspect-ratio-preserving & exact) with 5 filter types
- [x] Crop, rotate (90/180/270), flip (H/V)
- [x] Adjustments: blur, brightness, contrast, grayscale, invert
- [x] Metadata access (width, height, color type)
- [x] Encoder objects with JPEG quality support
- [x] Lazy pipelines with image, byte, and file outputs
- [x] Full platform support (Linux, macOS, Windows, Android, iOS)
- [x] Web support through the Rust WebAssembly build

### Planned — `image` crate
- [ ] Hue rotation
- [ ] Sharpen / unsharp mask
- [ ] Thumbnail generation (optimized fast path)
- [ ] Create blank images (solid color, transparent)
- [ ] Composite images (overlay one image onto another at x, y)
- [ ] Tiling
- [ ] Animated GIF/WebP frame-level control

### Planned — requires `imageproc`
- [ ] Arbitrary angle rotation
- [ ] Blend modes (multiply, screen, overlay, etc.)
- [ ] Draw primitives (rectangles, circles, lines)
- [ ] Text rendering onto images
- [ ] Edge detection (Canny, Sobel)
- [ ] Content-aware resize (seam carving)

### Planned — requires other crates
- [ ] EXIF metadata read/write/preserve (e.g. `kamadak-exif`)
- [ ] Stitch images (horizontal/vertical concat, grid layout)
- [ ] Watermarking

### Exploring
- [ ] Advanced color adjustments (saturation, gamma, curves)
- [ ] GPU acceleration
