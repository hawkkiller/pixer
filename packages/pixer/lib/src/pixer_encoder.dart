import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/bindings.dart';
import 'pixer_exception.dart';

/// Encodes a [Pixer] image to a specific output format.
sealed class PixerEncoder {
  const PixerEncoder();

  /// Creates the default encoder for [format].
  factory PixerEncoder.fromFormat(ImageFormatEnum format) {
    return switch (format) {
      ImageFormatEnum.Png => const PixerPngEncoder(),
      ImageFormatEnum.Jpeg => PixerJpegEncoder(),
      ImageFormatEnum.Gif => const PixerGifEncoder(),
      ImageFormatEnum.WebP => const PixerWebPEncoder(),
      ImageFormatEnum.Bmp => const PixerBmpEncoder(),
      ImageFormatEnum.Ico => const PixerIcoEncoder(),
      ImageFormatEnum.Tiff => const PixerTiffEncoder(),
    };
  }

  /// Native image format used by this encoder.
  ImageFormatEnum get format;

  /// Encodes [handle] to a byte buffer.
  Uint8List encode(ffi.Pointer<ImageHandle> handle) {
    return _encodeWith(
      write: (outDataPtr, outLenPtr) {
        return pixer_write_to(handle, format.value, outDataPtr, outLenPtr);
      },
      context: 'format: ${format.name}',
    );
  }

  Uint8List _encodeWith({
    required int Function(
      ffi.Pointer<ffi.Pointer<ffi.Uint8>> outDataPtr,
      ffi.Pointer<ffi.UintPtr> outLenPtr,
    )
    write,
    required String context,
  }) {
    final outDataPtr = malloc.allocate<ffi.Pointer<ffi.Uint8>>(
      ffi.sizeOf<ffi.Pointer<ffi.Uint8>>(),
    );
    final outLenPtr = malloc.allocate<ffi.UintPtr>(ffi.sizeOf<ffi.UintPtr>());

    try {
      final error = ImageErrorCode.fromValue(write(outDataPtr, outLenPtr));
      if (error != ImageErrorCode.Success) {
        throw PixerException.fromCode(error, context: context);
      }

      final dataPtr = outDataPtr.value;
      final len = outLenPtr.value;
      if (dataPtr == ffi.nullptr || len == 0) {
        throw UnknownException('operation: encode');
      }

      try {
        return Uint8List.fromList(dataPtr.asTypedList(len));
      } finally {
        // Free the buffer allocated by Rust.
        pixer_free_buffer(dataPtr, len);
      }
    } finally {
      malloc.free(outDataPtr);
      malloc.free(outLenPtr);
    }
  }
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

  @override
  Uint8List encode(ffi.Pointer<ImageHandle> handle) {
    return _encodeWith(
      write: (outDataPtr, outLenPtr) {
        return pixer_write_to_with_quality(
          handle,
          format.value,
          quality,
          outDataPtr,
          outLenPtr,
        );
      },
      context: 'format: ${format.name}, quality: $quality',
    );
  }
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
