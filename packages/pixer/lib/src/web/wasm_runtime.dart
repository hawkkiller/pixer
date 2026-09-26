import 'dart:js_interop';
import 'dart:typed_data';

import '../abi.dart';

import '../enums.dart';
import '../image_metadata.dart';
import '../pixer_exception.dart';
import '../image_operation.dart';

@JS('WebAssembly.instantiate')
external JSPromise<JSObject> _instantiate(JSObject bytes, JSObject imports);

@JS('fetch')
external JSPromise<_Response> _fetch(String url);

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _InstantiatedSource._(JSObject _) implements JSObject {
  external _Instance get instance;
}

extension type _Instance._(JSObject _) implements JSObject {
  external _Exports get exports;
}

extension type _Memory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

extension type _Exports._(JSObject _) implements JSObject {
  external int pixer_abi_version();
  external _Memory get memory;
  external int pixer_alloc(int size, int alignment);
  external void pixer_dealloc(int pointer, int size, int alignment);
  external void pixer_free(int handle);
  external void pixer_free_buffer(int pointer, int length);
  external int pixer_load_from_memory_with_error(
    int data,
    int length,
    int error,
  );
  external int pixer_load_from_memory_with_format_and_error(
    int data,
    int length,
    int format,
    int error,
  );
  external int pixer_get_metadata(int handle, int metadata);
  external int pixer_encode(int handle, int format, int outData, int outLength);
  external int pixer_encode_jpeg(
    int handle,
    int quality,
    int outData,
    int outLength,
  );
  external int pixer_batch_to_image(
    int handle,
    int operations,
    int count,
    int error,
    int failedIndex,
  );
  external int pixer_batch_encode(
    int handle,
    int operations,
    int count,
    int format,
    int quality,
    int outData,
    int outLength,
    int failedIndex,
  );
  external int pixer_resize(int handle, int width, int height, int filter);
  external int pixer_resize_exact(
    int handle,
    int width,
    int height,
    int filter,
  );
  external int pixer_crop_imm(int handle, int x, int y, int width, int height);
  external int pixer_rotate90(int handle);
  external int pixer_rotate180(int handle);
  external int pixer_rotate270(int handle);
  external int pixer_fliph(int handle);
  external int pixer_flipv(int handle);
  external int pixer_blur(int handle, double sigma);
  external int pixer_brighten(int handle, int value);
  external int pixer_adjust_contrast(int handle, double contrast);
  external int pixer_grayscale(int handle);
  external int pixer_invert(int handle);
}

final class WasmRuntime {
  WasmRuntime._(this._exports);

  final _Exports _exports;

  static Future<WasmRuntime> load({Uint8List? bytes, Uri? uri}) async {
    if ((bytes == null) == (uri == null)) {
      throw ArgumentError('Provide exactly one of wasmBytes or wasmUri');
    }

    final JSObject moduleBytes;
    if (bytes != null) {
      moduleBytes = bytes.toJS;
    } else {
      final response = await _fetch(uri.toString()).toDart;
      if (!response.ok) {
        throw StateError(
          'Failed to load Pixer WebAssembly module: HTTP ${response.status}',
        );
      }
      moduleBytes = await response.arrayBuffer().toDart;
    }

    final imports = <String, Object?>{}.jsify()! as JSObject;
    final source = _InstantiatedSource._(
      await _instantiate(moduleBytes, imports).toDart,
    );
    final exports = source.instance.exports;
    final int version;
    try {
      version = exports.pixer_abi_version();
    } catch (error) {
      throw StateError(
        'Pixer WASM has no usable ABI version. Rebuild or download pixer.wasm '
        'matching this Pixer package. Cause: $error',
      );
    }
    checkPixerAbi(version);
    return WasmRuntime._(exports);
  }

  ByteBuffer get _buffer => _exports.memory.buffer.toDart;

  int _allocate(int size, {int alignment = 1}) {
    final pointer = _exports.pixer_alloc(size, alignment);
    if (pointer == 0) throw StateError('WebAssembly allocation failed');
    return pointer;
  }

  T _withAllocation<T>(
    int size,
    T Function(int pointer) use, {
    int alignment = 1,
  }) {
    final pointer = _allocate(size, alignment: alignment);
    try {
      return use(pointer);
    } finally {
      _exports.pixer_dealloc(pointer, size, alignment);
    }
  }

  void freeHandle(int handle) => _exports.pixer_free(handle);

  int loadImage(Uint8List data, ImageFormatEnum? format) {
    return _withAllocation(data.length, (dataPointer) {
      Uint8List.view(_buffer, dataPointer, data.length).setAll(0, data);
      return _withAllocation(4, (errorPointer) {
        final handle = format == null
            ? _exports.pixer_load_from_memory_with_error(
                dataPointer,
                data.length,
                errorPointer,
              )
            : _exports.pixer_load_from_memory_with_format_and_error(
                dataPointer,
                data.length,
                format.value,
                errorPointer,
              );
        if (handle == 0) {
          checkImageError(
            _data(errorPointer, 4).getUint32(0, Endian.little),
            'input: memory',
          );
        }
        return handle;
      }, alignment: 4);
    });
  }

  PixerMetadata metadata(int handle) => _withAllocation(12, (pointer) {
    final code = _exports.pixer_get_metadata(handle, pointer);
    checkImageError(code, 'operation: metadata');
    final data = _data(pointer, 12);
    return PixerMetadata(
      width: data.getUint32(0, Endian.little),
      height: data.getUint32(4, Endian.little),
      colorType: ColorType.fromValue(data.getUint8(8)),
    );
  }, alignment: 4);

  Uint8List encode(int handle, ImageFormatEnum format, int quality) {
    return _withAllocation(8, (output) {
      final code = format == ImageFormatEnum.Jpeg
          ? _exports.pixer_encode_jpeg(handle, quality, output, output + 4)
          : _exports.pixer_encode(handle, format.value, output, output + 4);
      checkImageError(code, 'format: ${format.name}');
      return _copyOutput(output);
    }, alignment: 4);
  }

  Uint8List batchEncode(
    int handle,
    List<ImageOperation> operations,
    ImageFormatEnum format,
    int quality,
  ) => _withOperations(operations, (operationsPointer) {
    return _withAllocation(12, (output) {
      final code = _exports.pixer_batch_encode(
        handle,
        operationsPointer,
        operations.length,
        format.value,
        quality,
        output,
        output + 4,
        output + 8,
      );
      checkBatchError(
        code,
        _data(output + 8, 4).getUint32(0, Endian.little),
        operations,
        'encode',
      );
      return _copyOutput(output);
    }, alignment: 4);
  });

  int batchToImage(int handle, List<ImageOperation> operations) {
    return _withOperations(operations, (operationsPointer) {
      return _withAllocation(8, (output) {
        final result = _exports.pixer_batch_to_image(
          handle,
          operationsPointer,
          operations.length,
          output,
          output + 4,
        );
        checkBatchError(
          _data(output, 4).getUint32(0, Endian.little),
          _data(output + 4, 4).getUint32(0, Endian.little),
          operations,
          'toImage',
        );
        return result;
      }, alignment: 4);
    });
  }

  T _withOperations<T>(
    List<ImageOperation> operations,
    T Function(int pointer) use,
  ) {
    if (operations.isEmpty) return use(0);
    return _withAllocation(operations.length * 48, (pointer) {
      final data = _data(pointer, operations.length * 48);
      for (var index = 0; index < operations.length; index++) {
        _writeOperation(operations[index], data, index * 48);
      }
      return use(pointer);
    }, alignment: 8);
  }

  Uint8List _copyOutput(int output) {
    final data = _data(output, 8);
    final pointer = data.getUint32(0, Endian.little);
    final length = data.getUint32(4, Endian.little);
    if (pointer == 0 || length == 0)
      throw UnknownException('operation: encode');
    try {
      return Uint8List.fromList(Uint8List.view(_buffer, pointer, length));
    } finally {
      _exports.pixer_free_buffer(pointer, length);
    }
  }

  ByteData _data(int pointer, int length) =>
      ByteData.view(_buffer, pointer, length);

  int resize(int h, int w, int height, int filter) =>
      _exports.pixer_resize(h, w, height, filter);
  int resizeExact(int h, int w, int height, int filter) =>
      _exports.pixer_resize_exact(h, w, height, filter);
  int crop(int h, int x, int y, int w, int height) =>
      _exports.pixer_crop_imm(h, x, y, w, height);
  int rotate90(int h) => _exports.pixer_rotate90(h);
  int rotate180(int h) => _exports.pixer_rotate180(h);
  int rotate270(int h) => _exports.pixer_rotate270(h);
  int flipHorizontal(int h) => _exports.pixer_fliph(h);
  int flipVertical(int h) => _exports.pixer_flipv(h);
  int blur(int h, double sigma) => _exports.pixer_blur(h, sigma);
  int brightness(int h, int value) => _exports.pixer_brighten(h, value);
  int contrast(int h, double value) => _exports.pixer_adjust_contrast(h, value);
  int grayscale(int h) => _exports.pixer_grayscale(h);
  int invert(int h) => _exports.pixer_invert(h);

  static void _writeOperation(ImageOperation op, ByteData data, int offset) {
    data
      ..setUint32(offset, op.kind.value, Endian.little)
      ..setFloat64(offset + 40, op.scalar, Endian.little);
    _writeInt64(data, offset + 8, op.arg0);
    _writeInt64(data, offset + 16, op.arg1);
    _writeInt64(data, offset + 24, op.arg2);
    _writeInt64(data, offset + 32, op.arg3);
  }

  // dart2js does not implement ByteData.setInt64. Operation arguments are
  // validated to 32 bits, so writing the low word plus sign extension is exact.
  static void _writeInt64(ByteData data, int offset, int value) {
    data
      ..setUint32(offset, value & 0xFFFFFFFF, Endian.little)
      ..setUint32(offset + 4, value < 0 ? 0xFFFFFFFF : 0, Endian.little);
  }
}
