// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated from native/include/pixer.h by tool/generate_bindings.dart.

/// Sampling filter used when resizing.
///
/// Quality and cost roughly increase from top to bottom; `Lanczos3` is the
/// default and produces the sharpest results, `Nearest` is the fastest.
enum FilterTypeEnum {
  /// Nearest-neighbour. Fastest, blocky output. Good for pixel art.
  Nearest(0),

  /// Linear (a.k.a. bilinear). Cheap, slightly blurry.
  Triangle(1),

  /// Catmull-Rom cubic. Sharper than `Triangle`, can ring on edges.
  CatmullRom(2),

  /// Gaussian. Soft output, useful for downscaling without aliasing.
  Gaussian(3),

  /// Lanczos with `a = 3`. Highest quality, slowest. Default.
  Lanczos3(4);

  final int value;
  const FilterTypeEnum(this.value);

  static FilterTypeEnum fromValue(int value) => switch (value) {
    0 => Nearest,
    1 => Triangle,
    2 => CatmullRom,
    3 => Gaussian,
    4 => Lanczos3,
    _ => throw ArgumentError('Unknown value for FilterTypeEnum: $value'),
  };
}

/// Error code returned through `out_error` pointers and as the result of
/// operations that don't return a handle.
enum ImageErrorCode {
  /// The operation succeeded.
  Success(0),

  /// The provided path is empty, malformed, or refers to a non-existent file.
  InvalidPath(1),

  /// The image format is not recognised or not supported by this build.
  UnsupportedFormat(2),

  /// The image bytes are corrupt or do not match the expected format.
  DecodingError(3),

  /// Encoding the image to the requested format failed.
  EncodingError(4),

  /// An underlying I/O operation (read/write) failed.
  IoError(5),

  /// Width, height, or crop bounds are zero or exceed the image.
  InvalidDimensions(6),

  /// A handle or output pointer was null, or the image has been freed.
  InvalidPointer(7),

  /// A scalar parameter (e.g. JPEG quality, blur sigma) is out of range.
  InvalidParameter(8),

  /// An unclassified error occurred.
  Unknown(99);

  final int value;
  const ImageErrorCode(this.value);

  static ImageErrorCode fromValue(int value) => switch (value) {
    0 => Success,
    1 => InvalidPath,
    2 => UnsupportedFormat,
    3 => DecodingError,
    4 => EncodingError,
    5 => IoError,
    6 => InvalidDimensions,
    7 => InvalidPointer,
    8 => InvalidParameter,
    99 => Unknown,
    _ => throw ArgumentError('Unknown value for ImageErrorCode: $value'),
  };
}

/// Image container format used for both decoding and encoding.
enum ImageFormatEnum {
  /// Portable Network Graphics — lossless, alpha supported.
  Png(0),

  /// JPEG — lossy, no alpha. Quality is configurable on encode.
  Jpeg(1),

  /// Graphics Interchange Format — palette-based, supports animation
  /// (single-frame only via this API).
  Gif(2),

  /// WebP — lossy or lossless, alpha supported.
  WebP(3),

  /// Windows Bitmap — uncompressed, large files.
  Bmp(4),

  /// Windows Icon — multi-resolution container.
  Ico(5),

  /// Tagged Image File Format — typically lossless.
  Tiff(6);

  final int value;
  const ImageFormatEnum(this.value);

  static ImageFormatEnum fromValue(int value) => switch (value) {
    0 => Png,
    1 => Jpeg,
    2 => Gif,
    3 => WebP,
    4 => Bmp,
    5 => Ico,
    6 => Tiff,
    _ => throw ArgumentError('Unknown value for ImageFormatEnum: $value'),
  };
}

/// Stable operation identifiers shared by the native and Dart batch APIs.
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

  final int value;
  const PixerOperationKind(this.value);

  static PixerOperationKind fromValue(int value) => switch (value) {
    0 => Resize,
    1 => ResizeExact,
    2 => Crop,
    3 => Rotate90,
    4 => Rotate180,
    5 => Rotate270,
    6 => FlipHorizontal,
    7 => FlipVertical,
    8 => Blur,
    9 => Brightness,
    10 => Contrast,
    11 => Grayscale,
    12 => Invert,
    _ => throw ArgumentError('Unknown value for PixerOperationKind: $value'),
  };
}
