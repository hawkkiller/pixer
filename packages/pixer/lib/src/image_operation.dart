import 'enums.dart';
import 'pixer_exception.dart';

/// A validated operation passed to either platform backend.
final class ImageOperation {
  const ImageOperation(
    this.kind,
    this.name, [
    this.arg0 = 0,
    this.arg1 = 0,
    this.arg2 = 0,
    this.arg3 = 0,
    this.scalar = 0,
  ]);
  final PixerOperationKind kind;
  final String name;
  final int arg0;
  final int arg1;
  final int arg2;
  final int arg3;
  final double scalar;
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
  checkImageError(
    value,
    failedIndex < operations.length
        ? 'batch operation ${failedIndex + 1}: ${operations[failedIndex].name}'
        : 'batch terminal: $terminal',
  );
}
