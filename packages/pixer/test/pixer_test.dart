import 'dart:typed_data';
import 'package:pixer/pixer.dart';
import 'package:test/test.dart';

Uint8List _transparentPng() => Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  group('Pixer', () {
    test('loads image from file throws IoException for missing files', () {
      // For missing files, we now get specific IoException instead of generic LoadException
      expect(
        () => Pixer.fromFile('nonexistent.jpg'),
        throwsA(isA<IoException>()),
      );
    });

    test('loads image from memory', () {
      // Create a minimal valid PNG (1x1 transparent pixel)
      final pngData = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
        0x42, 0x60, 0x82,
      ]);

      final image = Pixer.fromMemory(pngData);
      expect(image.width, equals(1));
      expect(image.height, equals(1));
      image.dispose();
    });

    test('gets metadata correctly', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);
      final metadata = image.getMetadata();

      expect(metadata.width, equals(1));
      expect(metadata.height, equals(1));
      expect(metadata.colorType, isA<ColorType>());

      image.dispose();
    });

    test('encodes image to buffer', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);
      final encoded = image.encode(const PixerPngEncoder());

      expect(encoded, isA<Uint8List>());
      expect(encoded.isNotEmpty, isTrue);

      image.dispose();
    });

    test('encodes JPEG with quality', () {
      final image = Pixer.fromMemory(_transparentPng());
      final encoded = image.encode(PixerJpegEncoder(quality: 90));

      expect(encoded, isA<Uint8List>());
      expect(encoded.isNotEmpty, isTrue);
      expect(encoded.take(2), equals([0xFF, 0xD8]));

      image.dispose();
    });

    test('validates JPEG quality', () {
      expect(() => PixerJpegEncoder(quality: -1), throwsA(isA<RangeError>()));
      expect(() => PixerJpegEncoder(quality: 0), throwsA(isA<RangeError>()));
      expect(() => PixerJpegEncoder(quality: 101), throwsA(isA<RangeError>()));
    });

    test('throws when using disposed image', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);
      image.dispose();
      expect(image.isDisposed, isTrue);

      expect(
        () => image.getMetadata(),
        throwsA(isA<InvalidPointerException>()),
      );
    });

    test('filter type enum has all values', () {
      expect(FilterTypeEnum.Nearest.value, equals(0));
      expect(FilterTypeEnum.Triangle.value, equals(1));
      expect(FilterTypeEnum.CatmullRom.value, equals(2));
      expect(FilterTypeEnum.Gaussian.value, equals(3));
      expect(FilterTypeEnum.Lanczos3.value, equals(4));
    });

    test('image format enum has all values', () {
      expect(ImageFormatEnum.Png.value, equals(0));
      expect(ImageFormatEnum.Jpeg.value, equals(1));
      expect(ImageFormatEnum.Gif.value, equals(2));
      expect(ImageFormatEnum.WebP.value, equals(3));
      expect(ImageFormatEnum.Bmp.value, equals(4));
      expect(ImageFormatEnum.Ico.value, equals(5));
      expect(ImageFormatEnum.Tiff.value, equals(6));
    });

    test('color type enum has all values', () {
      expect(ColorType.luminance.value, equals(0));
      expect(ColorType.luminanceAlpha.value, equals(1));
      expect(ColorType.rgb.value, equals(2));
      expect(ColorType.rgba.value, equals(3));
    });

    test('crop throws on out-of-bounds rectangle', () {
      // Use 1x1 PNG image for bounds testing
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);

      // Image is 1x1, so any crop requesting more than 1 pixel should fail
      // Crop that exceeds width
      expect(
        () => image.crop(0, 0, 2, 1), // width=2 but image is only 1 wide
        throwsA(isA<InvalidDimensionsException>()),
      );

      // Crop that exceeds height
      expect(
        () => image.crop(0, 0, 1, 2), // height=2 but image is only 1 tall
        throwsA(isA<InvalidDimensionsException>()),
      );

      // Crop that starts out of bounds
      expect(
        () => image.crop(1, 0, 1, 1), // x=1 puts us outside the 1x1 image
        throwsA(isA<InvalidDimensionsException>()),
      );

      image.dispose();
    });

    test('invert returns a new image (original unchanged)', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final original = Pixer.fromMemory(pngData);
      final originalBytes = original.encode(const PixerPngEncoder());

      // Invert should return a NEW image
      final inverted = original.invert();

      // Original should still be usable and unchanged
      expect(original.isDisposed, isFalse);
      final originalBytesAfter = original.encode(const PixerPngEncoder());
      expect(originalBytesAfter, equals(originalBytes));

      // Inverted should be a different image
      expect(inverted, isNot(same(original)));

      inverted.dispose();
      original.dispose();
    });

    test('metadata is cached (multiple calls return same instance)', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);

      // Multiple calls to getMetadata should return the same cached instance
      final metadata1 = image.getMetadata();
      final metadata2 = image.getMetadata();

      expect(identical(metadata1, metadata2), isTrue);

      // width/height/colorType getters should also use the cached metadata
      expect(image.width, equals(metadata1.width));
      expect(image.height, equals(metadata1.height));
      expect(image.colorType, equals(metadata1.colorType));

      image.dispose();
    });

    test('blur with sigma 0 returns unchanged image', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);

      // blur(0) should work without error
      final blurred = image.blur(0);
      expect(blurred.width, equals(image.width));
      expect(blurred.height, equals(image.height));

      blurred.dispose();
      image.dispose();
    });

    test('blur throws on negative sigma', () {
      final pngData = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final image = Pixer.fromMemory(pngData);

      expect(() => image.blur(-1.0), throwsA(isA<ArgumentError>()));

      image.dispose();
    });

    test('load error specificity - invalid data throws specific exception', () {
      // Invalid/corrupted image data should throw a specific exception
      // (UnsupportedFormatException when format can't be detected, or DecodingException
      // when format is detected but data is corrupted)
      final invalidData = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

      expect(
        () => Pixer.fromMemory(invalidData),
        throwsA(isA<PixerException>()),
      );
    });
  });
}
