/// Fast image processing for Dart, backed by Rust.
///
/// Start with [Pixer] to load an image, chain operations, and either
/// [Pixer.saveToFile] or [Pixer.encode] the result. Errors throw subclasses
/// of [PixerException].
///
/// ```dart
/// final image = Pixer.fromFile('input.jpg');
/// final thumb = image.resize(800, 600);
/// final bytes = thumb.encode(PixerJpegEncoder(quality: 85));
/// thumb.dispose();
/// image.dispose();
/// ```
library;

export 'src/pixer_base.dart';
export 'src/pixer_exception.dart';
export 'src/filter_type.dart';
export 'src/image_format.dart';
export 'src/image_metadata.dart';
export 'src/pixer_encoder.dart';
