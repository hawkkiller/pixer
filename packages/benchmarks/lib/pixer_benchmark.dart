import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pixer/pixer.dart';

/// Benchmark for resizing images using the pixer package
class PixerResizeBenchmark extends BenchmarkBase {
  PixerResizeBenchmark(this.targetWidth, this.targetHeight)
    : super('pixer.resize_${targetWidth}x$targetHeight');

  final int targetWidth;
  final int targetHeight;
  late Pixer image;

  @override
  void setup() {
    super.setup();
    image = Pixer.fromFile('assets/example_img.jpg');
  }

  @override
  void teardown() {
    super.teardown();
    image.dispose();
  }

  @override
  void run() {
    final resized = image.resize(targetWidth, targetHeight);
    resized.dispose();
  }
}

/// Benchmark for loading images using the pixer package
class PixerLoadBenchmark extends BenchmarkBase {
  PixerLoadBenchmark() : super('pixer.load');

  @override
  void run() {
    final image = Pixer.fromFile('assets/example_img.jpg');
    image.dispose();
  }
}

/// Benchmark for encoding images using the pixer package
class PixerEncodeBenchmark extends BenchmarkBase {
  PixerEncodeBenchmark() : super('pixer.encode_jpeg');

  late Pixer image;

  @override
  void setup() {
    super.setup();
    image = Pixer.fromFile('assets/example_img.jpg');
  }

  @override
  void teardown() {
    super.teardown();
    image.dispose();
  }

  @override
  void run() {
    image.encode(PixerJpegEncoder(quality: 100));
  }
}

/// Benchmark for rotating images using the pixer package
class PixerRotateBenchmark extends BenchmarkBase {
  PixerRotateBenchmark() : super('pixer.rotate_90');

  late Pixer image;

  @override
  void setup() {
    super.setup();
    image = Pixer.fromFile('assets/example_img.jpg');
  }

  @override
  void teardown() {
    super.teardown();
    image.dispose();
  }

  @override
  void run() {
    final rotated = image.rotate90();
    rotated.dispose();
  }
}

/// Benchmark for flipping images using the pixer package
class PixerFlipBenchmark extends BenchmarkBase {
  PixerFlipBenchmark() : super('pixer.flip_horizontal');

  late Pixer image;

  @override
  void setup() {
    super.setup();
    image = Pixer.fromFile('assets/example_img.jpg');
  }

  @override
  void teardown() {
    super.teardown();
    image.dispose();
  }

  @override
  void run() {
    final flipped = image.flipHorizontal();
    flipped.dispose();
  }
}
