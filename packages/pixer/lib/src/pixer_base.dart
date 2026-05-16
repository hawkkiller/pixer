import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/bindings.dart';
import 'image_metadata.dart';
import 'pixer_encoder.dart';
import 'pixer_exception.dart';

/// A loaded image, backed by native Rust.
///
/// Operations like [resize], [crop], [blur], and so on each return a new
/// [Pixer]; the original is unchanged. Encode with [encode] or save with
/// [saveToFile].
///
/// ## Memory management
///
/// Every [Pixer] owns a native handle. Call [dispose] when you're done with
/// it — including intermediates in a pipeline. A finalizer provides a safety
/// net but is not guaranteed to run (especially across isolates), so explicit
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
  Pixer._(this._handle) : assert(_handle != ffi.nullptr) {
    _finalizer.attach(this, _handle, detach: this);
  }

  static final Finalizer<ffi.Pointer<ImageHandle>> _finalizer = Finalizer(
    (handle) => pixer_free(handle),
  );

  final ffi.Pointer<ImageHandle> _handle;
  bool _isDisposed = false;
  PixerMetadata? _cachedMetadata;

  /// Whether the native resources have been disposed.
  bool get isDisposed => _isDisposed;

  /// Loads an image from a file path
  ///
  /// Throws [InvalidPathException] if the path is empty or invalid.
  /// Throws [IoException] if the file cannot be read.
  /// Throws [DecodingException] if the image format cannot be decoded.
  /// Throws [UnsupportedFormatException] if the format is not supported.
  factory Pixer.fromFile(String path) {
    if (path.trim().isEmpty) {
      throw InvalidPathException('path is empty');
    }
    final pathPtr = path.toNativeUtf8();
    final errorPtr = malloc.allocate<ffi.Uint32>(ffi.sizeOf<ffi.Uint32>());
    try {
      final handle = pixer_load_with_error(pathPtr.cast(), errorPtr);
      if (handle == ffi.nullptr) {
        final errorCode = ImageErrorCode.fromValue(errorPtr.value);
        throw PixerException.fromCode(errorCode, context: 'path: $path');
      }
      return Pixer._(handle);
    } finally {
      malloc.free(pathPtr);
      malloc.free(errorPtr);
    }
  }

  /// Loads an image from a byte buffer
  ///
  /// Throws [DecodingException] if the buffer is empty or cannot be decoded.
  /// Throws [UnsupportedFormatException] if the format is not supported.
  factory Pixer.fromMemory(Uint8List data) {
    if (data.isEmpty) {
      throw DecodingException('input buffer is empty');
    }
    final dataPtr = malloc.allocate<ffi.Uint8>(data.length);
    final errorPtr = malloc.allocate<ffi.Uint32>(ffi.sizeOf<ffi.Uint32>());
    try {
      dataPtr.asTypedList(data.length).setAll(0, data);
      final handle = pixer_load_from_memory_with_error(
        dataPtr,
        data.length,
        errorPtr,
      );
      if (handle == ffi.nullptr) {
        final errorCode = ImageErrorCode.fromValue(errorPtr.value);
        throw PixerException.fromCode(errorCode, context: 'input: memory');
      }
      return Pixer._(handle);
    } finally {
      malloc.free(dataPtr);
      malloc.free(errorPtr);
    }
  }

  /// Loads an image from a byte buffer with a specific format
  ///
  /// Throws [DecodingException] if the buffer is empty or cannot be decoded.
  /// Throws [UnsupportedFormatException] if the format is not supported.
  factory Pixer.fromMemoryWithFormat(Uint8List data, ImageFormatEnum format) {
    if (data.isEmpty) {
      throw DecodingException('input buffer is empty');
    }
    final dataPtr = malloc.allocate<ffi.Uint8>(data.length);
    final errorPtr = malloc.allocate<ffi.Uint32>(ffi.sizeOf<ffi.Uint32>());
    try {
      dataPtr.asTypedList(data.length).setAll(0, data);
      final handle = pixer_load_from_memory_with_format_and_error(
        dataPtr,
        data.length,
        format.value,
        errorPtr,
      );
      if (handle == ffi.nullptr) {
        final errorCode = ImageErrorCode.fromValue(errorPtr.value);
        throw PixerException.fromCode(
          errorCode,
          context: 'input: memory, format: ${format.name}',
        );
      }
      return Pixer._(handle);
    } finally {
      malloc.free(dataPtr);
      malloc.free(errorPtr);
    }
  }

  /// Checks if the image has been disposed
  void _checkDisposed() {
    if (_isDisposed) {
      throw InvalidPointerException('image has been disposed');
    }
  }

  void _validateDimensions(int width, int height, {String? context}) {
    if (width <= 0 || height <= 0) {
      throw InvalidDimensionsException(
        context ?? 'width and height must be > 0',
      );
    }
  }

  void _validateCrop(int x, int y, int width, int height) {
    if (x < 0 || y < 0) {
      throw InvalidDimensionsException('x and y must be >= 0');
    }
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

  Pixer _fromNativeHandle(ffi.Pointer<ImageHandle> handle, String operation) {
    if (handle == ffi.nullptr) {
      throw UnknownException('operation: $operation');
    }
    return Pixer._(handle);
  }

  ImageErrorCode _errorFromValue(int value) {
    try {
      return ImageErrorCode.fromValue(value);
    } on ArgumentError {
      return ImageErrorCode.Unknown;
    }
  }

  /// Gets the image metadata (width, height, color type).
  ///
  /// The result is cached; subsequent calls return the cached value
  /// without an FFI round-trip.
  PixerMetadata getMetadata() {
    _checkDisposed();
    if (_cachedMetadata != null) return _cachedMetadata!;

    final metadataPtr = malloc.allocate<ImageMetadata>(
      ffi.sizeOf<ImageMetadata>(),
    );
    try {
      final errorCode = pixer_get_metadata(_handle, metadataPtr);
      final error = _errorFromValue(errorCode);
      if (error != ImageErrorCode.Success) {
        throw PixerException.fromCode(error, context: 'operation: metadata');
      }
      _cachedMetadata = PixerMetadata.fromNative(metadataPtr);
      return _cachedMetadata!;
    } finally {
      malloc.free(metadataPtr);
    }
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
  void saveToFile(String path) {
    _checkDisposed();
    if (path.trim().isEmpty) {
      throw InvalidPathException('path is empty');
    }
    final pathPtr = path.toNativeUtf8();
    try {
      final errorCode = pixer_save(_handle, pathPtr.cast());
      final error = _errorFromValue(errorCode);
      if (error != ImageErrorCode.Success) {
        throw PixerException.fromCode(error, context: 'path: $path');
      }
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Encodes the image to a byte buffer with [encoder].
  ///
  /// Pass `const PixerPngEncoder()` (or any other [PixerEncoder]) for default
  /// settings, or e.g. `PixerJpegEncoder(quality: 90)` to tune output.
  Uint8List encode(PixerEncoder encoder) {
    _checkDisposed();
    return encoder.encode(_handle);
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
    final handle = pixer_resize(_handle, width, height, filter.value);
    return _fromNativeHandle(handle, 'resize');
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
    final handle = pixer_resize_exact(_handle, width, height, filter.value);
    return _fromNativeHandle(handle, 'resizeExact');
  }

  /// Crops the image to the specified rectangle
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer crop(int x, int y, int width, int height) {
    _checkDisposed();
    _validateCrop(x, y, width, height);
    final handle = pixer_crop_imm(_handle, x, y, width, height);
    return _fromNativeHandle(handle, 'crop');
  }

  /// Rotates the image 90 degrees clockwise
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer rotate90() {
    _checkDisposed();
    final handle = pixer_rotate90(_handle);
    return _fromNativeHandle(handle, 'rotate90');
  }

  /// Rotates the image 180 degrees
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer rotate180() {
    _checkDisposed();
    final handle = pixer_rotate180(_handle);
    return _fromNativeHandle(handle, 'rotate180');
  }

  /// Rotates the image 270 degrees clockwise (90 degrees counter-clockwise)
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer rotate270() {
    _checkDisposed();
    final handle = pixer_rotate270(_handle);
    return _fromNativeHandle(handle, 'rotate270');
  }

  /// Flips the image horizontally
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer flipHorizontal() {
    _checkDisposed();
    final handle = pixer_fliph(_handle);
    return _fromNativeHandle(handle, 'flipHorizontal');
  }

  /// Flips the image vertically
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer flipVertical() {
    _checkDisposed();
    final handle = pixer_flipv(_handle);
    return _fromNativeHandle(handle, 'flipVertical');
  }

  /// Applies a Gaussian blur to the image.
  ///
  /// [sigma] controls the blur strength (higher = more blur).
  /// A value of 0 results in no change.
  /// Throws [ArgumentError] if sigma is negative.
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer blur(double sigma) {
    _checkDisposed();
    if (sigma < 0) {
      throw ArgumentError.value(sigma, 'sigma', 'Must be >= 0');
    }
    final handle = pixer_blur(_handle, sigma);
    return _fromNativeHandle(handle, 'blur');
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
    final handle = pixer_brighten(_handle, value);
    return _fromNativeHandle(handle, 'brightness');
  }

  /// Adjusts contrast around the midpoint.
  ///
  /// [contrast] of `0.0` leaves the image unchanged. Positive values increase
  /// contrast, negative values decrease it. Must be finite.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer contrast(double contrast) {
    _checkDisposed();
    final handle = pixer_adjust_contrast(_handle, contrast);
    return _fromNativeHandle(handle, 'contrast');
  }

  /// Converts the image to grayscale
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer grayscale() {
    _checkDisposed();
    final handle = pixer_grayscale(_handle);
    return _fromNativeHandle(handle, 'grayscale');
  }

  /// Inverts the colors of the image.
  ///
  /// Returns a new [Pixer] instance. The original is not modified.
  Pixer invert() {
    _checkDisposed();
    final handle = pixer_invert(_handle);
    return _fromNativeHandle(handle, 'invert');
  }

  /// Disposes the native resources
  ///
  /// Call this when the image is no longer needed to prevent memory leaks.
  /// A finalizer provides a fallback, but explicit disposal is recommended.
  void dispose() {
    if (!_isDisposed) {
      _finalizer.detach(this);
      pixer_free(_handle);
      _isDisposed = true;
    }
  }
}
