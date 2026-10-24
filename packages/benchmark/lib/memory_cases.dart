import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:pixer/pixer.dart';

/// Operations measured by `bin/memory.dart`, in report order.
const memoryOperations = [
  'decode',
  'resize_800x600',
  'resize_3840x2160',
  'encode_jpeg',
  'pipeline_4k',
];

/// Libraries measured by `bin/memory.dart`.
const memoryLibraries = ['pixer', 'image'];

/// Reads the input and returns [operation] for [library].
///
/// Every operation starts from the encoded JPEG bytes, so a resize or encode
/// includes decoding its source. Decoding up front would leave decoder garbage
/// on the Dart heap (and freed blocks in malloc) that the measured operation
/// could reuse, which would hide part of its cost. The returned function
/// returns the result, which the caller keeps alive until memory has been
/// read. Resizes use an exact cubic filter and encodes use JPEG quality 85 in
/// both libraries, as in the timing benchmark.
Object? Function() prepareMemoryCase(String library, String operation) {
  final bytes = File('assets/example_img.jpg').readAsBytesSync();
  return switch ((library, operation)) {
    ('pixer', 'decode') => () => Pixer.fromMemory(bytes),
    ('pixer', 'resize_800x600') => () => _pixerResize(bytes, 800, 600),
    ('pixer', 'resize_3840x2160') => () => _pixerResize(bytes, 3840, 2160),
    ('pixer', 'encode_jpeg') => () => _pixer(bytes, (image) => image.encode(_pixerJpeg)),
    ('pixer', 'pipeline_4k') => () => _pixer(
      bytes,
      (image) =>
          image.resizeExact(3840, 2160, filter: FilterTypeEnum.CatmullRom).encode(_pixerJpeg),
    ),
    ('image', 'decode') => () => decodeImage(bytes),
    ('image', 'resize_800x600') => () => _imageResize(decodeImage(bytes)!, 800, 600),
    ('image', 'resize_3840x2160') => () => _imageResize(decodeImage(bytes)!, 3840, 2160),
    ('image', 'encode_jpeg') => () => encodeJpg(decodeImage(bytes)!, quality: 85),
    ('image', 'pipeline_4k') => () => encodeJpg(
      _imageResize(decodeImage(bytes)!, 3840, 2160),
      quality: 85,
    ),
    _ => throw ArgumentError('Unknown memory case: $library $operation'),
  };
}

final _pixerJpeg = PixerJpegEncoder(quality: 85);

/// Decodes [bytes], applies [operation], and disposes the decoded source.
T _pixer<T>(Uint8List bytes, T Function(Pixer image) operation) {
  final image = Pixer.fromMemory(bytes);
  try {
    return operation(image);
  } finally {
    image.dispose();
  }
}

Pixer _pixerResize(Uint8List bytes, int width, int height) => _pixer(
  bytes,
  (image) => image.resizeExact(width, height, filter: FilterTypeEnum.CatmullRom).toImage(),
);

Image _imageResize(Image image, int width, int height) =>
    copyResize(image, width: width, height: height, interpolation: Interpolation.cubic);
