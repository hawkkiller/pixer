import 'dart:typed_data';

import '../enums.dart';
import '../image_metadata.dart';
import '../image_operation.dart';
import '../pixer_encoder.dart';
import '../pixer_exception.dart';
import 'wasm_runtime.dart';

/// Owns a handle in the initialized WASM instance.
final class BackendImage {
  BackendImage._(this._handle) {
    if (_handle == 0) throw UnknownException('operation: image');
  }
  final int _handle;
  static WasmRuntime? _runtime;
  static Future<WasmRuntime>? _initializing;

  /// Loads the Pixer WebAssembly module.
  ///
  /// Pass module bytes (for example from Flutter's asset bundle) or a URL.
  /// With neither argument, `pixer.wasm` is fetched relative to the page.
  static Future<void> initialize({Uint8List? wasmBytes, Uri? wasmUri}) async {
    if (_runtime != null) return;
    if (wasmBytes != null && wasmUri != null) {
      throw ArgumentError('Provide wasmBytes or wasmUri, not both');
    }
    final initializing = _initializing ??= WasmRuntime.load(
      bytes: wasmBytes,
      uri: wasmBytes == null ? (wasmUri ?? Uri.parse('pixer.wasm')) : null,
    );
    try {
      _runtime = await initializing;
    } finally {
      if (_runtime == null) _initializing = null;
    }
  }

  static WasmRuntime get _wasm =>
      _runtime ??
      (throw StateError(
        'Call and await Pixer.initialize() before using Pixer on web',
      ));

  factory BackendImage.fromFile(String path) => throw UnsupportedError(
    'Pixer.fromFile is unavailable on web; use Pixer.fromMemory',
  );

  factory BackendImage.fromMemory(Uint8List bytes, [ImageFormatEnum? format]) =>
      BackendImage._(_wasm.loadImage(bytes, format));

  PixerMetadata getMetadata() => _wasm.metadata(_handle);

  BackendImage transform(ImageOperation op) => BackendImage._(switch (op.kind) {
    PixerOperationKind.Resize => _wasm.resize(
      _handle,
      op.arg0,
      op.arg1,
      op.arg2,
    ),
    PixerOperationKind.ResizeExact => _wasm.resizeExact(
      _handle,
      op.arg0,
      op.arg1,
      op.arg2,
    ),
    PixerOperationKind.Crop => _wasm.crop(
      _handle,
      op.arg0,
      op.arg1,
      op.arg2,
      op.arg3,
    ),
    PixerOperationKind.Rotate90 => _wasm.rotate90(_handle),
    PixerOperationKind.Rotate180 => _wasm.rotate180(_handle),
    PixerOperationKind.Rotate270 => _wasm.rotate270(_handle),
    PixerOperationKind.FlipHorizontal => _wasm.flipHorizontal(_handle),
    PixerOperationKind.FlipVertical => _wasm.flipVertical(_handle),
    PixerOperationKind.Blur => _wasm.blur(_handle, op.scalar),
    PixerOperationKind.Brightness => _wasm.brightness(_handle, op.arg0),
    PixerOperationKind.Contrast => _wasm.contrast(_handle, op.scalar),
    PixerOperationKind.Grayscale => _wasm.grayscale(_handle),
    PixerOperationKind.Invert => _wasm.invert(_handle),
  });

  BackendImage batchToImage(List<ImageOperation> operations) =>
      BackendImage._(_wasm.batchToImage(_handle, operations));

  Uint8List encode(PixerEncoder encoder, [List<ImageOperation>? operations]) =>
      operations == null
      ? _wasm.encode(_handle, encoder.format, encoder.jpegQuality)
      : _wasm.batchEncode(
          _handle,
          operations,
          encoder.format,
          encoder.jpegQuality,
        );

  void saveToFile(String path, [List<ImageOperation>? operations]) =>
      throw UnsupportedError(
        'File writes are unavailable on web; use encode instead',
      );

  void dispose() => _wasm.freeHandle(_handle);
}
