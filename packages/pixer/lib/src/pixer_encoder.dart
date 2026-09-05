import 'enums.dart';

/// Output configuration passed to Pixer.encode or PixerBatch.encode.
sealed class PixerEncoder {
  const PixerEncoder();

  factory PixerEncoder.fromFormat(ImageFormatEnum format) => switch (format) {
    ImageFormatEnum.Png => const PixerPngEncoder(),
    ImageFormatEnum.Jpeg => PixerJpegEncoder(),
    ImageFormatEnum.Gif => const PixerGifEncoder(),
    ImageFormatEnum.WebP => const PixerWebPEncoder(),
    ImageFormatEnum.Bmp => const PixerBmpEncoder(),
    ImageFormatEnum.Ico => const PixerIcoEncoder(),
    ImageFormatEnum.Tiff => const PixerTiffEncoder(),
  };

  /// Output container format.
  ImageFormatEnum get format;

  /// Quality passed to the backend; ignored by non-JPEG encoders.
  int get jpegQuality => 0;
}

/// JPEG output with quality between 1 and 100.
final class PixerJpegEncoder extends PixerEncoder {
  PixerJpegEncoder({this.quality = 75}) {
    if (quality < 1 || quality > 100) {
      throw RangeError.range(quality, 1, 100, 'quality');
    }
  }

  final int quality;

  @override
  ImageFormatEnum get format => ImageFormatEnum.Jpeg;

  @override
  int get jpegQuality => quality;
}

final class PixerPngEncoder extends PixerEncoder {
  const PixerPngEncoder();
  @override
  ImageFormatEnum get format => ImageFormatEnum.Png;
}

final class PixerGifEncoder extends PixerEncoder {
  const PixerGifEncoder();
  @override
  ImageFormatEnum get format => ImageFormatEnum.Gif;
}

final class PixerWebPEncoder extends PixerEncoder {
  const PixerWebPEncoder();
  @override
  ImageFormatEnum get format => ImageFormatEnum.WebP;
}

final class PixerBmpEncoder extends PixerEncoder {
  const PixerBmpEncoder();
  @override
  ImageFormatEnum get format => ImageFormatEnum.Bmp;
}

final class PixerIcoEncoder extends PixerEncoder {
  const PixerIcoEncoder();
  @override
  ImageFormatEnum get format => ImageFormatEnum.Ico;
}

final class PixerTiffEncoder extends PixerEncoder {
  const PixerTiffEncoder();
  @override
  ImageFormatEnum get format => ImageFormatEnum.Tiff;
}
