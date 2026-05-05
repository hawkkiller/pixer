import 'bindings/bindings.dart';

/// Encodes a [Pixer] image to a specific output format.
sealed class PixerEncoder {
  const PixerEncoder();

  /// Native image format used by this encoder.
  ImageFormatEnum get format;
}

/// Encodes an image as JPEG.
///
/// [quality] must be between 1 and 100.
final class PixerJpegEncoder extends PixerEncoder {
  PixerJpegEncoder({this.quality = 75}) {
    if (quality < 1 || quality > 100) {
      throw RangeError.range(quality, 1, 100, 'quality');
    }
  }

  /// JPEG encoding quality, from 1 (lowest) to 100 (highest).
  final int quality;

  @override
  ImageFormatEnum get format => ImageFormatEnum.Jpeg;
}

/// Encodes an image as PNG.
final class PixerPngEncoder extends PixerEncoder {
  const PixerPngEncoder();

  @override
  ImageFormatEnum get format => ImageFormatEnum.Png;
}

/// Encodes an image as GIF.
final class PixerGifEncoder extends PixerEncoder {
  const PixerGifEncoder();

  @override
  ImageFormatEnum get format => ImageFormatEnum.Gif;
}

/// Encodes an image as WebP.
final class PixerWebPEncoder extends PixerEncoder {
  const PixerWebPEncoder();

  @override
  ImageFormatEnum get format => ImageFormatEnum.WebP;
}

/// Encodes an image as BMP.
final class PixerBmpEncoder extends PixerEncoder {
  const PixerBmpEncoder();

  @override
  ImageFormatEnum get format => ImageFormatEnum.Bmp;
}

/// Encodes an image as ICO.
final class PixerIcoEncoder extends PixerEncoder {
  const PixerIcoEncoder();

  @override
  ImageFormatEnum get format => ImageFormatEnum.Ico;
}

/// Encodes an image as TIFF.
final class PixerTiffEncoder extends PixerEncoder {
  const PixerTiffEncoder();

  @override
  ImageFormatEnum get format => ImageFormatEnum.Tiff;
}
