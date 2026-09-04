part of 'pixer_base.dart';

/// A lazy, ordered batch of operations for one [Pixer] image.
///
/// Add transformations fluently, then call a terminal method:
/// [toImage], [encode], or [saveToFile]. The source image is never modified.
final class PixerBatch {
  PixerBatch._(this._source);

  final Pixer _source;
  final List<_BatchCommand> _commands = [];

  /// Adds an aspect-ratio-preserving resize.
  PixerBatch resize(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) {
    _source._validateDimensions(width, height);
    return _add(
      _BatchCommand(_BatchOperation.resize, width, height, filter.value),
    );
  }

  /// Adds a resize to exact dimensions.
  PixerBatch resizeExact(
    int width,
    int height, {
    FilterTypeEnum filter = FilterTypeEnum.Lanczos3,
  }) {
    _source._validateDimensions(width, height);
    return _add(
      _BatchCommand(_BatchOperation.resizeExact, width, height, filter.value),
    );
  }

  /// Adds a crop evaluated against the image produced by preceding operations.
  PixerBatch crop(int x, int y, int width, int height) {
    _source._validateCoordinate(x, 'x');
    _source._validateCoordinate(y, 'y');
    _source._validateDimensions(
      width,
      height,
      context: 'crop width and height must be > 0',
    );
    return _add(_BatchCommand(_BatchOperation.crop, x, y, width, height));
  }

  /// Adds a 90-degree clockwise rotation.
  PixerBatch rotate90() => _add(const _BatchCommand(_BatchOperation.rotate90));

  /// Adds a 180-degree rotation.
  PixerBatch rotate180() =>
      _add(const _BatchCommand(_BatchOperation.rotate180));

  /// Adds a 270-degree clockwise rotation.
  PixerBatch rotate270() =>
      _add(const _BatchCommand(_BatchOperation.rotate270));

  /// Adds a horizontal flip.
  PixerBatch flipHorizontal() =>
      _add(const _BatchCommand(_BatchOperation.flipHorizontal));

  /// Adds a vertical flip.
  PixerBatch flipVertical() =>
      _add(const _BatchCommand(_BatchOperation.flipVertical));

  /// Adds a Gaussian blur.
  PixerBatch blur(double sigma) {
    _source._validateBlur(sigma);
    return _add(_BatchCommand(_BatchOperation.blur, 0, 0, 0, 0, sigma));
  }

  /// Adds a brightness adjustment.
  PixerBatch brightness(int value) {
    _source._validateBrightness(value);
    return _add(_BatchCommand(_BatchOperation.brightness, value));
  }

  /// Adds a contrast adjustment.
  PixerBatch contrast(double contrast) {
    _source._validateContrast(contrast);
    return _add(_BatchCommand(_BatchOperation.contrast, 0, 0, 0, 0, contrast));
  }

  /// Adds a grayscale conversion.
  PixerBatch grayscale() =>
      _add(const _BatchCommand(_BatchOperation.grayscale));

  /// Adds a color inversion.
  PixerBatch invert() => _add(const _BatchCommand(_BatchOperation.invert));

  /// Executes the batch and returns a new image.
  Pixer toImage() {
    _source._checkDisposed();
    return _withNativeOperations((operations, operationCount) {
      final errorPtr = malloc.allocate<ffi.Uint32>(ffi.sizeOf<ffi.Uint32>());
      final failedIndexPtr = malloc.allocate<ffi.UintPtr>(
        ffi.sizeOf<ffi.UintPtr>(),
      );
      try {
        final handle = pixer_batch_to_image(
          _source._handle,
          operations,
          operationCount,
          errorPtr,
          failedIndexPtr,
        );
        _throwIfError(errorPtr.value, failedIndexPtr.value, 'toImage');
        return _source._fromNativeHandle(handle, 'batch');
      } finally {
        malloc.free(errorPtr);
        malloc.free(failedIndexPtr);
      }
    });
  }

  /// Executes the batch and encodes the result.
  Uint8List encode(PixerEncoder encoder) {
    _source._checkDisposed();
    return _withNativeOperations((operations, operationCount) {
      final outDataPtr = malloc.allocate<ffi.Pointer<ffi.Uint8>>(
        ffi.sizeOf<ffi.Pointer<ffi.Uint8>>(),
      );
      final outLenPtr = malloc.allocate<ffi.UintPtr>(ffi.sizeOf<ffi.UintPtr>());
      final failedIndexPtr = malloc.allocate<ffi.UintPtr>(
        ffi.sizeOf<ffi.UintPtr>(),
      );
      try {
        final jpegQuality = switch (encoder) {
          PixerJpegEncoder(:final quality) => quality,
          _ => 0,
        };
        final errorCode = pixer_batch_write_to(
          _source._handle,
          operations,
          operationCount,
          encoder.format.value,
          jpegQuality,
          outDataPtr,
          outLenPtr,
          failedIndexPtr,
        );
        _throwIfError(errorCode, failedIndexPtr.value, 'encode');

        final dataPtr = outDataPtr.value;
        final length = outLenPtr.value;
        if (dataPtr == ffi.nullptr || length == 0) {
          throw UnknownException('operation: batch encode');
        }
        try {
          return Uint8List.fromList(dataPtr.asTypedList(length));
        } finally {
          pixer_free_buffer(dataPtr, length);
        }
      } finally {
        malloc.free(outDataPtr);
        malloc.free(outLenPtr);
        malloc.free(failedIndexPtr);
      }
    });
  }

  /// Executes the batch and saves the result using the path extension as format.
  void saveToFile(String path) {
    _source._checkDisposed();
    if (path.trim().isEmpty) {
      throw InvalidPathException('path is empty');
    }

    _withNativeOperations((operations, operationCount) {
      final pathPtr = path.toNativeUtf8();
      final failedIndexPtr = malloc.allocate<ffi.UintPtr>(
        ffi.sizeOf<ffi.UintPtr>(),
      );
      try {
        final errorCode = pixer_batch_save(
          _source._handle,
          operations,
          operationCount,
          pathPtr.cast(),
          failedIndexPtr,
        );
        _throwIfError(errorCode, failedIndexPtr.value, 'saveToFile');
      } finally {
        malloc.free(pathPtr);
        malloc.free(failedIndexPtr);
      }
    });
  }

  PixerBatch _add(_BatchCommand command) {
    _commands.add(command);
    return this;
  }

  T _withNativeOperations<T>(
    T Function(ffi.Pointer<PixerOperation> operations, int operationCount)
    execute,
  ) {
    if (_commands.isEmpty) {
      return execute(ffi.nullptr.cast(), 0);
    }

    final operations = malloc.allocate<PixerOperation>(
      ffi.sizeOf<PixerOperation>() * _commands.length,
    );
    try {
      for (var index = 0; index < _commands.length; index++) {
        _commands[index]._writeTo(operations[index]);
      }
      return execute(operations, _commands.length);
    } finally {
      malloc.free(operations);
    }
  }

  void _throwIfError(int value, int failedIndex, String terminal) {
    final error = _source._errorFromValue(value);
    if (error == ImageErrorCode.Success) return;

    final context = failedIndex < _commands.length
        ? 'batch operation ${failedIndex + 1}: ${_commands[failedIndex].operation.id}'
        : 'batch terminal: $terminal';
    throw PixerException.fromCode(error, context: context);
  }
}

enum _BatchOperation {
  resize(PixerOperationKind.Resize, 'resize'),
  resizeExact(PixerOperationKind.ResizeExact, 'resizeExact'),
  crop(PixerOperationKind.Crop, 'crop'),
  rotate90(PixerOperationKind.Rotate90, 'rotate90'),
  rotate180(PixerOperationKind.Rotate180, 'rotate180'),
  rotate270(PixerOperationKind.Rotate270, 'rotate270'),
  flipHorizontal(PixerOperationKind.FlipHorizontal, 'flipHorizontal'),
  flipVertical(PixerOperationKind.FlipVertical, 'flipVertical'),
  blur(PixerOperationKind.Blur, 'blur'),
  brightness(PixerOperationKind.Brightness, 'brightness'),
  contrast(PixerOperationKind.Contrast, 'contrast'),
  grayscale(PixerOperationKind.Grayscale, 'grayscale'),
  invert(PixerOperationKind.Invert, 'invert');

  const _BatchOperation(this.nativeKind, this.id);

  final PixerOperationKind nativeKind;
  final String id;
}

final class _BatchCommand {
  const _BatchCommand(
    this.operation, [
    this.arg0 = 0,
    this.arg1 = 0,
    this.arg2 = 0,
    this.arg3 = 0,
    this.scalar = 0,
  ]);

  final _BatchOperation operation;
  final int arg0;
  final int arg1;
  final int arg2;
  final int arg3;
  final double scalar;

  void _writeTo(PixerOperation operation) {
    operation
      ..kind = this.operation.nativeKind.value
      ..arg0 = arg0
      ..arg1 = arg1
      ..arg2 = arg2
      ..arg3 = arg3
      ..scalar = scalar;
  }
}
