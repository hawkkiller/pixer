import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:vm_service/vm_service_io.dart';

import '../lib/memory_cases.dart';

/// Measures how much memory pixer and the `image` package use per operation.
///
/// Run with `dart run bin/memory.dart [--runs N]`. Every measurement runs in
/// a fresh process so earlier cases can't hide or inflate a later one:
///
/// - Peak RSS growth: an AOT build of this file runs the operation once and
///   reports how far the process's peak resident memory rose above where it
///   stood just before. This counts everything the OS sees, including pixer's
///   native (Rust) buffers and threads. Median of `--runs` processes.
/// - Dart heap: a JIT run with the VM service reports the bytes the operation
///   allocated on the Dart heap, and how much of that its result still holds
///   after a GC. Pixer keeps pixels in native memory, outside the Dart heap.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && memoryLibraries.contains(args.first)) {
    if (args.contains('--heap')) return _serveHeap(args[0], args[1]);
    stdout.writeln(jsonEncode(_measureRss(args[0], args[1])));
    return;
  }

  if (const bool.fromEnvironment('dart.vm.product')) {
    stderr.writeln('Run the full benchmark with `dart run bin/memory.dart`.');
    exitCode = 64;
    return;
  }

  final runsIndex = args.indexOf('--runs');
  final runs = runsIndex == -1 ? 3 : int.parse(args[runsIndex + 1]);
  await _runAll(runs);
}

/// Keeps a result reachable until memory has been read.
Object? _sink;

const _mb = 1024 * 1024;

Map<String, Object?> _measureRss(String library, String operation) {
  final run = prepareMemoryCase(library, operation);
  final peakReset = _resetPeakRss();
  final before = _rss();
  _sink = run();
  final peak = _peakRss();
  return {
    'baseline_rss': before,
    'peak_rss': peak,
    'peak_rss_growth': peak - before,
    // Without a reset, a peak reached during preparation can hide the
    // operation's own peak, so growth is then a lower bound.
    'exact_peak': peakReset,
  };
}

/// Runs [library]'s [operation] for [_heapChild], which reads this process's
/// Dart heap through the VM service. Reading it from this process would put
/// the decoded allocation profiles on the heap being measured.
///
/// Reads one command per line from stdin: `run` runs the operation, `empty`
/// runs nothing (to measure the cost of the protocol itself), `exit` stops.
Future<void> _serveHeap(String library, String operation) async {
  final run = prepareMemoryCase(library, operation);
  // A first run compiles the code it reaches. In JIT that code lives on the
  // Dart heap, so only a later run is measured.
  run();
  final info = await Service.controlWebServer(enable: true, silenceOutput: true);
  final commands = StreamIterator(stdin.transform(utf8.decoder).transform(const LineSplitter()));
  stdout.writeln('service ${info.serverWebSocketUri} ${Service.getIsolateId(Isolate.current)}');
  while (await commands.moveNext() && commands.current != 'exit') {
    _sink = null;
    if (commands.current == 'run') _sink = run();
    stdout.writeln('done ${_sink.runtimeType}');
  }
  await commands.cancel();
}

/// Resets the kernel's peak RSS to the current RSS. Linux only.
bool _resetPeakRss() {
  if (!Platform.isLinux) return false;
  try {
    File('/proc/self/clear_refs').writeAsStringSync('5');
    return true;
  } on FileSystemException {
    return false;
  }
}

int _rss() => Platform.isLinux ? _procStatus('VmRSS') : ProcessInfo.currentRss;

int _peakRss() => Platform.isLinux ? _procStatus('VmHWM') : ProcessInfo.maxRss;

/// Reads a `kB` field of `/proc/self/status` in bytes.
int _procStatus(String field) {
  final line = File(
    '/proc/self/status',
  ).readAsLinesSync().firstWhere((line) => line.startsWith('$field:'));
  return int.parse(line.split(RegExp(r'\s+'))[1]) * 1024;
}

Future<void> _runAll(int runs) async {
  final dart = Platform.resolvedExecutable;
  stdout.writeln('Building AOT executable...');
  final build = await Process.run(dart, [
    'build',
    'cli',
    '--target',
    'bin/memory.dart',
    '--output',
    'build/memory',
  ]);
  if (build.exitCode != 0) {
    stderr
      ..write(build.stdout)
      ..write(build.stderr);
    exit(build.exitCode);
  }
  final executable = Platform.isWindows
      ? 'build/memory/bundle/bin/memory.exe'
      : 'build/memory/bundle/bin/memory';

  final results = <String, Map<String, Map<String, Object?>>>{};
  for (final operation in memoryOperations) {
    stdout.writeln('Measuring $operation...');
    for (final library in memoryLibraries) {
      final samples = [
        for (var i = 0; i < runs; i++) await _child(executable, [library, operation]),
      ]..sort((a, b) => (a['peak_rss_growth'] as int).compareTo(b['peak_rss_growth'] as int));
      final heap = await _heapChild(dart, library, operation);
      results.putIfAbsent(operation, () => {})[library] = {
        ...samples[samples.length ~/ 2],
        'peak_rss_growth_runs': [for (final sample in samples) sample['peak_rss_growth']],
        ...heap,
      };
    }
  }

  _printTable(results, runs);

  final file = File('memory_results.json');
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'timestamp': DateTime.now().toIso8601String(),
      'dart': Platform.version,
      'cpus': Platform.numberOfProcessors,
      'runs': runs,
      'results': results,
    }),
  );
  stdout.writeln('\nResults saved to: ${file.absolute.path}');
}

Future<Map<String, Object?>> _child(String executable, List<String> args) async {
  final result = await Process.run(executable, args);
  if (result.exitCode != 0) {
    stderr
      ..writeln('$executable ${args.join(' ')} failed:')
      ..write(result.stdout)
      ..write(result.stderr);
    exit(result.exitCode);
  }
  final lines = LineSplitter.split(result.stdout as String);
  return jsonDecode(lines.lastWhere((line) => line.startsWith('{'))) as Map<String, Object?>;
}

/// Measures the Dart heap of an operation run by [_serveHeap] in a JIT child.
Future<Map<String, Object?>> _heapChild(String dart, String library, String operation) async {
  final process = await Process.start(dart, [
    'run',
    'bin/memory.dart',
    library,
    operation,
    '--heap',
  ]);
  final stderrText = process.stderr.transform(utf8.decoder).join();
  final lines = StreamIterator(
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  Future<List<String>> expect(String prefix) async {
    while (await lines.moveNext()) {
      if (lines.current.startsWith(prefix)) return lines.current.split(' ');
    }
    stderr
      ..writeln('$library $operation --heap failed:')
      ..write(await stderrText);
    exit(1);
  }

  final [_, uri, isolateId] = await expect('service ');
  final service = await vmServiceConnectUri(uri);

  /// Returns the bytes [command] allocated on the Dart heap, the heap and
  /// external bytes its result holds after a GC, and the result type.
  Future<List<Object>> measure(String command) async {
    final before = await service.getAllocationProfile(isolateId, gc: true, reset: true);
    process.stdin.writeln(command);
    final [_, result] = await expect('done ');
    final allocated = await service.getAllocationProfile(isolateId);
    final after = await service.getAllocationProfile(isolateId, gc: true);
    return [
      allocated.members!.fold<int>(0, (sum, stats) => sum + (stats.accumulatedSize ?? 0)),
      after.memoryUsage!.heapUsage! - before.memoryUsage!.heapUsage!,
      after.memoryUsage!.externalUsage! - before.memoryUsage!.externalUsage!,
      result,
    ];
  }

  try {
    // The VM allocates on the measured heap while serving the profiles (about
    // 12 MB, stable to a few KB), so an empty command's cost is subtracted.
    final empty = await measure('empty');
    final measured = await measure('run');
    int delta(int i) => (measured[i] as int) - (empty[i] as int);
    return {
      'dart_heap_allocated': delta(0),
      'dart_heap_retained': delta(1),
      'dart_external_retained': delta(2),
      'result': measured[3],
    };
  } finally {
    await service.dispose();
    process.stdin.writeln('exit');
    await lines.cancel();
    await process.exitCode;
  }
}

void _printTable(Map<String, Map<String, Map<String, Object?>>> results, int runs) {
  String mb(Object? bytes) => ((bytes as int) / _mb).toStringAsFixed(1);

  final first = results.values.first;
  stdout
    ..writeln(
      '\nProcess RSS before the operation: '
      'pixer ${mb(first['pixer']!['baseline_rss'])} MB, '
      'image ${mb(first['image']!['baseline_rss'])} MB',
    )
    ..writeln('Peak RSS growth is the median of $runs processes; Dart heap is bytes allocated.\n')
    ..writeln(
      '${'operation'.padRight(18)}'
      '${'pixer RSS'.padLeft(11)}${'image RSS'.padLeft(11)}${'ratio'.padLeft(8)}'
      '${'pixer heap'.padLeft(12)}${'image heap'.padLeft(12)}  (MB)',
    );
  for (final MapEntry(key: operation, value: libraries) in results.entries) {
    final pixer = libraries['pixer']!;
    final image = libraries['image']!;
    final pixerRss = pixer['peak_rss_growth'] as int;
    final imageRss = image['peak_rss_growth'] as int;
    final exact = pixer['exact_peak'] == true && image['exact_peak'] == true;
    stdout.writeln(
      '${operation.padRight(18)}'
      '${mb(pixerRss).padLeft(11)}${mb(imageRss).padLeft(11)}'
      '${'${(imageRss / pixerRss).toStringAsFixed(1)}x'.padLeft(8)}'
      '${mb(max(0, pixer['dart_heap_allocated'] as int)).padLeft(12)}'
      '${mb(max(0, image['dart_heap_allocated'] as int)).padLeft(12)}'
      '${exact ? '' : '  (lower bound)'}',
    );
  }
}
