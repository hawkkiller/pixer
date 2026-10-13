@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pixer/pixer.dart';
import 'package:pixer/src/cli.dart';
import 'package:test/test.dart';

final class _Collector implements StreamConsumer<List<int>> {
  final bytes = BytesBuilder();

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(bytes.add);

  @override
  Future<void> close() async {}
}

typedef _Result = ({int code, Uint8List out, String err});

Future<_Result> _run(List<String> args, {List<int>? input}) async {
  final out = _Collector();
  final err = _Collector();
  final outSink = IOSink(out);
  final errSink = IOSink(err);
  final code = await runCli(
    args,
    out: outSink,
    err: errSink,
    input: Stream.value(input ?? const []),
  );
  await outSink.close();
  await errSink.close();
  return (
    code: code,
    out: out.bytes.takeBytes(),
    err: utf8.decode(err.bytes.takeBytes()),
  );
}

void main() {
  late Directory directory;
  late String input;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pixer_cli_test_');
    input = '${directory.path}/input.png';
    await File(input).writeAsBytes(
      img.encodePng(img.Image(width: 40, height: 20, numChannels: 4)),
    );
  });

  tearDown(() => directory.delete(recursive: true));

  (int, int) sizeOf(String path) {
    final image = Pixer.fromFile(path);
    try {
      return (image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  test('info prints size and color type', () async {
    final result = await _run(['info', input]);
    expect(result.code, 0);
    expect(utf8.decode(result.out), '40x20 rgba\n');
  });

  test('info prefixes paths and reports failures per image', () async {
    final missing = '${directory.path}/missing.png';
    final result = await _run(['info', input, missing]);
    expect(result.code, 1);
    expect(utf8.decode(result.out), '$input: 40x20 rgba\n');
    expect(result.err, startsWith('pixer: $missing: '));
  });

  test('convert applies operations in order', () async {
    final output = '${directory.path}/out.jpg';
    final result = await _run([
      'convert',
      input,
      output,
      '--crop',
      '0,0,10x20',
      '--rotate=90',
      '--resize',
      '10',
      '--grayscale',
      '--quality',
      '90',
    ]);
    expect(result.code, 0, reason: result.err);
    expect(sizeOf(output), (10, 5));
  });

  test('convert without operations re-encodes', () async {
    final output = '${directory.path}/out.webp';
    final result = await _run(['convert', input, output]);
    expect(result.code, 0, reason: result.err);
    expect(sizeOf(output), (40, 20));
  });

  test('convert reads stdin and writes stdout', () async {
    final result = await _run([
      'convert',
      '-',
      '-',
      '--format',
      'png',
      '--resize-exact',
      '7x3',
    ], input: await File(input).readAsBytes());
    expect(result.code, 0, reason: result.err);
    final image = Pixer.fromMemory(result.out, format: ImageFormatEnum.Png);
    expect((image.width, image.height), (7, 3));
    image.dispose();
  });

  test('reports usage errors with exit code 64', () async {
    for (final args in [
      <String>[],
      ['bogus'],
      ['info'],
      ['convert', input],
      ['convert', input, '-'],
      ['convert', input, 'out.unknown'],
      ['convert', input, 'out.png', '--quality', '80'],
      ['convert', input, 'out.png', '--resize', 'big'],
      ['convert', input, 'out.png', '--rotate', '45'],
      ['convert', input, 'out.png', '--blur'],
      ['convert', input, 'out.png', '--sharpen'],
    ]) {
      final result = await _run(args);
      expect(result.code, usageExitCode, reason: '$args');
    }
  });

  test('reports image errors with exit code 1', () async {
    final result = await _run([
      'convert',
      input,
      '${directory.path}/out.png',
      '--crop',
      '30,0,20x20',
    ]);
    expect(result.code, 1);
    expect(result.err, startsWith('pixer: Invalid dimensions'));
  });

  test('prints the version', () async {
    final result = await _run(['--version']);
    expect(result.code, 0);
    expect(utf8.decode(result.out), 'pixer $cliVersion\n');
  });
}
