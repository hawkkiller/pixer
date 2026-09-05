/// Sampling filter used when resizing.
enum FilterTypeEnum {
  Nearest(0),
  Triangle(1),
  CatmullRom(2),
  Gaussian(3),
  Lanczos3(4);

  const FilterTypeEnum(this.value);
  final int value;

  static FilterTypeEnum fromValue(int value) => values.firstWhere(
    (filter) => filter.value == value,
    orElse: () => throw ArgumentError('Unknown FilterTypeEnum value: $value'),
  );
}

/// Error codes shared by the native and WebAssembly APIs.
enum ImageErrorCode {
  Success(0),
  InvalidPath(1),
  UnsupportedFormat(2),
  DecodingError(3),
  EncodingError(4),
  IoError(5),
  InvalidDimensions(6),
  InvalidPointer(7),
  InvalidParameter(8),
  Unknown(99);

  const ImageErrorCode(this.value);
  final int value;

  static ImageErrorCode fromValue(int value) => values.firstWhere(
    (code) => code.value == value,
    orElse: () => throw ArgumentError('Unknown ImageErrorCode value: $value'),
  );
}

/// Image container format used for decoding and encoding.
enum ImageFormatEnum {
  Png(0),
  Jpeg(1),
  Gif(2),
  WebP(3),
  Bmp(4),
  Ico(5),
  Tiff(6);

  const ImageFormatEnum(this.value);
  final int value;

  static ImageFormatEnum fromValue(int value) => values.firstWhere(
    (format) => format.value == value,
    orElse: () => throw ArgumentError('Unknown ImageFormatEnum value: $value'),
  );
}

/// Stable operation identifiers shared by Dart and Rust batches.
enum PixerOperationKind {
  Resize(0),
  ResizeExact(1),
  Crop(2),
  Rotate90(3),
  Rotate180(4),
  Rotate270(5),
  FlipHorizontal(6),
  FlipVertical(7),
  Blur(8),
  Brightness(9),
  Contrast(10),
  Grayscale(11),
  Invert(12);

  const PixerOperationKind(this.value);
  final int value;

  static PixerOperationKind fromValue(int value) => values.firstWhere(
    (kind) => kind.value == value,
    orElse: () =>
        throw ArgumentError('Unknown PixerOperationKind value: $value'),
  );
}
