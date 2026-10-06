@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pixer/pixer.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await expectLater(
      Pixer.initialize(wasmBytes: Uint8List(1)),
      throwsA(anything),
    );
    // A valid WASM module without an ABI export must fail before any image call.
    await expectLater(
      Pixer.initialize(
        wasmBytes: Uint8List.fromList([0, 97, 115, 109, 1, 0, 0, 0]),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('no usable ABI version'),
        ),
      ),
    );
    // A minimal module exporting pixer_abi_version() => 0.
    final name = utf8.encode('pixer_abi_version');
    await expectLater(
      Pixer.initialize(
        wasmBytes: Uint8List.fromList([
          0,
          97,
          115,
          109,
          1,
          0,
          0,
          0,
          1,
          5,
          1,
          96,
          0,
          1,
          127,
          3,
          2,
          1,
          0,
          7,
          name.length + 4,
          1,
          name.length,
          ...name,
          0,
          0,
          10,
          6,
          1,
          4,
          0,
          65,
          0,
          11,
        ]),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('expected 3, got 0'),
        ),
      ),
    );
    await Future.wait([
      Pixer.initialize(wasmUri: Uri.parse('pixer.wasm')),
      Pixer.initialize(wasmUri: Uri.parse('pixer.wasm')),
    ]);
  });

  Pixer load() => Pixer.fromMemory(
    base64Decode(
      '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A9Iooor2D58//2Q==',
    ),
  );

  test('loads, transforms, and encodes through WebAssembly', () {
    final source = load();
    final transformed = source.resizeExact(4, 2).rotate90().toImage();
    final encoded = source
        .resizeExact(4, 2)
        .rotate90()
        .encode(const PixerPngEncoder());
    final decoded = Pixer.fromMemory(encoded);

    expect((transformed.width, transformed.height), (2, 4));
    expect((decoded.width, decoded.height), (2, 4));

    decoded.dispose();
    transformed.dispose();
    source.dispose();
  });

  test('supports every operation and encoder', () {
    final source = load();
    final images = <Pixer>[
      source.resize(1, 1).toImage(),
      source.resizeExact(2, 2).toImage(),
      source.crop(0, 0, 1, 1).toImage(),
      source.rotate90().toImage(),
      source.rotate180().toImage(),
      source.rotate270().toImage(),
      source.flipHorizontal().toImage(),
      source.flipVertical().toImage(),
      source.blur(0).toImage(),
      source.brightness(1).toImage(),
      source.contrast(1).toImage(),
      source.grayscale().toImage(),
      source.invert().toImage(),
    ];
    final encoders = <PixerEncoder>[
      const PixerPngEncoder(),
      PixerJpegEncoder(),
      const PixerGifEncoder(),
      const PixerWebPEncoder(),
      const PixerBmpEncoder(),
      const PixerIcoEncoder(),
      const PixerTiffEncoder(),
    ];

    for (final encoder in encoders) {
      expect(source.encode(encoder), isNotEmpty);
    }
    for (final image in images) {
      image.dispose();
    }
    source.dispose();
    expect(() => source.getMetadata(), throwsA(isA<InvalidPointerException>()));
  });

  test('handles signed and failing pipelines', () {
    final source = load();
    final darkened = source.brightness(-1).toImage();

    expect((darkened.width, darkened.height), (1, 1));
    expect(
      () => source.crop(0, 0, 2, 2).toImage(),
      throwsA(isA<InvalidDimensionsException>()),
    );

    darkened.dispose();
    source.dispose();
  });
}
