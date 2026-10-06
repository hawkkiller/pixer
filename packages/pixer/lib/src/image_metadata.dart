import 'enums.dart';

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

/// Width, height, color layout, and (when probed) container format of an image.
final class PixerMetadata {
  const PixerMetadata({
    required this.width,
    required this.height,
    required this.colorType,
    this.format,
  });

  final int width;
  final int height;
  final ColorType colorType;

  /// The container format detected by [Pixer.probe] or [Pixer.probeFile];
  /// null for decoded images, which no longer have one.
  final ImageFormatEnum? format;

  @override
  String toString() =>
      'PixerMetadata(width: $width, height: $height, colorType: ${colorType.name}'
      '${format == null ? '' : ', format: ${format!.name}'})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PixerMetadata &&
          width == other.width &&
          height == other.height &&
          colorType == other.colorType &&
          format == other.format;

  @override
  int get hashCode => Object.hash(width, height, colorType, format);
}

/// Builds metadata from the native `ImageMetadata` fields.
PixerMetadata metadataFromNative(
  int width,
  int height,
  int colorType,
  int format,
) => PixerMetadata(
  width: width,
  height: height,
  colorType: ColorType.fromValue(colorType),
  format: format == PIXER_FORMAT_UNKNOWN
      ? null
      : ImageFormatEnum.fromValue(format),
);
