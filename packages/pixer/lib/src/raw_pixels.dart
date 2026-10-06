import 'dart:typed_data';

/// Byte order of 8-bit pixels passed to `Pixer.fromPixels`.
///
/// Must match `PixelLayout` in native/src/ffi.rs.
enum PixelLayout {
  /// Red, green, blue, alpha; 4 bytes per pixel.
  rgba8(0, 4),

  /// Red, green, blue; 3 bytes per pixel.
  rgb8(1, 3),

  /// Blue, green, red, alpha; 4 bytes per pixel, as produced by many camera
  /// and platform APIs. Stored as RGBA.
  bgra8(2, 4),

  /// Luminance; 1 byte per pixel.
  gray8(3, 1);

  const PixelLayout(this.value, this.bytesPerPixel);

  /// ABI value passed to the native engine.
  final int value;

  /// Number of bytes each pixel occupies.
  final int bytesPerPixel;
}

/// 8-bit RGBA pixels, row-major with no row padding.
///
/// [bytes] holds `width * height * 4` bytes, the layout
/// `ui.decodeImageFromPixels` expects with `ui.PixelFormat.rgba8888`.
final class RawPixels {
  const RawPixels(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;

  @override
  String toString() =>
      'RawPixels(width: $width, height: $height, bytes: ${bytes.length})';
}
