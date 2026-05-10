import 'dart:convert';
import 'dart:io';

import 'package:benchmarks/dart_image_benchmark.dart';
import 'package:benchmarks/pixer_benchmark.dart';

void main() {
  print('\n=== Image Processing Benchmarks ===\n');
  print('Format: {benchmark_name}(RunTime): {time} us.\n');

  final results = <String, Map<String, dynamic>>{};

  // Resize benchmarks - various sizes
  print('--- Resize Benchmarks ---');
  final resizeSizes = [
    (800, 600),
    (1920, 1080),
    (3840, 2160), // 4K
  ];

  for (final (width, height) in resizeSizes) {
    final operation = 'resize_${width}x$height';
    results[operation] = {};

    final pixerTime = PixerResizeBenchmark(width, height).measure();
    print('pixer.$operation(RunTime): $pixerTime us.');
    results[operation]!['pixer_us'] = pixerTime;

    final dartImageTime = DartImageResizeBenchmark(width, height).measure();
    print('dart_image.$operation(RunTime): $dartImageTime us.');
    results[operation]!['dart_image_us'] = dartImageTime;
    print('');
  }

  // Load benchmarks
  print('--- Load Benchmarks ---');
  results['load'] = {};

  final pixerLoadTime = PixerLoadBenchmark().measure();
  print('pixer.load(RunTime): $pixerLoadTime us.');
  results['load']!['pixer_us'] = pixerLoadTime;

  final dartImageLoadTime = DartImageLoadBenchmark().measure();
  print('dart_image.load(RunTime): $dartImageLoadTime us.');
  results['load']!['dart_image_us'] = dartImageLoadTime;
  print('');

  // Encode benchmarks
  print('--- Encode Benchmarks ---');
  results['encode_jpeg'] = {};

  final pixerEncodeTime = PixerEncodeBenchmark().measure();
  print('pixer.encode_jpeg(RunTime): $pixerEncodeTime us.');
  results['encode_jpeg']!['pixer_us'] = pixerEncodeTime;

  final dartImageEncodeTime = DartImageEncodeBenchmark().measure();
  print('dart_image.encode_jpeg(RunTime): $dartImageEncodeTime us.');
  results['encode_jpeg']!['dart_image_us'] = dartImageEncodeTime;
  print('');

  // Rotate benchmarks
  print('--- Rotate Benchmarks ---');
  results['rotate_90'] = {};

  final pixerRotateTime = PixerRotateBenchmark().measure();
  print('pixer.rotate_90(RunTime): $pixerRotateTime us.');
  results['rotate_90']!['pixer_us'] = pixerRotateTime;

  final dartImageRotateTime = DartImageRotateBenchmark().measure();
  print('dart_image.rotate_90(RunTime): $dartImageRotateTime us.');
  results['rotate_90']!['dart_image_us'] = dartImageRotateTime;
  print('');

  // Flip benchmarks
  print('--- Flip Benchmarks ---');
  results['flip_horizontal'] = {};

  final pixerFlipTime = PixerFlipBenchmark().measure();
  print('pixer.flip_horizontal(RunTime): $pixerFlipTime us.');
  results['flip_horizontal']!['pixer_us'] = pixerFlipTime;

  final dartImageFlipTime = DartImageFlipBenchmark().measure();
  print('dart_image.flip_horizontal(RunTime): $dartImageFlipTime us.');
  results['flip_horizontal']!['dart_image_us'] = dartImageFlipTime;
  print('');

  // Save results to JSON file
  final jsonOutput = {'timestamp': DateTime.now().toIso8601String(), 'results': results};

  final file = File('benchmark_results.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOutput));

  print('\n=== Benchmarks Complete ===');
  print('Results saved to: ${file.absolute.path}\n');
}
