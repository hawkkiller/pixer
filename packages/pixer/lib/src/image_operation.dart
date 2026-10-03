import 'enums.dart';
import 'pixer_exception.dart';

const _maxUint32 = 0xFFFFFFFF;
const _minInt32 = -0x80000000;
const _maxInt32 = 0x7FFFFFFF;
const _maxFloat32 = 3.4028234663852886e38;
const _minNormalFloat32 = 1.1754943508222875e-38;

/// A validated operation passed to either platform backend.
sealed class ImageOperation {
  const ImageOperation();

  /// Public method name, used in error messages.
  String get name;
}

final class ResizeOperation extends ImageOperation {
  ResizeOperation(this.width, this.height, this.filter, {this.exact = false}) {
    _checkSize(
      width,
      height,
      'width and height must fit unsigned 32-bit values',
    );
  }

  final int width;
  final int height;
  final FilterTypeEnum filter;
  final bool exact;

  @override
  String get name => exact ? 'resizeExact' : 'resize';
}

final class CropOperation extends ImageOperation {
  CropOperation(this.x, this.y, this.width, this.height) {
    _checkCoordinate(x, 'x');
    _checkCoordinate(y, 'y');
    _checkSize(width, height, 'crop width and height must be > 0');
  }

  final int x;
  final int y;
  final int width;
  final int height;

  @override
  String get name => 'crop';
}

final class BlurOperation extends ImageOperation {
  BlurOperation(this.sigma) {
    if (!sigma.isFinite ||
        sigma < 0 ||
        sigma > _maxFloat32 ||
        (sigma > 0 && sigma < _minNormalFloat32)) {
      throw ArgumentError.value(
        sigma,
        'sigma',
        'Must be zero or a positive normal 32-bit float',
      );
    }
  }

  final double sigma;

  @override
  String get name => 'blur';
}

final class BrightnessOperation extends ImageOperation {
  BrightnessOperation(this.value) {
    if (value < _minInt32 || value > _maxInt32) {
      throw RangeError.range(value, _minInt32, _maxInt32, 'value');
    }
  }

  final int value;

  @override
  String get name => 'brightness';
}

final class ContrastOperation extends ImageOperation {
  ContrastOperation(this.contrast) {
    if (!contrast.isFinite || contrast.abs() > _maxFloat32) {
      throw ArgumentError.value(
        contrast,
        'contrast',
        'Must be finite and fit a 32-bit float',
      );
    }
  }

  final double contrast;

  @override
  String get name => 'contrast';
}

/// Operations without arguments.
final class SimpleOperation extends ImageOperation {
  const SimpleOperation._(this.kind, this.name);

  static const rotate90 = SimpleOperation._(
    PixerOperationKind.Rotate90,
    'rotate90',
  );
  static const rotate180 = SimpleOperation._(
    PixerOperationKind.Rotate180,
    'rotate180',
  );
  static const rotate270 = SimpleOperation._(
    PixerOperationKind.Rotate270,
    'rotate270',
  );
  static const flipHorizontal = SimpleOperation._(
    PixerOperationKind.FlipHorizontal,
    'flipHorizontal',
  );
  static const flipVertical = SimpleOperation._(
    PixerOperationKind.FlipVertical,
    'flipVertical',
  );
  static const grayscale = SimpleOperation._(
    PixerOperationKind.Grayscale,
    'grayscale',
  );
  static const invert = SimpleOperation._(PixerOperationKind.Invert, 'invert');

  final PixerOperationKind kind;
  @override
  final String name;
}

/// The values of one `PixerOperation` ABI struct.
typedef OperationSlots = ({
  int kind,
  int arg0,
  int arg1,
  int arg2,
  int arg3,
  double scalar,
});

/// The only Dart code that knows the slot layout. Mirror of
/// `TryFrom<&PixerOperation> for Op` in native/src/ffi.rs.
OperationSlots encodeOperation(ImageOperation op) => switch (op) {
  ResizeOperation(:final width, :final height, :final filter, :final exact) =>
    _slots(
      exact ? PixerOperationKind.ResizeExact : PixerOperationKind.Resize,
      arg0: width,
      arg1: height,
      arg2: filter.value,
    ),
  CropOperation(:final x, :final y, :final width, :final height) => _slots(
    PixerOperationKind.Crop,
    arg0: x,
    arg1: y,
    arg2: width,
    arg3: height,
  ),
  BlurOperation(:final sigma) => _slots(PixerOperationKind.Blur, scalar: sigma),
  BrightnessOperation(:final value) => _slots(
    PixerOperationKind.Brightness,
    arg0: value,
  ),
  ContrastOperation(:final contrast) => _slots(
    PixerOperationKind.Contrast,
    scalar: contrast,
  ),
  SimpleOperation(:final kind) => _slots(kind),
};

OperationSlots _slots(
  PixerOperationKind kind, {
  int arg0 = 0,
  int arg1 = 0,
  int arg2 = 0,
  int arg3 = 0,
  double scalar = 0,
}) => (
  kind: kind.value,
  arg0: arg0,
  arg1: arg1,
  arg2: arg2,
  arg3: arg3,
  scalar: scalar,
);

void _checkSize(int width, int height, String message) {
  if (width <= 0 || height <= 0 || width > _maxUint32 || height > _maxUint32) {
    throw InvalidDimensionsException(message);
  }
}

void _checkCoordinate(int value, String name) {
  if (value < 0 || value > _maxUint32) {
    throw InvalidDimensionsException('$name must fit an unsigned 32-bit value');
  }
}
