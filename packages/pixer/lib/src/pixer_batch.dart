part of 'pixer_base.dart';

/// A lazy, ordered batch. Terminal calls leave the source unchanged.
final class PixerBatch {
  PixerBatch._(this._source);

  final Pixer _source;
  final List<ImageOperation> _operations = [];

  PixerBatch resize(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) {
    _source._validateDimensions(width, height);
    return _add(
      ImageOperation(
        PixerOperationKind.Resize,
        'resize',
        width,
        height,
        filter.value,
      ),
    );
  }

  PixerBatch resizeExact(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) {
    _source._validateDimensions(width, height);
    return _add(
      ImageOperation(
        PixerOperationKind.ResizeExact,
        'resizeExact',
        width,
        height,
        filter.value,
      ),
    );
  }

  PixerBatch crop(int x, int y, int width, int height) {
    _source._validateCoordinate(x, 'x');
    _source._validateCoordinate(y, 'y');
    _source._validateDimensions(
      width,
      height,
      context: 'crop width and height must be > 0',
    );
    return _add(
      ImageOperation(PixerOperationKind.Crop, 'crop', x, y, width, height),
    );
  }

  PixerBatch rotate90() =>
      _add(const ImageOperation(PixerOperationKind.Rotate90, 'rotate90'));
  PixerBatch rotate180() =>
      _add(const ImageOperation(PixerOperationKind.Rotate180, 'rotate180'));
  PixerBatch rotate270() =>
      _add(const ImageOperation(PixerOperationKind.Rotate270, 'rotate270'));
  PixerBatch flipHorizontal() => _add(
    const ImageOperation(PixerOperationKind.FlipHorizontal, 'flipHorizontal'),
  );
  PixerBatch flipVertical() => _add(
    const ImageOperation(PixerOperationKind.FlipVertical, 'flipVertical'),
  );

  PixerBatch blur(double sigma) {
    _source._validateBlur(sigma);
    return _add(
      ImageOperation(PixerOperationKind.Blur, 'blur', 0, 0, 0, 0, sigma),
    );
  }

  PixerBatch brightness(int value) {
    _source._validateBrightness(value);
    return _add(
      ImageOperation(PixerOperationKind.Brightness, 'brightness', value),
    );
  }

  PixerBatch contrast(double contrast) {
    _source._validateContrast(contrast);
    return _add(
      ImageOperation(
        PixerOperationKind.Contrast,
        'contrast',
        0,
        0,
        0,
        0,
        contrast,
      ),
    );
  }

  PixerBatch grayscale() =>
      _add(const ImageOperation(PixerOperationKind.Grayscale, 'grayscale'));
  PixerBatch invert() =>
      _add(const ImageOperation(PixerOperationKind.Invert, 'invert'));

  /// Executes the batch and returns an independently owned image.
  Pixer toImage() {
    _source._checkDisposed();
    return Pixer._(_source._backend.batchToImage(_operations));
  }

  /// Executes and encodes the batch without a Dart-visible intermediate.
  Uint8List encode(PixerEncoder encoder) {
    _source._checkDisposed();
    return _source._backend.encode(encoder, _operations);
  }

  /// Executes and saves the batch on native platforms.
  void saveToFile(String path) {
    _source._checkDisposed();
    if (path.trim().isEmpty) throw InvalidPathException('path is empty');
    _source._backend.saveToFile(path, _operations);
  }

  PixerBatch _add(ImageOperation operation) {
    _operations.add(operation);
    return this;
  }
}
