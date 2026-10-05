import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:image/image.dart';

import 'single_run.dart';

final _bytes = File('assets/example_img.jpg').readAsBytesSync();

/// Base for benchmarks that operate on an already decoded image.
abstract class _DartImageBenchmark extends BenchmarkBase with SingleRun {
  _DartImageBenchmark(super.name);

  late Image image;

  @override
  void setup() => image = decodeImage(_bytes)!;
}

class DartImageResizeBenchmark extends _DartImageBenchmark {
  DartImageResizeBenchmark(this.targetWidth, this.targetHeight)
    : super('dart_image.resize_${targetWidth}x$targetHeight');

  final int targetWidth;
  final int targetHeight;

  @override
  void run() => copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: Interpolation.cubic,
  );
}

class DartImageLoadBenchmark extends BenchmarkBase with SingleRun {
  DartImageLoadBenchmark() : super('dart_image.load');

  @override
  void run() => decodeImage(_bytes);
}

class DartImageEncodeBenchmark extends _DartImageBenchmark {
  DartImageEncodeBenchmark() : super('dart_image.encode_jpeg');

  @override
  void run() => encodeJpg(image, quality: 85);
}

class DartImageRotateBenchmark extends _DartImageBenchmark {
  DartImageRotateBenchmark() : super('dart_image.rotate_90');

  @override
  void run() => copyRotate(image, angle: 90);
}

class DartImageFlipBenchmark extends _DartImageBenchmark {
  DartImageFlipBenchmark() : super('dart_image.flip_horizontal');

  @override
  void run() => flipHorizontal(image);
}

/// Decode, upscale to 4K, and encode, as in the showcase app.
class DartImagePipelineBenchmark extends BenchmarkBase with SingleRun {
  DartImagePipelineBenchmark() : super('dart_image.pipeline_4k');

  @override
  void run() {
    final resized = copyResize(
      decodeImage(_bytes)!,
      width: 3840,
      height: 2160,
      interpolation: Interpolation.cubic,
    );
    encodeJpg(resized, quality: 85);
  }
}
