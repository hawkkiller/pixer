# Pixer

Fast, cross-platform image manipulation for Dart, powered by Rust via FFI.

## Installation

```yaml
dependencies:
  pixer: ^0.0.8
```

Native binaries are downloaded automatically via Dart build hooks.

## Quick Start

```dart
import 'package:pixer/pixer.dart';

final image = Pixer.fromFile('input.jpg');
final result = image.resize(800, 600);
result.saveToFile('output.png');
result.dispose();
image.dispose();
```

## Loading Images

```dart
// From file (format auto-detected)
final image = Pixer.fromFile('photo.jpg');

// From memory
final bytes = await File('photo.png').readAsBytes();
final image = Pixer.fromMemory(bytes);

// From memory with explicit format
final image = Pixer.fromMemoryWithFormat(bytes, ImageFormatEnum.Png);
```

## Supported Formats

PNG, JPEG, GIF, WebP, BMP, ICO, TIFF

## Image Operations

All operations return a **new** `Pixer` instance; the original is unchanged.

```dart
// Resize to fit within 800x600, preserving aspect ratio
final resized = image.resize(800, 600);

// Resize to exactly 800x600 (may distort)
final stretched = image.resizeExact(800, 600);

// Crop (x, y, width, height)
final cropped = image.crop(100, 100, 400, 300);

// Rotate
final r90 = image.rotate90();
final r180 = image.rotate180();
final r270 = image.rotate270();

// Flip
final hFlip = image.flipHorizontal();
final vFlip = image.flipVertical();

// Adjustments
final blurred = image.blur(2.5);       // Gaussian blur, sigma in pixels
final bright = image.brightness(30);   // Add to each channel; clamps to [0, 255]
final punchier = image.contrast(20);   // 0 = unchanged, positive boosts, negative flattens
final gray = image.grayscale();
final inverted = image.invert();
```

### Resize Filters

```dart
image.resize(800, 600, filter: FilterTypeEnum.Lanczos3);  // Default, high quality
image.resize(800, 600, filter: FilterTypeEnum.Nearest);   // Fastest, pixelated
image.resize(800, 600, filter: FilterTypeEnum.Triangle);  // Bilinear
image.resize(800, 600, filter: FilterTypeEnum.CatmullRom);
image.resize(800, 600, filter: FilterTypeEnum.Gaussian);
```

## Saving & Encoding

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

Every `Pixer` owns a native handle. Call `dispose()` when done — including intermediates in a pipeline.
Each pixer is assigned a finalizer, which frees the native handle when the pixer is garbage collected.
However, the finalizer is not guaranteed to run, especially across isolates. It is **strongly recommended** to call `dispose()` explicitly.

```dart
final image = Pixer.fromFile('input.jpg');
try {
  final resized = image.resize(800, 600);
  try {
    resized.saveToFile('out.jpg');
  } finally {
    resized.dispose();
  }
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

Linux, macOS, Windows, Android, iOS

## Roadmap

### Current (v0.0.x)
- [x] Load/save: PNG, JPEG, GIF, WebP, BMP, ICO, TIFF
- [x] Resize (aspect-ratio-preserving & exact) with 5 filter types
- [x] Crop, rotate (90/180/270), flip (H/V)
- [x] Adjustments: blur, brightness, contrast, grayscale, invert
- [x] Metadata access (width, height, color type)
- [x] Encoder objects with JPEG quality support
- [x] Full platform support (Linux, macOS, Windows, Android, iOS)

### Planned — `image` crate
- [ ] Hue rotation
- [ ] Sharpen / unsharp mask
- [ ] Thumbnail generation (optimized fast path)
- [ ] Create blank images (solid color, transparent)
- [ ] Composite images (overlay one image onto another at x, y)
- [ ] Tiling
- [ ] Animated GIF/WebP frame-level control
- [ ] Batch processing API

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
