import 'dart:typed_data';

import 'backend_native.dart'
    if (dart.library.js_interop) 'web/backend_web.dart';
import 'enums.dart';
import 'image_metadata.dart';
import 'image_operation.dart';
import 'pixer_encoder.dart';
import 'pixer_exception.dart';

part 'pixer_batch.dart';

/// A loaded image, backed by Rust on native and web platforms.
///
/// Operations like [resize], [crop], [blur], and so on each return a new
/// [Pixer]; the original is unchanged. Encode with [encode] or save with
/// [saveToFile].
///
/// ## Memory management
///
/// Every [Pixer] owns a Rust image. Call [dispose] when you're done with
/// it — including intermediates in a pipeline. Native finalizers provide a safety
/// net but are not guaranteed to run (especially across isolates), so explicit
/// disposal is the only reliable strategy.
///
/// Example:
/// ```dart
/// final image = Pixer.fromFile('input.jpg');
/// final resized = image.resize(800, 600);
/// resized.saveToFile('output.jpg');
/// resized.dispose();
/// image.dispose();
/// ```
final class Pixer {
  static const _maxUint32 = 0xFFFFFFFF;
  static const _minInt32 = -0x80000000;
  static const _maxInt32 = 0x7FFFFFFF;
  static const _maxFloat32 = 3.4028234663852886e38;

  Pixer._(this._backend);
  final BackendImage _backend;
  bool _isDisposed = false;
  PixerMetadata? _cachedMetadata;

  /// Loads the WASM module on web; native platforms are ready immediately.
  /// Pass [wasmBytes] or [wasmUri], or serve pixer.wasm beside the web page.
  static Future<void> initialize({Uint8List? wasmBytes, Uri? wasmUri}) =>
      BackendImage.initialize(wasmBytes: wasmBytes, wasmUri: wasmUri);

  /// Whether the native resources have been disposed.
  bool get isDisposed => _isDisposed;

  /// Loads an image from a file path
  ///
  /// Throws [InvalidPathException] if the path is empty or invalid.
  /// Throws [IoException] if the file cannot be read.
  /// Throws [DecodingException] if the image format cannot be decoded.
  /// Throws [UnsupportedFormatException] if the format is not supported.
  /// Throws [UnsupportedError] on web; use [Pixer.fromMemory] instead.
  factory Pixer.fromFile(String path) {
    if (path.trim().isEmpty) throw InvalidPathException('path is empty');
    return Pixer._(BackendImage.fromFile(path));
  }

  /// Loads an image from a byte buffer
  ///
  /// Throws [DecodingException] if the buffer is empty or cannot be decoded.
  /// Throws [UnsupportedFormatException] if the format is not supported.
  factory Pixer.fromMemory(Uint8List data) {
    if (data.isEmpty) throw DecodingException('input buffer is empty');
    return Pixer._(BackendImage.fromMemory(data));
  }

  /// Loads an image from a byte buffer with a specific format
  ///
  /// Throws [DecodingException] if the buffer is empty or cannot be decoded.
  /// Throws [UnsupportedFormatException] if the format is not supported.
  factory Pixer.fromMemoryWithFormat(Uint8List data, ImageFormatEnum format) {
    if (data.isEmpty) throw DecodingException('input buffer is empty');
    return Pixer._(BackendImage.fromMemory(data, format));
  }

  /// Checks if the image has been disposed
  void _checkDisposed() {
    if (_isDisposed) {
      throw InvalidPointerException('image has been disposed');
    }
  }

  void _validateDimensions(int width, int height, {String? context}) {
    if (width <= 0 ||
        height <= 0 ||
        width > _maxUint32 ||
        height > _maxUint32) {
      throw InvalidDimensionsException(
        context ?? 'width and height must fit unsigned 32-bit values',
      );
    }
  }

  void _validateCoordinate(int value, String name) {
    if (value < 0 || value > _maxUint32) {
      throw InvalidDimensionsException(
        '$name must fit an unsigned 32-bit value',
      );
    }
  }

  void _validateBlur(double sigma) {
    if (!sigma.isFinite || sigma < 0 || sigma > _maxFloat32) {
      throw ArgumentError.value(
        sigma,
        'sigma',
        'Must be finite, >= 0, and fit a 32-bit float',
      );
    }
  }

  void _validateBrightness(int value) {
    if (value < _minInt32 || value > _maxInt32) {
      throw RangeError.range(value, _minInt32, _maxInt32, 'value');
    }
  }

  void _validateContrast(double contrast) {
    if (!contrast.isFinite || contrast.abs() > _maxFloat32) {
      throw ArgumentError.value(
        contrast,
        'contrast',
        'Must be finite and fit a 32-bit float',
      );
    }
  }

  void _validateCrop(int x, int y, int width, int height) {
    _validateCoordinate(x, 'x');
    _validateCoordinate(y, 'y');
    _validateDimensions(
      width,
      height,
      context: 'crop width and height must be > 0',
    );

    // Bounds validation
    final meta = getMetadata();
    if (x + width > meta.width) {
      throw InvalidDimensionsException(
        'crop right edge (${x + width}) exceeds image width (${meta.width})',
      );
    }
    if (y + height > meta.height) {
      throw InvalidDimensionsException(
        'crop bottom edge (${y + height}) exceeds image height (${meta.height})',
      );
    }
  }

  /// Gets the image metadata (width, height, color type).
  ///
  /// The result is cached; subsequent calls return the cached value
  /// without calling the platform backend again.
  PixerMetadata getMetadata() {
    _checkDisposed();
    return _cachedMetadata ??= _backend.getMetadata();
  }

  /// Gets the image width
  int get width => getMetadata().width;

  /// Gets the image height
  int get height => getMetadata().height;

  /// Gets the image color type
  ColorType get colorType => getMetadata().colorType;

  /// Saves the image to a file
  ///
  /// The format is determined by the file extension.
  /// Throws [InvalidPathException] if the path is empty.
  /// Throws [UnsupportedError] on web; use [encode] instead.
  void saveToFile(String path) {
    _checkDisposed();
    if (path.trim().isEmpty) throw InvalidPathException('path is empty');
    _backend.saveToFile(path);
  }

  /// Encodes the image to a byte buffer with [encoder].
  ///
  /// Pass `const PixerPngEncoder()` (or any other [PixerEncoder]) for default
  /// settings, or e.g. `PixerJpegEncoder(quality: 90)` to tune output.
  Uint8List encode(PixerEncoder encoder) {
    _checkDisposed();
    return _backend.encode(encoder);
  }

  /// Starts a lazy batch of image operations.
  ///
  /// Operations are recorded in Dart and executed together when [PixerBatch.toImage],
  /// [PixerBatch.encode], or [PixerBatch.saveToFile] is called.
  PixerBatch batch() {
    _checkDisposed();
    return PixerBatch._(this);
  }

  /// Resizes the image to fit *within* [width] x [height], preserving aspect
  /// ratio.
  ///
  /// The result is at most [width] x [height]; the smaller dimension is
  /// scaled proportionally so the image is never distorted. Use
  /// [resizeExact] to force exact dimensions.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer resize(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) {
    _checkDisposed();
    _validateDimensions(width, height);
    return Pixer._(
      _backend.transform(
        ImageOperation(
          PixerOperationKind.Resize,
          'resize',
          width,
          height,
          filter.value,
        ),
      ),
    );
  }

  /// Resizes the image to exactly [width] x [height], ignoring aspect ratio.
  ///
  /// May visibly stretch or squash the image. See [resize] to preserve
  /// aspect ratio.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer resizeExact(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) {
    _checkDisposed();
    _validateDimensions(width, height);
    return Pixer._(
      _backend.transform(
        ImageOperation(
          PixerOperationKind.ResizeExact,
          'resizeExact',
          width,
          height,
          filter.value,
        ),
      ),
    );
  }

  /// Crops the image to the specified rectangle
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer crop(int x, int y, int width, int height) {
    _checkDisposed();
    _validateCrop(x, y, width, height);
    return Pixer._(
      _backend.transform(
        ImageOperation(PixerOperationKind.Crop, 'crop', x, y, width, height),
      ),
    );
  }

  /// Rotates the image 90 degrees clockwise
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer rotate90() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(PixerOperationKind.Rotate90, 'rotate90'),
      ),
    );
  }

  /// Rotates the image 180 degrees
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer rotate180() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(PixerOperationKind.Rotate180, 'rotate180'),
      ),
    );
  }

  /// Rotates the image 270 degrees clockwise (90 degrees counter-clockwise)
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer rotate270() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(PixerOperationKind.Rotate270, 'rotate270'),
      ),
    );
  }

  /// Flips the image horizontally
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer flipHorizontal() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(
          PixerOperationKind.FlipHorizontal,
          'flipHorizontal',
        ),
      ),
    );
  }

  /// Flips the image vertically
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer flipVertical() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(PixerOperationKind.FlipVertical, 'flipVertical'),
      ),
    );
  }

  /// Applies a Gaussian blur to the image.
  ///
  /// [sigma] controls the blur strength (higher = more blur).
  /// A value of 0 results in no change.
  /// Throws [ArgumentError] if sigma is negative.
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer blur(double sigma) {
    _checkDisposed();
    _validateBlur(sigma);
    return Pixer._(
      _backend.transform(
        ImageOperation(PixerOperationKind.Blur, 'blur', 0, 0, 0, 0, sigma),
      ),
    );
  }

  /// Adjusts brightness by adding [value] to every channel.
  ///
  /// Values are clamped per-channel to `[0, 255]`. Negative values darken,
  /// positive values brighten. The practical range is roughly `-255..=255`;
  /// larger magnitudes simply saturate.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer brightness(int value) {
    _checkDisposed();
    _validateBrightness(value);
    return Pixer._(
      _backend.transform(
        ImageOperation(PixerOperationKind.Brightness, 'brightness', value),
      ),
    );
  }

  /// Adjusts contrast around the midpoint.
  ///
  /// [contrast] of `0.0` leaves the image unchanged. Positive values increase
  /// contrast, negative values decrease it. Must be finite.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer contrast(double contrast) {
    _checkDisposed();
    _validateContrast(contrast);
    return Pixer._(
      _backend.transform(
        ImageOperation(
          PixerOperationKind.Contrast,
          'contrast',
          0,
          0,
          0,
          0,
          contrast,
        ),
      ),
    );
  }

  /// Converts the image to grayscale
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer grayscale() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(PixerOperationKind.Grayscale, 'grayscale'),
      ),
    );
  }

  /// Inverts the colors of the image.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer invert() {
    _checkDisposed();
    return Pixer._(
      _backend.transform(
        const ImageOperation(PixerOperationKind.Invert, 'invert'),
      ),
    );
  }

  /// Disposes the native resources
  ///
  /// Call this when the image is no longer needed to prevent memory leaks.
  /// Native finalizers provide a fallback. Web requires explicit disposal.
  void dispose() {
    if (_isDisposed) return;
    _backend.dispose();
    _isDisposed = true;
  }
}
