import 'dart:ffi' as ffi;
import 'bindings/bindings.dart';

/// Image color type
enum ColorType {
  /// Grayscale
  l(0),

  /// Grayscale with alpha
  la(1),

  /// RGB
  rgb(2),

  /// RGBA
  rgba(3);

  const ColorType(this.value);

  final int value;

  static ColorType fromValue(int value) => switch (value) {
    0 => l,
    1 => la,
    2 => rgb,
    3 => rgba,
    _ => rgba, // Default to RGBA
  };
}

/// Metadata about an image
class PixerMetadata {
  const PixerMetadata({required this.width, required this.height, required this.colorType});

  /// Image width in pixels
  final int width;

  /// Image height in pixels
  final int height;

  /// Color type
  final ColorType colorType;

  /// Creates metadata from native struct
  factory PixerMetadata.fromNative(ffi.Pointer<ImageMetadata> ptr) {
    final metadata = ptr.ref;
    return PixerMetadata(
      width: metadata.width,
      height: metadata.height,
      colorType: ColorType.fromValue(metadata.color_type),
    );
  }

  @override
  String toString() =>
      'PixerMetadata(width: $width, height: $height, colorType: ${colorType.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PixerMetadata &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          colorType == other.colorType;

  @override
  int get hashCode => Object.hash(width, height, colorType);
}
