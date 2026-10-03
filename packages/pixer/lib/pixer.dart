/// Fast image processing for Dart, backed by Rust.
///
/// Start with [Pixer] to load an image. Operations build a lazy
/// [PixerPipeline] that runs in one native call when you encode, save, or
/// materialize the result. Errors throw subclasses of [PixerException].
///
/// ```dart
/// final image = Pixer.fromFile('input.jpg');
/// final bytes = image
///     .resize(800, 600)
///     .grayscale()
///     .encode(PixerJpegEncoder(quality: 85));
/// image.dispose();
/// ```
library;

export 'src/pixer_base.dart';
export 'src/pixer_exception.dart' hide checkBatchError, checkImageError;
export 'src/enums.dart' show FilterTypeEnum, ImageErrorCode, ImageFormatEnum;
export 'src/image_metadata.dart';
export 'src/pixer_encoder.dart';
