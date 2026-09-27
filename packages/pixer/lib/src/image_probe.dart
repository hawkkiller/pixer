import 'dart:typed_data';

import 'enums.dart';
import 'pixer_exception.dart';

/// Container information read from encoded image bytes without decoding pixels.
///
/// [frameCount] counts displayed frames. A still image has one frame.
final class PixerImageHeader {
  const PixerImageHeader._({
    required this.format,
    required this.width,
    required this.height,
    required this.frameCount,
  });

  /// The image container format.
  final ImageFormatEnum format;

  /// Canvas width in pixels.
  final int width;

  /// Canvas height in pixels.
  final int height;

  /// Number of displayed frames.
  final int frameCount;
}

PixerImageHeader probeImageHeader(Uint8List bytes) {
  if (bytes.isEmpty) throw DecodingException('input buffer is empty');
  final probe = _ImageProbe(bytes);
  if (probe.matches(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return probe.png();
  }
  if (probe.matches(const [0xff, 0xd8, 0xff])) return probe.jpeg();
  if (probe.matches(const [0x47, 0x49, 0x46, 0x38]) &&
      (probe.matches(const [0x37, 0x61], 4) ||
          probe.matches(const [0x39, 0x61], 4))) {
    return probe.gif();
  }
  if (probe.matches(const [0x52, 0x49, 0x46, 0x46]) &&
      probe.matches(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return probe.webp();
  }
  throw UnsupportedFormatException('input: memory');
}

final class _ImageProbe {
  _ImageProbe(this.bytes) : view = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData view;

  bool matches(List<int> signature, [int offset = 0]) {
    if (offset > bytes.length - signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  void requireBytes(int offset, int count) {
    if (offset < 0 || count < 0 || offset > bytes.length - count) {
      throw DecodingException('truncated image header');
    }
  }

  int u16be(int offset) {
    requireBytes(offset, 2);
    return view.getUint16(offset);
  }

  int u16le(int offset) {
    requireBytes(offset, 2);
    return view.getUint16(offset, Endian.little);
  }

  int u32be(int offset) {
    requireBytes(offset, 4);
    return view.getUint32(offset);
  }

  int u32le(int offset) {
    requireBytes(offset, 4);
    return view.getUint32(offset, Endian.little);
  }

  int u24le(int offset) {
    requireBytes(offset, 3);
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
  }

  String fourCc(int offset) {
    requireBytes(offset, 4);
    return String.fromCharCodes(bytes, offset, offset + 4);
  }

  PixerImageHeader header(
    ImageFormatEnum format,
    int width,
    int height,
    int frameCount,
  ) {
    if (width == 0 || height == 0) {
      throw InvalidDimensionsException('encoded image has zero dimensions');
    }
    if (frameCount == 0) {
      throw DecodingException('encoded image contains no frames');
    }
    return PixerImageHeader._(
      format: format,
      width: width,
      height: height,
      frameCount: frameCount,
    );
  }

  PixerImageHeader png() {
    var offset = 8;
    int? width;
    int? height;
    int? declaredFrames;
    var frameControls = 0;
    var hasImageData = false;
    var ended = false;

    while (offset < bytes.length) {
      requireBytes(offset, 12);
      final length = u32be(offset);
      final type = fourCc(offset + 4);
      final data = offset + 8;
      requireBytes(data, length + 4); // Includes the chunk CRC.
      if (width == null) {
        if (type != 'IHDR' || length != 13) {
          throw DecodingException('PNG must start with a 13-byte IHDR');
        }
        width = u32be(data);
        height = u32be(data + 4);
      } else {
        switch (type) {
          case 'IHDR':
            throw DecodingException('duplicate PNG IHDR');
          case 'acTL':
            if (length != 8 || declaredFrames != null || hasImageData) {
              throw DecodingException('invalid PNG animation control');
            }
            declaredFrames = u32be(data);
            if (declaredFrames == 0) {
              throw DecodingException('PNG animation has no frames');
            }
          case 'fcTL':
            if (declaredFrames == null || length != 26) {
              throw DecodingException('invalid PNG frame control');
            }
            frameControls++;
          case 'IDAT':
            hasImageData = true;
          case 'IEND':
            if (length != 0) throw DecodingException('invalid PNG end chunk');
            ended = true;
          default:
            break;
        }
      }
      offset = data + length + 4;
      if (ended) break;
    }
    if (!ended || !hasImageData || width == null || height == null) {
      throw DecodingException('incomplete PNG container');
    }
    if (declaredFrames != null && frameControls != declaredFrames) {
      throw DecodingException('PNG frame count does not match animation data');
    }
    return header(ImageFormatEnum.Png, width, height, declaredFrames ?? 1);
  }

  PixerImageHeader jpeg() {
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset++] != 0xff) {
        throw DecodingException('invalid JPEG marker');
      }
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      requireBytes(offset, 1);
      final marker = bytes[offset++];
      if (marker == 0xd9 || marker == 0xda) {
        throw DecodingException('JPEG has no frame header');
      }
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      final length = u16be(offset);
      if (length < 2) throw DecodingException('invalid JPEG segment length');
      requireBytes(offset, length);
      if ((marker >= 0xc0 && marker <= 0xc3) ||
          (marker >= 0xc5 && marker <= 0xc7) ||
          (marker >= 0xc9 && marker <= 0xcb) ||
          (marker >= 0xcd && marker <= 0xcf)) {
        if (length < 8) throw DecodingException('invalid JPEG frame header');
        return header(
          ImageFormatEnum.Jpeg,
          u16be(offset + 5),
          u16be(offset + 3),
          1,
        );
      }
      offset += length;
    }
    throw DecodingException('incomplete JPEG header');
  }

  int skipGifSubBlocks(int offset) {
    while (true) {
      requireBytes(offset, 1);
      final length = bytes[offset++];
      if (length == 0) return offset;
      requireBytes(offset, length);
      offset += length;
    }
  }

  PixerImageHeader gif() {
    requireBytes(0, 13);
    final width = u16le(6);
    final height = u16le(8);
    final packed = bytes[10];
    var offset = 13;
    if ((packed & 0x80) != 0) {
      final tableLength = 3 * (1 << ((packed & 7) + 1));
      requireBytes(offset, tableLength);
      offset += tableLength;
    }
    var frames = 0;
    while (offset < bytes.length) {
      final marker = bytes[offset++];
      if (marker == 0x3b) {
        return header(ImageFormatEnum.Gif, width, height, frames);
      }
      if (marker == 0x21) {
        requireBytes(offset, 1); // Extension label.
        offset = skipGifSubBlocks(offset + 1);
        continue;
      }
      if (marker != 0x2c) throw DecodingException('invalid GIF block');
      requireBytes(offset, 9);
      final frameWidth = u16le(offset + 4);
      final frameHeight = u16le(offset + 6);
      if (frameWidth == 0 || frameHeight == 0) {
        throw InvalidDimensionsException('GIF frame has zero dimensions');
      }
      final localPacked = bytes[offset + 8];
      offset += 9;
      if ((localPacked & 0x80) != 0) {
        final tableLength = 3 * (1 << ((localPacked & 7) + 1));
        requireBytes(offset, tableLength);
        offset += tableLength;
      }
      requireBytes(offset, 1); // LZW code size.
      offset = skipGifSubBlocks(offset + 1);
      frames++;
    }
    throw DecodingException('incomplete GIF container');
  }

  PixerImageHeader webp() {
    requireBytes(0, 12);
    final end = u32le(4) + 8;
    if (end < 20 || end > bytes.length) {
      throw DecodingException('invalid WebP RIFF length');
    }
    var offset = 12;
    int? width;
    int? height;
    var hasExtendedHeader = false;
    var animated = false;
    var hasAnimationControl = false;
    var hasStillImage = false;
    var frames = 0;

    while (offset < end) {
      if (offset > end - 8) throw DecodingException('truncated WebP chunk');
      final type = fourCc(offset);
      final length = u32le(offset + 4);
      final data = offset + 8;
      final paddedLength = length + (length & 1);
      if (data > end - paddedLength) {
        throw DecodingException('truncated WebP chunk payload');
      }
      switch (type) {
        case 'VP8X':
          if (length != 10 || hasExtendedHeader || offset != 12) {
            throw DecodingException('invalid WebP extended header');
          }
          hasExtendedHeader = true;
          animated = (bytes[data] & 0x02) != 0;
          width = u24le(data + 4) + 1;
          height = u24le(data + 7) + 1;
        case 'VP8 ':
          if (length < 10 ||
              (bytes[data] & 1) != 0 ||
              !matches(const [0x9d, 0x01, 0x2a], data + 3)) {
            throw DecodingException('invalid WebP VP8 header');
          }
          width ??= u16le(data + 6) & 0x3fff;
          height ??= u16le(data + 8) & 0x3fff;
          hasStillImage = true;
        case 'VP8L':
          if (length < 5 || bytes[data] != 0x2f) {
            throw DecodingException('invalid WebP VP8L header');
          }
          width ??= 1 + bytes[data + 1] + ((bytes[data + 2] & 0x3f) << 8);
          height ??=
              1 +
              (bytes[data + 2] >> 6) +
              (bytes[data + 3] << 2) +
              ((bytes[data + 4] & 0x0f) << 10);
          hasStillImage = true;
        case 'ANIM':
          if (length < 6) throw DecodingException('invalid WebP animation');
          hasAnimationControl = true;
        case 'ANMF':
          if (length < 16) throw DecodingException('invalid WebP frame');
          frames++;
        default:
          break;
      }
      offset = data + paddedLength;
    }
    if (width == null || height == null) {
      throw DecodingException('WebP has no image header');
    }
    if (animated) {
      if (!hasExtendedHeader || !hasAnimationControl || frames == 0) {
        throw DecodingException('incomplete WebP animation');
      }
    } else if (!hasStillImage || frames != 0 || hasAnimationControl) {
      throw DecodingException('WebP has no still image');
    }
    return header(ImageFormatEnum.WebP, width, height, animated ? frames : 1);
  }
}
