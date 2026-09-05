/// Pixel layout of an image: which channels are present.
enum ColorType {
  luminance(0),
  luminanceAlpha(1),
  rgb(2),
  rgba(3);

  const ColorType(this.value);
  final int value;

  static ColorType fromValue(int value) => switch (value) {
    0 => luminance,
    1 => luminanceAlpha,
    2 => rgb,
    3 => rgba,
    _ => throw ArgumentError('Unknown value for ColorType: $value'),
  };
}

/// Width, height, and color layout of an image.
final class PixerMetadata {
  const PixerMetadata({
    required this.width,
    required this.height,
    required this.colorType,
  });

  final int width;
  final int height;
  final ColorType colorType;

  @override
  String toString() =>
      'PixerMetadata(width: $width, height: $height, colorType: ${colorType.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PixerMetadata &&
          width == other.width &&
          height == other.height &&
          colorType == other.colorType;

  @override
  int get hashCode => Object.hash(width, height, colorType);
}
