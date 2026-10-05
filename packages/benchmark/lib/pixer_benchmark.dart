import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pixer/pixer.dart';

import 'single_run.dart';

final _bytes = File('assets/example_img.jpg').readAsBytesSync();

/// Base for benchmarks that operate on an already decoded image.
abstract class _PixerImageBenchmark extends BenchmarkBase with SingleRun {
  _PixerImageBenchmark(super.name);

  late Pixer image;

  @override
  void setup() => image = Pixer.fromMemory(_bytes);

  @override
  void teardown() => image.dispose();
}

/// Resizes to exact dimensions with a cubic filter, matching `image`'s `Interpolation.cubic`.
class PixerResizeBenchmark extends _PixerImageBenchmark {
  PixerResizeBenchmark(this.targetWidth, this.targetHeight)
    : super('pixer.resize_${targetWidth}x$targetHeight');

  final int targetWidth;
  final int targetHeight;

  @override
  void run() => image
      .resizeExact(targetWidth, targetHeight, filter: FilterTypeEnum.CatmullRom)
      .toImage()
      .dispose();
}

class PixerLoadBenchmark extends BenchmarkBase with SingleRun {
  PixerLoadBenchmark() : super('pixer.load');

  @override
  void run() => Pixer.fromMemory(_bytes).dispose();
}

class PixerEncodeBenchmark extends _PixerImageBenchmark {
  PixerEncodeBenchmark() : super('pixer.encode_jpeg');

  @override
  void run() => image.encode(PixerJpegEncoder(quality: 85));
}

class PixerRotateBenchmark extends _PixerImageBenchmark {
  PixerRotateBenchmark() : super('pixer.rotate_90');

  @override
  void run() => image.rotate90().toImage().dispose();
}

class PixerFlipBenchmark extends _PixerImageBenchmark {
  PixerFlipBenchmark() : super('pixer.flip_horizontal');

  @override
  void run() => image.flipHorizontal().toImage().dispose();
}

/// Decode, upscale to 4K, and encode, as in the showcase app.
class PixerPipelineBenchmark extends BenchmarkBase with SingleRun {
  PixerPipelineBenchmark() : super('pixer.pipeline_4k');

  @override
  void run() {
    final image = Pixer.fromMemory(_bytes);
    try {
      image
          .resizeExact(3840, 2160, filter: FilterTypeEnum.CatmullRom)
          .encode(PixerJpegEncoder(quality: 85));
    } finally {
      image.dispose();
    }
  }
}
