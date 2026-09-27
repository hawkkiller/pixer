import 'dart:convert';
import 'dart:typed_data';

import 'package:pixer/pixer.dart';
import 'package:test/test.dart';

Uint8List _fixture(String encoded) => base64Decode(encoded);

final _png = _fixture(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAYAAAC56t6BAAAAFUlEQVR4nGP8z8Dwn4GBgYEJRKAwADE7AgRVI0g0AAAAAElFTkSuQmCC',
);
final _jpegHeader = Uint8List.fromList([
  0xff, 0xd8, // SOI
  0xff, 0xe0, 0x00, 0x02, // Empty APP0
  0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x03, 0x00, 0x02, // SOF0
  0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00,
]);
final _gif = _fixture(
  'R0lGODdhAgADAIEAAP8AAAAAAAAAAAAAACwAAAAAAgADAAAIBgABCBwYEAA7',
);
final _webp = _fixture('UklGRhwAAABXRUJQVlA4TA8AAAAvAYAAAAcQ/Y/+ByKi/wEA');
final _lossyWebp = _fixture(
  'UklGRjwAAABXRUJQVlA4IDAAAADQAQCdASoCAAMAAkA4JaACdLoB+AADsAD+8JtD/yC0rlvAH/8SF+JC/Ehf+LmAAAA=',
);
final _extendedWebp = _fixture(
  'UklGRl4AAABXRUJQVlA4WAoAAAAQAAAAAQAAAgAAQUxQSAcAAAAAZGRkZGRkAFZQOCAwAAAA0AEAnQEqAgADAAJAOCWgAnS6AfgAA7AA/vCbQ/8gtK5bwB//EhfiQvxIX/i5gAAA',
);
final _apng = _fixture(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAYAAAC56t6BAAAACGFjVEwAAAACAAAAAPONk3AAAAAaZmNUTAAAAAAAAAACAAAAAwAAAAAAAAAAAAEACgAAUa8H6AAAABVJREFUeJxj/M/A8J+BgYGBCUSgMAAxOwIEVSNINAAAABpmY1RMAAAAAQAAAAIAAAADAAAAAAAAAAAAAQAKAADK3O08AAAAGWZkQVQAAAACeJxjZGD4/5+BgYGBCUSgMAAvPQIEBtbc6AAAAABJRU5ErkJggg==',
);
final _animatedGif = _fixture(
  'R0lGODlhAgADAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgADAAAIBgABCBwYEAAh+QQBCgABACwAAAAAAgADAIEAAP8AAAAAAAAAAAAIBgABCBwYEAA7',
);
final _animatedWebp = _fixture(
  'UklGRoQAAABXRUJQVlA4WAoAAAACAAAAAQAAAgAAQU5JTQYAAAAAAAAAAABBTk1GKAAAAAAAAAAAAAEAAAIAAGQAAAJWUDhMDwAAAC8BgAAABxD9j/4HIqL/AQBBTk1GKAAAAAAAAAAAAAEAAAIAAGQAAABWUDhMDwAAAC8BgAAABxDR//4HIqL/AQA=',
);

void main() {
  group('Pixer.probe', () {
    for (final (format, bytes) in [
      (ImageFormatEnum.Png, _png),
      (ImageFormatEnum.Jpeg, _jpegHeader),
      (ImageFormatEnum.Gif, _gif),
      (ImageFormatEnum.WebP, _webp),
    ]) {
      test('reads a still ' + format.name + ' without decoding', () {
        final header = Pixer.probe(bytes);
        expect(header.format, format);
        expect((header.width, header.height, header.frameCount), (2, 3, 1));
      });
    }

    test('reads lossy and extended still WebP containers', () {
      for (final bytes in [_lossyWebp, _extendedWebp]) {
        final header = Pixer.probe(bytes);
        expect(header.format, ImageFormatEnum.WebP);
        expect((header.width, header.height, header.frameCount), (2, 3, 1));
      }
    });

    for (final (format, bytes) in [
      (ImageFormatEnum.Png, _apng),
      (ImageFormatEnum.Gif, _animatedGif),
      (ImageFormatEnum.WebP, _animatedWebp),
    ]) {
      test('counts frames in animated ' + format.name, () {
        final header = Pixer.probe(bytes);
        expect(header.format, format);
        expect((header.width, header.height, header.frameCount), (2, 3, 2));
      });
    }

    test('reports large dimensions for callers to enforce their own limit', () {
      final oversized = Uint8List.fromList(_png);
      ByteData.sublistView(oversized).setUint32(16, 8193);
      expect(Pixer.probe(oversized).width, 8193);
    });

    test('rejects zero dimensions', () {
      final zeroWidth = Uint8List.fromList(_png);
      ByteData.sublistView(zeroWidth).setUint32(16, 0);
      expect(
        () => Pixer.probe(zeroWidth),
        throwsA(isA<InvalidDimensionsException>()),
      );
    });

    test('rejects unsupported formats', () {
      expect(
        () => Pixer.probe(Uint8List.fromList([0x42, 0x4d, 0, 0])),
        throwsA(isA<UnsupportedFormatException>()),
      );
    });

    test('rejects an empty buffer', () {
      expect(
        () => Pixer.probe(Uint8List(0)),
        throwsA(isA<DecodingException>()),
      );
    });

    test('rejects truncated headers and containers', () {
      for (final bytes in [
        _png.sublist(0, _png.length - 5),
        _jpegHeader.sublist(0, 12),
        _gif.sublist(0, _gif.length - 1),
        _webp.sublist(0, _webp.length - 1),
      ]) {
        expect(() => Pixer.probe(bytes), throwsA(isA<DecodingException>()));
      }
    });

    test('rejects a PNG animation with a false frame count', () {
      final wrongCount = Uint8List.fromList(_apng);
      ByteData.sublistView(wrongCount).setUint32(37, 3);
      expect(() => Pixer.probe(wrongCount), throwsA(isA<DecodingException>()));
    });

    test('does not decode compressed pixel data', () {
      final corruptPixels = Uint8List.fromList(_png);
      corruptPixels[44] = 0xff;
      expect(Pixer.probe(corruptPixels).format, ImageFormatEnum.Png);
    });
  });
}
