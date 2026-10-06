import 'dart:js_interop';
import 'dart:typed_data';

import '../abi.dart';

import '../enums.dart';
import '../image_metadata.dart';
import '../pixer_exception.dart';
import '../image_operation.dart';
import '../raw_pixels.dart';

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
  external int pixer_load_from_memory(
    int data,
    int length,
    int format,
    int outImage,
  );
  external int pixer_from_pixels(
    int width,
    int height,
    int data,
    int length,
    int layout,
    int outImage,
  );
  external int pixer_get_metadata(int handle, int metadata);
  external int pixer_batch_to_image(
    int handle,
    int operations,
    int count,
    int outImage,
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
  external int pixer_batch_to_rgba(
    int handle,
    int operations,
    int count,
    int outImage,
    int outData,
    int failedIndex,
  );
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

  T _withAllocation<T>(
    int size,
    T Function(int pointer) use, {
    int alignment = 1,
  }) {
    final pointer = _exports.pixer_alloc(size, alignment);
    if (pointer == 0) throw StateError('WebAssembly allocation failed');
    try {
      return use(pointer);
    } finally {
      _exports.pixer_dealloc(pointer, size, alignment);
    }
  }

  void freeHandle(int handle) => _exports.pixer_free(handle);

  // One block: the out-handle slot, then the encoded bytes.
  int loadImage(Uint8List data, ImageFormatEnum? format) =>
      _withAllocation(4 + data.length, (pointer) {
        Uint8List.view(_buffer, pointer + 4, data.length).setAll(0, data);
        final code = _exports.pixer_load_from_memory(
          pointer + 4,
          data.length,
          format?.value ?? PIXER_FORMAT_DETECT,
          pointer,
        );
        checkImageError(code, 'input: memory');
        return _u32(pointer);
      }, alignment: 4);

  // One block: the out-handle slot, then the pixels.
  int fromPixels(int width, int height, Uint8List data, PixelLayout layout) =>
      _withAllocation(4 + data.length, (pointer) {
        Uint8List.view(_buffer, pointer + 4, data.length).setAll(0, data);
        final code = _exports.pixer_from_pixels(
          width,
          height,
          pointer + 4,
          data.length,
          layout.value,
          pointer,
        );
        checkImageError(code, 'input: ${width}x$height ${layout.name} pixels');
        return _u32(pointer);
      }, alignment: 4);

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

  Uint8List encode(
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
        _u32(output + 8),
        operations,
        'encode (format: ${format.name})',
      );
      return _copyOutput(output);
    }, alignment: 4);
  });

  int batchToImage(int handle, List<ImageOperation> operations) {
    return _withOperations(operations, (operationsPointer) {
      return _withAllocation(8, (output) {
        final code = _exports.pixer_batch_to_image(
          handle,
          operationsPointer,
          operations.length,
          output,
          output + 4,
        );
        checkBatchError(code, _u32(output + 4), operations, 'toImage');
        return _u32(output);
      }, alignment: 4);
    });
  }

  RawPixels toRgba(int handle, List<ImageOperation> operations) {
    final (image, data) = _withOperations(operations, (operationsPointer) {
      return _withAllocation(12, (output) {
        final code = _exports.pixer_batch_to_rgba(
          handle,
          operationsPointer,
          operations.length,
          output,
          output + 4,
          output + 8,
        );
        checkBatchError(code, _u32(output + 8), operations, 'toRgba');
        return (_u32(output), _u32(output + 4));
      }, alignment: 4);
    });
    try {
      final PixerMetadata(:width, :height) = metadata(image);
      return RawPixels(
        width,
        height,
        Uint8List.fromList(Uint8List.view(_buffer, data, width * height * 4)),
      );
    } finally {
      _exports.pixer_free(image);
    }
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
    final pointer = _u32(output);
    final length = _u32(output + 4);
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

  int _u32(int pointer) => _data(pointer, 4).getUint32(0, Endian.little);

  static void _writeOperation(ImageOperation op, ByteData data, int offset) {
    final slots = encodeOperation(op);
    data
      ..setUint32(offset, slots.kind, Endian.little)
      ..setFloat64(offset + 40, slots.scalar, Endian.little);
    _writeInt64(data, offset + 8, slots.arg0);
    _writeInt64(data, offset + 16, slots.arg1);
    _writeInt64(data, offset + 24, slots.arg2);
    _writeInt64(data, offset + 32, slots.arg3);
  }

  // dart2js does not implement ByteData.setInt64. Operation arguments are
  // validated to 32 bits, so writing the low word plus sign extension is exact.
  static void _writeInt64(ByteData data, int offset, int value) {
    data
      ..setUint32(offset, value & 0xFFFFFFFF, Endian.little)
      ..setUint32(offset + 4, value < 0 ? 0xFFFFFFFF : 0, Endian.little);
  }
}
