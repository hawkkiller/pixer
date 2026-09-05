/// Fast image processing for Dart, backed by Rust.
///
/// Start with [Pixer] to load an image, apply operations, and either save or
/// encode the result. Use [Pixer.batch] to execute multiple operations in one
/// native call. Errors throw subclasses of [PixerException].
///
/// ```dart
/// final image = Pixer.fromFile('input.jpg');
/// final bytes = image
///     .batch()
///     .resize(800, 600)
///     .grayscale()
///     .encode(PixerJpegEncoder(quality: 85));
/// image.dispose();
/// ```
library;

export 'src/pixer_base.dart';
export 'src/pixer_exception.dart';
export 'src/filter_type.dart';
export 'src/image_format.dart';
export 'src/image_metadata.dart';
export 'src/pixer_encoder.dart';
