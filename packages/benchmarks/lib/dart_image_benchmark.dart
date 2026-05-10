import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:image/image.dart';

/// Benchmark for resizing images using the dart image package
class DartImageResizeBenchmark extends BenchmarkBase {
  DartImageResizeBenchmark(this.targetWidth, this.targetHeight)
    : super('dart_image.resize_${targetWidth}x$targetHeight');

  final int targetWidth;
  final int targetHeight;
  late Image image;

  @override
  void setup() {
    super.setup();
    image = decodeImage(File('assets/example_img.jpg').readAsBytesSync())!;
  }

  @override
  void run() {
    copyResize(image, width: targetWidth, height: targetHeight, interpolation: Interpolation.cubic);
  }
}

/// Benchmark for loading images using the dart image package
class DartImageLoadBenchmark extends BenchmarkBase {
  DartImageLoadBenchmark() : super('dart_image.load');

  late Uint8List imageBytes;

  @override
  void setup() {
    super.setup();
    imageBytes = Uint8List.fromList(File('assets/example_img.jpg').readAsBytesSync());
  }

  @override
  void run() {
    decodeImage(imageBytes);
  }
}

/// Benchmark for encoding images using the dart image package
class DartImageEncodeBenchmark extends BenchmarkBase {
  DartImageEncodeBenchmark() : super('dart_image.encode_jpeg');

  late Image image;

  @override
  void setup() {
    super.setup();
    image = decodeImage(File('assets/example_img.jpg').readAsBytesSync())!;
  }

  @override
  void run() {
    encodeJpg(image);
  }
}

/// Benchmark for rotating images using the dart image package
class DartImageRotateBenchmark extends BenchmarkBase {
  DartImageRotateBenchmark() : super('dart_image.rotate_90');

  late Image image;

  @override
  void setup() {
    super.setup();
    image = decodeImage(File('assets/example_img.jpg').readAsBytesSync())!;
  }

  @override
  void run() {
    copyRotate(image, angle: 90);
  }
}

/// Benchmark for flipping images using the dart image package
class DartImageFlipBenchmark extends BenchmarkBase {
  DartImageFlipBenchmark() : super('dart_image.flip_horizontal');

  late Image image;

  @override
  void setup() {
    super.setup();
    image = decodeImage(File('assets/example_img.jpg').readAsBytesSync())!;
  }

  @override
  void run() {
    flipHorizontal(image);
  }
}
