import 'dart:io';
import 'dart:typed_data';

import '../pixer.dart';
import 'hook/version.dart' as assets;

/// Exit code for invalid command-line usage (`EX_USAGE`).
const usageExitCode = 64;

/// Package version, derived from the native asset release tag.
final String cliVersion = assets.version.replaceFirst('pixer-assets-v', '');

const _usage = '''
Fast image processing from the command line.

Usage: pixer <command> [arguments]

Commands:
  info <image>...              Print the size and color type of images.
  convert <input> <output>     Transform an image and save it.

Run "pixer help <command>" for more information about a command.

Global options:
  -h, --help       Print this usage information.
      --version    Print the pixer version.''';

const _infoUsage = '''
Print the size and color type of images.

Usage: pixer info <image>...

Use "-" to read an image from stdin.''';

const _convertUsage = '''
Transform an image and save it. Operations run in the order given.

Usage: pixer convert <input> <output> [options]

Use "-" as input to read from stdin, or as output to write to stdout (requires
--format). The output format comes from the output file extension unless
--format is set.

Operations:
  --resize <W>x<H>          Fit within W x H, preserving aspect ratio.
                            A single number fits within a square.
  --resize-exact <W>x<H>    Resize to exactly W x H.
  --crop <X>,<Y>,<W>x<H>    Crop a W x H rectangle at X, Y.
  --rotate <90|180|270>     Rotate clockwise.
  --flip <h|v>              Flip horizontally or vertically.
  --blur <sigma>            Apply a Gaussian blur.
  --brightness <value>      Add value to color channels (negative darkens).
  --contrast <value>        Adjust contrast (negative reduces).
  --grayscale               Convert to grayscale.
  --invert                  Invert colors.

Output options:
  --format <format>         png, jpeg, gif, webp, bmp, ico, or tiff.
  --quality <1-100>         JPEG quality (default 75).
  --filter <filter>         Resize filter: nearest, triangle, catmull-rom,
                            gaussian, or lanczos3 (default).''';

/// One operation, applied to the loaded [Pixer] for the first step and to the
/// resulting [PixerPipeline] after that; both expose the same methods.
typedef _Step = PixerPipeline Function(dynamic source);

/// Thrown for invalid command-line usage of [command] (or of `pixer` itself).
final class UsageException implements Exception {
  UsageException(this.message, [this.command]);

  final String message;
  final String? command;

  @override
  String toString() =>
      '$message\nRun "pixer help${command == null ? '' : ' $command'}" for usage.';
}

/// Runs the `pixer` command with [args] and returns the exit code.
///
/// Command output goes to [out] and errors to [err], which default to
/// [stdout] and [stderr]; the `-` path reads from [input] (default [stdin]).
Future<int> runCli(
  List<String> args, {
  IOSink? out,
  IOSink? err,
  Stream<List<int>>? input,
}) async {
  final cli = _Cli(out ?? stdout, err ?? stderr, input ?? stdin);
  final errors = cli._err;
  try {
    return await cli._run(args);
  } on UsageException catch (e) {
    errors.writeln(e);
    return usageExitCode;
  } on PixerException catch (e) {
    errors.writeln('pixer: ${e.message}');
    return 1;
  } on FileSystemException catch (e) {
    final path = e.path == null ? '' : ': ${e.path}';
    errors.writeln('pixer: ${e.message}$path');
    return 1;
  } on ArgumentError catch (e) {
    errors.writeln('pixer: ${e.message}');
    return 1;
  } on StateError catch (e) {
    // `dart pub global activate` does not run build hooks, so the native
    // library is missing; `dart install` bundles it with the executable.
    if (!e.message.contains('No available native assets')) rethrow;
    errors.writeln(
      'pixer: the native library is missing. '
      'Install the CLI with "dart install pixer" instead of '
      '"dart pub global activate".',
    );
    return 1;
  }
}

final class _Cli {
  _Cli(this._out, this._err, this._in);

  final IOSink _out;
  final IOSink _err;
  final Stream<List<int>> _in;

  Future<int> _run(List<String> args) async {
    if (args.isEmpty) {
      _out.writeln(_usage);
      return usageExitCode;
    }
    final [command, ...rest] = args;
    switch (command) {
      case '-h' || '--help':
        _out.writeln(_usage);
        return 0;
      case '--version':
        _out.writeln('pixer $cliVersion');
        return 0;
      case 'help':
        _out.writeln(switch (rest) {
          ['info', ...] => _infoUsage,
          ['convert', ...] => _convertUsage,
          _ => _usage,
        });
        return 0;
      case 'info':
        return _info(rest);
      case 'convert':
        return _convert(rest);
      default:
        throw UsageException('Unknown command "$command".');
    }
  }

  Future<int> _info(List<String> args) async {
    if (args.contains('-h') || args.contains('--help')) {
      _out.writeln(_infoUsage);
      return 0;
    }
    if (args.isEmpty) throw UsageException('No images given.', 'info');
    for (final arg in args) {
      if (arg.startsWith('-') && arg != '-') {
        throw UsageException('Unknown option "$arg".', 'info');
      }
    }

    var exitCode = 0;
    for (final path in args) {
      try {
        final image = await _load(path);
        try {
          final metadata = image.getMetadata();
          final name = args.length > 1 ? '$path: ' : '';
          _out.writeln(
            '$name${metadata.width}x${metadata.height} ${metadata.colorType.name}',
          );
        } finally {
          image.dispose();
        }
      } on PixerException catch (e) {
        _err.writeln('pixer: $path: ${e.message}');
        exitCode = 1;
      } on FileSystemException catch (e) {
        _err.writeln('pixer: $path: ${e.message}');
        exitCode = 1;
      }
    }
    return exitCode;
  }

  Future<int> _convert(List<String> args) async {
    if (args.contains('-h') || args.contains('--help')) {
      _out.writeln(_convertUsage);
      return 0;
    }

    final positional = <String>[];
    final steps = <_Step>[];
    ImageFormatEnum? format;
    int? quality;
    var filter = FilterTypeEnum.Lanczos3;

    Never fail(String message) => throw UsageException(message, 'convert');

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '-' || !arg.startsWith('-')) {
        positional.add(arg);
        continue;
      }
      final equals = arg.indexOf('=');
      final name = equals == -1 ? arg : arg.substring(0, equals);
      String value() {
        if (equals != -1) return arg.substring(equals + 1);
        if (i + 1 >= args.length) fail('Missing value for "$name".');
        return args[++i];
      }

      switch (name) {
        case '--resize':
          final (w, h) = _parseSize(value(), name, fail, allowSquare: true);
          steps.add((p) => p.resize(w, h, filter: filter));
        case '--resize-exact':
          final (w, h) = _parseSize(value(), name, fail);
          steps.add((p) => p.resizeExact(w, h, filter: filter));
        case '--crop':
          final (x, y, w, h) = _parseCrop(value(), fail);
          steps.add((p) => p.crop(x, y, w, h));
        case '--rotate':
          steps.add(switch (value()) {
            '90' => (p) => p.rotate90(),
            '180' => (p) => p.rotate180(),
            '270' || '-90' => (p) => p.rotate270(),
            final v => fail('Invalid rotation "$v"; use 90, 180, or 270.'),
          });
        case '--flip':
          steps.add(switch (value()) {
            'h' || 'horizontal' => (p) => p.flipHorizontal(),
            'v' || 'vertical' => (p) => p.flipVertical(),
            final v => fail('Invalid flip "$v"; use h or v.'),
          });
        case '--blur':
          final sigma = _parseNum(value(), name, fail, double.tryParse);
          steps.add((p) => p.blur(sigma));
        case '--brightness':
          final amount = _parseNum(value(), name, fail, int.tryParse);
          steps.add((p) => p.brightness(amount));
        case '--contrast':
          final amount = _parseNum(value(), name, fail, double.tryParse);
          steps.add((p) => p.contrast(amount));
        case '--grayscale':
          if (equals != -1) fail('"$name" does not take a value.');
          steps.add((p) => p.grayscale());
        case '--invert':
          if (equals != -1) fail('"$name" does not take a value.');
          steps.add((p) => p.invert());
        case '--format':
          final v = value();
          format = _formatFromName(v) ?? fail('Unknown format "$v".');
        case '--quality':
          quality = _parseNum(value(), name, fail, int.tryParse);
          if (quality < 1 || quality > 100) {
            fail('"--quality" must be between 1 and 100.');
          }
        case '--filter':
          final v = value();
          filter = _filters[v.toLowerCase()] ?? fail('Unknown filter "$v".');
        default:
          fail('Unknown option "$arg".');
      }
    }

    if (positional.length != 2) {
      fail(
        positional.length < 2
            ? 'Expected an input and an output path.'
            : 'Too many arguments: ${positional.skip(2).join(' ')}',
      );
    }
    final [input, output] = positional;
    final toStdout = output == '-';
    format ??= toStdout
        ? fail('Writing to stdout requires --format.')
        : _formatFromPath(output) ??
              fail('Cannot infer the format of "$output"; pass --format.');
    if (quality != null && format != ImageFormatEnum.Jpeg) {
      fail('"--quality" only applies to JPEG output.');
    }
    final encoder = quality != null
        ? PixerJpegEncoder(quality: quality)
        : PixerEncoder.fromFormat(format);

    final image = await _load(input);
    final Uint8List bytes;
    try {
      bytes = switch (steps) {
        [] => image.encode(encoder),
        [final first, ...final rest] =>
          rest
              .fold(first(image), (pipeline, step) => step(pipeline))
              .encode(encoder),
      };
    } finally {
      image.dispose();
    }

    if (toStdout) {
      _out.add(bytes);
      await _out.flush();
    } else {
      await File(output).writeAsBytes(bytes);
    }
    return 0;
  }

  Future<Pixer> _load(String path) async {
    if (path == '-') {
      final builder = BytesBuilder(copy: false);
      await _in.forEach(builder.add);
      return Pixer.fromMemory(builder.takeBytes());
    }
    return Pixer.fromFile(path);
  }
}

(int, int) _parseSize(
  String value,
  String option,
  Never Function(String) fail, {
  bool allowSquare = false,
}) {
  final match = RegExp(r'^(\d+)(?:x(\d+))?$').firstMatch(value);
  if (match == null || (match[2] == null && !allowSquare)) {
    fail('Invalid size "$value" for "$option"; expected WIDTHxHEIGHT.');
  }
  final width = int.parse(match[1]!);
  return (width, match[2] == null ? width : int.parse(match[2]!));
}

(int, int, int, int) _parseCrop(String value, Never Function(String) fail) {
  final match = RegExp(r'^(\d+),(\d+),(\d+)x(\d+)$').firstMatch(value);
  if (match == null) {
    fail('Invalid crop "$value"; expected X,Y,WIDTHxHEIGHT.');
  }
  final [x, y, w, h] = [for (var g = 1; g <= 4; g++) int.parse(match[g]!)];
  return (x, y, w, h);
}

T _parseNum<T extends num>(
  String value,
  String option,
  Never Function(String) fail,
  T? Function(String) parse,
) => parse(value) ?? fail('Invalid number "$value" for "$option".');

const _filters = {
  'nearest': FilterTypeEnum.Nearest,
  'triangle': FilterTypeEnum.Triangle,
  'catmull-rom': FilterTypeEnum.CatmullRom,
  'catmullrom': FilterTypeEnum.CatmullRom,
  'gaussian': FilterTypeEnum.Gaussian,
  'lanczos3': FilterTypeEnum.Lanczos3,
};

ImageFormatEnum? _formatFromName(String name) => switch (name.toLowerCase()) {
  'png' => ImageFormatEnum.Png,
  'jpg' || 'jpeg' => ImageFormatEnum.Jpeg,
  'gif' => ImageFormatEnum.Gif,
  'webp' => ImageFormatEnum.WebP,
  'bmp' => ImageFormatEnum.Bmp,
  'ico' => ImageFormatEnum.Ico,
  'tif' || 'tiff' => ImageFormatEnum.Tiff,
  _ => null,
};

ImageFormatEnum? _formatFromPath(String path) {
  final dot = path.lastIndexOf('.');
  return dot == -1 ? null : _formatFromName(path.substring(dot + 1));
}
