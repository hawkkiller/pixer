import 'dart:convert';
import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

import '../lib/dart_image_benchmark.dart';
import '../lib/pixer_benchmark.dart';

void main() {
  final cases = <String, (BenchmarkBase, BenchmarkBase)>{
    'resize_800x600': (PixerResizeBenchmark(800, 600), DartImageResizeBenchmark(800, 600)),
    'resize_1280x720': (PixerResizeBenchmark(1280, 720), DartImageResizeBenchmark(1280, 720)),
    'resize_3840x2160': (PixerResizeBenchmark(3840, 2160), DartImageResizeBenchmark(3840, 2160)),
    'load': (PixerLoadBenchmark(), DartImageLoadBenchmark()),
    'encode_jpeg': (PixerEncodeBenchmark(), DartImageEncodeBenchmark()),
    'rotate_90': (PixerRotateBenchmark(), DartImageRotateBenchmark()),
    'flip_horizontal': (PixerFlipBenchmark(), DartImageFlipBenchmark()),
    'pipeline_4k': (PixerPipelineBenchmark(), DartImagePipelineBenchmark()),
  };

  print('Microseconds per operation\n');
  print('${'operation'.padRight(18)}${'pixer'.padLeft(12)}${'image'.padLeft(14)}  speedup');
  final results = <String, Map<String, double>>{};
  for (final MapEntry(key: operation, value: (pixer, image)) in cases.entries) {
    final pixerUs = pixer.measure();
    final imageUs = image.measure();
    results[operation] = {'pixer_us': pixerUs, 'dart_image_us': imageUs};
    print(
      '${operation.padRight(18)}'
      '${pixerUs.toStringAsFixed(0).padLeft(12)}'
      '${imageUs.toStringAsFixed(0).padLeft(14)}'
      '  ${(imageUs / pixerUs).toStringAsFixed(1)}x',
    );
  }

  final file = File('benchmark_results.json');
  file.writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'timestamp': DateTime.now().toIso8601String(), 'results': results}),
  );
  print('\nResults saved to: ${file.absolute.path}');
}
