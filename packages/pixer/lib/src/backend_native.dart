import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;

import 'bindings/bindings.dart'
    hide FilterTypeEnum, ImageErrorCode, ImageFormatEnum, PixerOperationKind;
import 'enums.dart';
import 'image_metadata.dart';
import 'image_operation.dart';
import 'pixer_encoder.dart';
import 'pixer_exception.dart';

/// Owns a native handle. The shared Pixer API guards access after disposal.
final class BackendImage implements ffi.Finalizable {
  BackendImage._(this._handle) {
    if (_handle == ffi.nullptr) throw UnknownException('operation: image');
    try {
      final metadata = getMetadata();
      _finalizer.attach(
        this,
        _handle.cast(),
        detach: this,
        externalSize:
            metadata.width * metadata.height * (metadata.colorType.value + 1),
      );
    } catch (_) {
      pixer_free(_handle);
      rethrow;
    }
  }

  final ffi.Pointer<ImageHandle> _handle;
  static final _finalizer = ffi.NativeFinalizer(
    ffi.Native.addressOf<
          ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ImageHandle>)>
        >(pixer_free)
        .cast(),
  );

  static Future<void> initialize({Uint8List? wasmBytes, Uri? wasmUri}) async {}

  factory BackendImage.fromFile(String path) => ffi.using((arena) {
    final error = arena<ffi.Uint32>();
    final handle = pixer_load_with_error(
      path.toNativeUtf8(allocator: arena).cast(),
      error,
    );
    checkImageError(error.value, 'path: $path');
    return BackendImage._(handle);
  });

  factory BackendImage.fromMemory(Uint8List bytes, [ImageFormatEnum? format]) =>
      ffi.using((arena) {
        final data = arena<ffi.Uint8>(bytes.length);
        data.asTypedList(bytes.length).setAll(0, bytes);
        final error = arena<ffi.Uint32>();
        final handle = format == null
            ? pixer_load_from_memory_with_error(data, bytes.length, error)
            : pixer_load_from_memory_with_format_and_error(
                data,
                bytes.length,
                format.value,
                error,
              );
        checkImageError(error.value, 'input: memory');
        return BackendImage._(handle);
      });

  PixerMetadata getMetadata() => ffi.using((arena) {
    final pointer = arena<ImageMetadata>();
    checkImageError(
      pixer_get_metadata(_handle, pointer),
      'operation: metadata',
    );
    return PixerMetadata(
      width: pointer.ref.width,
      height: pointer.ref.height,
      colorType: ColorType.fromValue(pointer.ref.color_type),
    );
  });

  BackendImage transform(ImageOperation op) => BackendImage._(switch (op.kind) {
    PixerOperationKind.Resize => pixer_resize(
      _handle,
      op.arg0,
      op.arg1,
      op.arg2,
    ),
    PixerOperationKind.ResizeExact => pixer_resize_exact(
      _handle,
      op.arg0,
      op.arg1,
      op.arg2,
    ),
    PixerOperationKind.Crop => pixer_crop_imm(
      _handle,
      op.arg0,
      op.arg1,
      op.arg2,
      op.arg3,
    ),
    PixerOperationKind.Rotate90 => pixer_rotate90(_handle),
    PixerOperationKind.Rotate180 => pixer_rotate180(_handle),
    PixerOperationKind.Rotate270 => pixer_rotate270(_handle),
    PixerOperationKind.FlipHorizontal => pixer_fliph(_handle),
    PixerOperationKind.FlipVertical => pixer_flipv(_handle),
    PixerOperationKind.Blur => pixer_blur(_handle, op.scalar),
    PixerOperationKind.Brightness => pixer_brighten(_handle, op.arg0),
    PixerOperationKind.Contrast => pixer_adjust_contrast(_handle, op.scalar),
    PixerOperationKind.Grayscale => pixer_grayscale(_handle),
    PixerOperationKind.Invert => pixer_invert(_handle),
  });

  BackendImage batchToImage(List<ImageOperation> operations) =>
      ffi.using((arena) {
        final pointer = _operations(arena, operations);
        final error = arena<ffi.Uint32>();
        final failedIndex = arena<ffi.UintPtr>();
        final handle = pixer_batch_to_image(
          _handle,
          pointer,
          operations.length,
          error,
          failedIndex,
        );
        checkBatchError(error.value, failedIndex.value, operations, 'toImage');
        return BackendImage._(handle);
      });

  Uint8List encode(PixerEncoder encoder, [List<ImageOperation>? operations]) =>
      ffi.using((arena) {
        final output = arena<ffi.Pointer<ffi.Uint8>>();
        final length = arena<ffi.UintPtr>();
        if (operations == null) {
          final code = encoder is PixerJpegEncoder
              ? pixer_encode_jpeg(_handle, encoder.quality, output, length)
              : pixer_encode(_handle, encoder.format.value, output, length);
          checkImageError(code, 'format: ${encoder.format.name}');
        } else {
          final pointer = _operations(arena, operations);
          final failedIndex = arena<ffi.UintPtr>();
          final code = pixer_batch_encode(
            _handle,
            pointer,
            operations.length,
            encoder.format.value,
            encoder.jpegQuality,
            output,
            length,
            failedIndex,
          );
          checkBatchError(code, failedIndex.value, operations, 'encode');
        }
        final data = output.value;
        final count = length.value;
        if (data == ffi.nullptr || count == 0)
          throw UnknownException('operation: encode');
        try {
          return Uint8List.fromList(data.asTypedList(count));
        } finally {
          pixer_free_buffer(data, count);
        }
      });

  void saveToFile(String path, [List<ImageOperation>? operations]) => ffi.using(
    (arena) {
      final pathPointer = path.toNativeUtf8(allocator: arena).cast<ffi.Char>();
      if (operations == null) {
        checkImageError(pixer_save(_handle, pathPointer), 'path: $path');
      } else {
        final pointer = _operations(arena, operations);
        final failedIndex = arena<ffi.UintPtr>();
        final code = pixer_batch_save(
          _handle,
          pointer,
          operations.length,
          pathPointer,
          failedIndex,
        );
        checkBatchError(code, failedIndex.value, operations, 'saveToFile');
      }
    },
  );

  static ffi.Pointer<PixerOperation> _operations(
    ffi.Arena arena,
    List<ImageOperation> commands,
  ) {
    if (commands.isEmpty) return ffi.nullptr;
    final pointer = arena<PixerOperation>(commands.length);
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i];
      pointer[i]
        ..kind = command.kind.value
        ..arg0 = command.arg0
        ..arg1 = command.arg1
        ..arg2 = command.arg2
        ..arg3 = command.arg3
        ..scalar = command.scalar;
    }
    return pointer;
  }

  void dispose() {
    _finalizer.detach(this);
    pixer_free(_handle);
  }
}
