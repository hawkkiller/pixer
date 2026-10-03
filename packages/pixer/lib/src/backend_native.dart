import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;

import 'abi.dart';
import 'bindings/bindings.dart'
    hide FilterTypeEnum, ImageErrorCode, ImageFormatEnum, PixerOperationKind, PIXER_FORMAT_DETECT;
import 'enums.dart';
import 'image_metadata.dart';
import 'image_operation.dart';
import 'pixer_encoder.dart';
import 'pixer_exception.dart';

/// Owns a native handle. The shared Pixer API guards access after disposal.
final class BackendImage implements ffi.Finalizable {
  BackendImage._(this._handle) {
    _finalizer.attach(
      this,
      _handle.cast(),
      detach: this,
      externalSize: pixer_image_byte_length(_handle),
    );
  }

  final ffi.Pointer<ImageHandle> _handle;
  static final _finalizer = ffi.NativeFinalizer(
    ffi.Native.addressOf<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ImageHandle>)>>(
      pixer_free,
    ).cast(),
  );

  // Evaluated once; throws on mismatch.
  static final bool _compatible = _checkAbi();

  static bool _checkAbi() {
    final int version;
    try {
      version = pixer_abi_version();
    } catch (error) {
      throw StateError(
        'Pixer binary has no usable ABI version. Rebuild or download the '
        'binary matching this Pixer package. Cause: $error',
      );
    }
    checkPixerAbi(version);
    return true;
  }

  static void _ensureCompatible() => _compatible;

  static Future<void> initialize({Uint8List? wasmBytes, Uri? wasmUri}) async {
    _ensureCompatible();
  }

  factory BackendImage.fromFile(String path) => ffi.using((arena) {
    _ensureCompatible();
    final image = arena<ffi.Pointer<ImageHandle>>();
    checkImageError(pixer_load(path.toNativeUtf8(allocator: arena).cast(), image), 'path: $path');
    return BackendImage._(image.value);
  });

  factory BackendImage.fromMemory(Uint8List bytes, [ImageFormatEnum? format]) => ffi.using((arena) {
    _ensureCompatible();
    final data = arena<ffi.Uint8>(bytes.length)..asTypedList(bytes.length).setAll(0, bytes);
    final image = arena<ffi.Pointer<ImageHandle>>();
    checkImageError(
      pixer_load_from_memory(data, bytes.length, format?.value ?? PIXER_FORMAT_DETECT, image),
      'input: memory',
    );
    return BackendImage._(image.value);
  });

  PixerMetadata getMetadata() => ffi.using((arena) {
    final pointer = arena<ImageMetadata>();
    checkImageError(pixer_get_metadata(_handle, pointer), 'operation: metadata');
    return PixerMetadata(
      width: pointer.ref.width,
      height: pointer.ref.height,
      colorType: ColorType.fromValue(pointer.ref.color_type),
    );
  });

  BackendImage batchToImage(List<ImageOperation> operations) => ffi.using((arena) {
    final image = arena<ffi.Pointer<ImageHandle>>();
    final failedIndex = arena<ffi.UintPtr>();
    final code = pixer_batch_to_image(
      _handle,
      _operations(arena, operations),
      operations.length,
      image,
      failedIndex,
    );
    checkBatchError(code, failedIndex.value, operations, 'toImage');
    return BackendImage._(image.value);
  });

  Uint8List encode(PixerEncoder encoder, [List<ImageOperation> operations = const []]) =>
      ffi.using((arena) {
        final output = arena<ffi.Pointer<ffi.Uint8>>();
        final length = arena<ffi.UintPtr>();
        final failedIndex = arena<ffi.UintPtr>();
        final code = pixer_batch_encode(
          _handle,
          _operations(arena, operations),
          operations.length,
          encoder.format.value,
          encoder.jpegQuality,
          output,
          length,
          failedIndex,
        );
        checkBatchError(
          code,
          failedIndex.value,
          operations,
          'encode (format: ${encoder.format.name})',
        );
        final data = output.value;
        final count = length.value;
        if (data == ffi.nullptr || count == 0) throw UnknownException('operation: encode');
        try {
          return Uint8List.fromList(data.asTypedList(count));
        } finally {
          pixer_free_buffer(data, count);
        }
      });

  void saveToFile(String path, [List<ImageOperation> operations = const []]) => ffi.using((arena) {
    final failedIndex = arena<ffi.UintPtr>();
    final code = pixer_batch_save(
      _handle,
      _operations(arena, operations),
      operations.length,
      path.toNativeUtf8(allocator: arena).cast(),
      failedIndex,
    );
    checkBatchError(code, failedIndex.value, operations, 'saveToFile (path: $path)');
  });

  static ffi.Pointer<PixerOperation> _operations(ffi.Arena arena, List<ImageOperation> commands) {
    if (commands.isEmpty) return ffi.nullptr;
    final pointer = arena<PixerOperation>(commands.length);
    for (var i = 0; i < commands.length; i++) {
      final slots = encodeOperation(commands[i]);
      pointer[i]
        ..kind = slots.kind
        ..arg0 = slots.arg0
        ..arg1 = slots.arg1
        ..arg2 = slots.arg2
        ..arg3 = slots.arg3
        ..scalar = slots.scalar;
    }
    return pointer;
  }

  void dispose() {
    _finalizer.detach(this);
    pixer_free(_handle);
  }
}
