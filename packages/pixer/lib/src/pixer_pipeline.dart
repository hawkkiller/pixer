part of 'pixer_base.dart';

/// A lazy, immutable sequence of operations on a source [Pixer].
///
/// Each operation returns a new pipeline, so a pipeline can be safely
/// branched. Nothing is processed until a terminal method ([toImage],
/// [encode], or [saveToFile]) is called; the terminal runs every operation in
/// a single native call, keeping intermediates inside Rust. Terminals leave
/// the source unchanged and may be called repeatedly.
///
/// Arguments are validated when each operation is added. Checks that depend on
/// the image, such as crop bounds, run against the preceding operation's
/// output when a terminal is called.
final class PixerPipeline {
  PixerPipeline._(this._source, this._operations);

  final Pixer _source;
  final List<ImageOperation> _operations;

  /// Resizes to fit *within* [width] x [height], preserving aspect ratio.
  ///
  /// The result is at most [width] x [height]; the smaller dimension is
  /// scaled proportionally so the image is never distorted. Use
  /// [resizeExact] to force exact dimensions.
  PixerPipeline resize(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) => _add(ResizeOperation(width, height, filter));

  /// Resizes to exactly [width] x [height], ignoring aspect ratio.
  ///
  /// May visibly stretch or squash the image. See [resize] to preserve
  /// aspect ratio.
  PixerPipeline resizeExact(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) => _add(ResizeOperation(width, height, filter, exact: true));

  /// Crops to the rectangle at ([x], [y]) of size [width] x [height].
  ///
  /// The rectangle must fit inside the image produced by the preceding
  /// operations; otherwise the terminal throws [InvalidDimensionsException].
  PixerPipeline crop(int x, int y, int width, int height) =>
      _add(CropOperation(x, y, width, height));

  /// Rotates 90 degrees clockwise.
  PixerPipeline rotate90() => _add(SimpleOperation.rotate90);

  /// Rotates 180 degrees.
  PixerPipeline rotate180() => _add(SimpleOperation.rotate180);

  /// Rotates 270 degrees clockwise (90 degrees counter-clockwise).
  PixerPipeline rotate270() => _add(SimpleOperation.rotate270);

  /// Flips horizontally.
  PixerPipeline flipHorizontal() => _add(SimpleOperation.flipHorizontal);

  /// Flips vertically.
  PixerPipeline flipVertical() => _add(SimpleOperation.flipVertical);

  /// Applies a Gaussian blur.
  ///
  /// [sigma] controls the blur strength (higher = more blur); `0` leaves the
  /// image unchanged. Throws [ArgumentError] unless sigma is zero or a
  /// positive normal 32-bit float.
  PixerPipeline blur(double sigma) => _add(BlurOperation(sigma));

  /// Adds [value] to color channels, preserving alpha.
  ///
  /// Values are clamped to the channel range (`[0, 255]` for 8-bit images).
  /// Negative values darken, positive values brighten; larger magnitudes
  /// simply saturate.
  PixerPipeline brightness(int value) => _add(BrightnessOperation(value));

  /// Adjusts contrast around the midpoint.
  ///
  /// `0.0` leaves the image unchanged. Positive values increase contrast,
  /// negative values decrease it. Must be finite.
  PixerPipeline contrast(double contrast) => _add(ContrastOperation(contrast));

  /// Converts to grayscale, preserving alpha and bit depth.
  PixerPipeline grayscale() => _add(SimpleOperation.grayscale);

  /// Inverts the colors.
  PixerPipeline invert() => _add(SimpleOperation.invert);

  /// Runs the pipeline and returns a new, independently owned [Pixer].
  ///
  /// The caller must [Pixer.dispose] the result.
  Pixer toImage() {
    _source._checkDisposed();
    return Pixer._(_source._backend.batchToImage(_operations));
  }

  /// Runs the pipeline and encodes the result with [encoder].
  Uint8List encode(PixerEncoder encoder) {
    _source._checkDisposed();
    return _source._backend.encode(encoder, _operations);
  }

  /// Runs the pipeline and saves the result; the extension picks the format.
  ///
  /// Throws [InvalidPathException] if the path is empty.
  /// Throws [UnsupportedError] on web; use [encode] instead.
  void saveToFile(String path) {
    _source._checkDisposed();
    if (path.trim().isEmpty) throw InvalidPathException('path is empty');
    _source._backend.saveToFile(path, _operations);
  }

  PixerPipeline _add(ImageOperation operation) =>
      PixerPipeline._(_source, List.unmodifiable([..._operations, operation]));
}
