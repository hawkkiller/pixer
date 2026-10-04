import 'enums.dart';
import 'image_operation.dart';

/// Base exception for pixer errors
sealed class PixerException implements Exception {
  PixerException._(this.code, String? context)
    : message = context == null || context.isEmpty
          ? _defaultMessage(code)
          : '${_defaultMessage(code)} ($context)';

  final String message;
  final ImageErrorCode code;

  @override
  String toString() => 'PixerException: $message (code: ${code.name})';

  /// Creates an exception from an error code
  factory PixerException.fromCode(ImageErrorCode code, {String? context}) {
    return switch (code) {
      ImageErrorCode.Success => throw StateError(
        'Cannot create exception from success code',
      ),
      ImageErrorCode.InvalidPath => InvalidPathException(context),
      ImageErrorCode.UnsupportedFormat => UnsupportedFormatException(context),
      ImageErrorCode.DecodingError => DecodingException(context),
      ImageErrorCode.EncodingError => EncodingException(context),
      ImageErrorCode.IoError => IoException(context),
      ImageErrorCode.InvalidDimensions => InvalidDimensionsException(context),
      ImageErrorCode.InvalidPointer => InvalidPointerException(context),
      ImageErrorCode.InvalidParameter => InvalidParameterException(context),
      ImageErrorCode.Unknown => UnknownException(context),
    };
  }

  static String _defaultMessage(ImageErrorCode code) => switch (code) {
    ImageErrorCode.Success => 'Success',
    ImageErrorCode.InvalidPath => 'Invalid path provided',
    ImageErrorCode.UnsupportedFormat =>
      'Unsupported image format, or format not enabled in this build',
    ImageErrorCode.DecodingError => 'Failed to decode image',
    ImageErrorCode.EncodingError => 'Failed to encode image',
    ImageErrorCode.IoError => 'I/O error occurred',
    ImageErrorCode.InvalidDimensions => 'Invalid dimensions',
    ImageErrorCode.InvalidPointer =>
      'Invalid pointer (image may have been disposed)',
    ImageErrorCode.InvalidParameter => 'Invalid parameter',
    ImageErrorCode.Unknown => 'An unknown error occurred',
  };
}

/// Exception thrown when the path is invalid
final class InvalidPathException extends PixerException {
  InvalidPathException([String? context])
    : super._(ImageErrorCode.InvalidPath, context);
}

/// Exception thrown when the format is not supported
final class UnsupportedFormatException extends PixerException {
  UnsupportedFormatException([String? context])
    : super._(ImageErrorCode.UnsupportedFormat, context);
}

/// Exception thrown when decoding fails
final class DecodingException extends PixerException {
  DecodingException([String? context])
    : super._(ImageErrorCode.DecodingError, context);
}

/// Exception thrown when encoding fails
final class EncodingException extends PixerException {
  EncodingException([String? context])
    : super._(ImageErrorCode.EncodingError, context);
}

/// Exception thrown when I/O operation fails
final class IoException extends PixerException {
  IoException([String? context]) : super._(ImageErrorCode.IoError, context);
}

/// Exception thrown when dimensions are invalid
final class InvalidDimensionsException extends PixerException {
  InvalidDimensionsException([String? context])
    : super._(ImageErrorCode.InvalidDimensions, context);
}

/// Exception thrown when a null pointer is encountered
final class InvalidPointerException extends PixerException {
  InvalidPointerException([String? context])
    : super._(ImageErrorCode.InvalidPointer, context);
}

/// Exception thrown when an operation parameter is invalid
final class InvalidParameterException extends PixerException {
  InvalidParameterException([String? context])
    : super._(ImageErrorCode.InvalidParameter, context);
}

/// Exception thrown for unknown errors
final class UnknownException extends PixerException {
  UnknownException([String? context])
    : super._(ImageErrorCode.Unknown, context);
}

/// Translate ABI error codes consistently on both platforms.
void checkImageError(int value, String context) {
  if (value == 0) return;
  final code = ImageErrorCode.values.firstWhere(
    (code) => code.value == value,
    orElse: () => ImageErrorCode.Unknown,
  );
  throw PixerException.fromCode(code, context: context);
}

void checkBatchError(
  int value,
  int failedIndex,
  List<ImageOperation> operations,
  String terminal,
) {
  if (value == 0) return;
  final String context;
  if (failedIndex >= operations.length) {
    context = operations.isEmpty ? terminal : 'pipeline terminal: $terminal';
  } else if (operations.length == 1) {
    context = 'operation: ${operations.single.name}';
  } else {
    context =
        'pipeline operation ${failedIndex + 1}: ${operations[failedIndex].name}';
  }
  checkImageError(value, context);
}
