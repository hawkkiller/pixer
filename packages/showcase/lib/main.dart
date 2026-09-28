import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:pixer/pixer.dart';

void main() => runApp(const PixerShowcase());

const _targetWidth = 3840;
const _targetHeight = 2160;

final _showcaseColors =
    ColorScheme.fromSeed(
      seedColor: const Color(0xffb44732),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xffb44732),
      onPrimary: const Color(0xffffffff),
      surface: const Color(0xffffffff),
      onSurface: const Color(0xff191a18),
      surfaceContainerLowest: const Color(0xffffffff),
      surfaceContainerLow: const Color(0xfffafaf8),
      surfaceContainer: const Color(0xfff4f4f1),
      surfaceContainerHigh: const Color(0xffeeeeea),
      surfaceContainerHighest: const Color(0xffe7e7e2),
      onSurfaceVariant: const Color(0xff6a6b65),
      outline: const Color(0xffc8c9c2),
      outlineVariant: const Color(0xffdedfd8),
    );

final _showcaseTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _showcaseColors,
  scaffoldBackgroundColor: _showcaseColors.surface,
  textTheme:
      const TextTheme(
        displaySmall: TextStyle(
          fontSize: 42,
          height: 1.05,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35),
        bodySmall: TextStyle(fontSize: 12, height: 1.35),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ).apply(
        bodyColor: _showcaseColors.onSurface,
        displayColor: _showcaseColors.onSurface,
      ),
  dividerTheme: DividerThemeData(
    color: _showcaseColors.outlineVariant,
    thickness: 1,
    space: 1,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(Size(180, 52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: _showcaseColors.primary,
    circularTrackColor: _showcaseColors.surfaceContainerHighest,
  ),
);

class PixerShowcase extends StatelessWidget {
  const PixerShowcase({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pixer showcase',
    debugShowCheckedModeBanner: false,
    theme: _showcaseTheme,
    home: const _ShowcasePage(),
  );
}

enum _Engine { image, pixer }

final class _ProcessedImage {
  const _ProcessedImage(this.bytes, this.elapsed);

  final Uint8List bytes;
  final Duration elapsed;
}

Future<_ProcessedImage> _upscaleWithImage(Uint8List bytes) async {
  final stopwatch = Stopwatch()..start();
  final source = image.decodeImage(bytes);
  if (source == null) throw StateError('Could not decode the source image');
  final result = image.copyResize(
    source,
    width: _targetWidth,
    height: _targetHeight,
    interpolation: image.Interpolation.cubic,
  );
  final encoded = Uint8List.fromList(image.encodeJpg(result));
  stopwatch.stop();
  return _ProcessedImage(encoded, stopwatch.elapsed);
}

Future<_ProcessedImage> _upscaleWithPixer(Uint8List bytes) async {
  await Pixer.initialize();
  final stopwatch = Stopwatch()..start();
  final source = Pixer.fromMemory(bytes);
  Pixer? result;
  try {
    result = source.resizeExact(
      _targetWidth,
      _targetHeight,
      filter: FilterTypeEnum.Lanczos3,
    );
    final encoded = result.encode(PixerJpegEncoder(quality: 100));
    stopwatch.stop();
    return _ProcessedImage(encoded, stopwatch.elapsed);
  } finally {
    result?.dispose();
    source.dispose();
  }
}

class _ShowcasePage extends StatefulWidget {
  const _ShowcasePage();

  @override
  State<_ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<_ShowcasePage> {
  Uint8List? _source;
  final _results = <_Engine, _ProcessedImage>{};
  final _running = <_Engine>{};
  final _errors = <_Engine, String>{};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load('assets/example_img.jpg');
      if (!mounted) return;
      setState(() => _source = data.buffer.asUint8List());
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  Future<void> _run(_Engine engine, Uint8List source) async {
    try {
      final result = await compute(
        engine == _Engine.image ? _upscaleWithImage : _upscaleWithPixer,
        source,
      );
      if (mounted) setState(() => _results[engine] = result);
    } catch (error) {
      if (mounted) setState(() => _errors[engine] = error.toString());
    } finally {
      if (mounted) setState(() => _running.remove(engine));
    }
  }

  Future<void> _upscale() async {
    final source = _source;
    if (source == null || _running.isNotEmpty) return;
    setState(() {
      _running.addAll(_Engine.values);
      _errors.clear();
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Future.wait([
      for (final engine in _Engine.values) _run(engine, source),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upscale to 4K', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = [
                        for (final engine in _Engine.values)
                          _ImageCard(
                            title: engine == _Engine.image ? 'Image' : 'Pixer',
                            source: _source,
                            result: _results[engine],
                            loading: _running.contains(engine),
                            error: _errors[engine],
                          ),
                      ];
                      if (constraints.maxWidth < 760) {
                        return Column(
                          children: [
                            cards.first,
                            const SizedBox(height: 28),
                            cards.last,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards.first),
                          const SizedBox(width: 24),
                          Expanded(child: cards.last),
                        ],
                      );
                    },
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _loadError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _source == null || _running.isNotEmpty
                        ? null
                        : _upscale,
                    child: Text(
                      _results.isEmpty ? 'Upscale images' : 'Upscale again',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.title,
    required this.source,
    required this.result,
    required this.loading,
    required this.error,
  });

  final String title;
  final Uint8List? source;
  final _ProcessedImage? result;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bytes = result?.bytes ?? source;
    final complete = !loading && error == null && result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: AspectRatio(
            aspectRatio: _targetWidth / _targetHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bytes != null)
                  Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: '$title upscale',
                  ),
                if (loading)
                  ColoredBox(
                    color: colors.surface.withValues(alpha: 0.65),
                    child: Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Upscaling with $title',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previousChildren, ?currentChild],
          ),
          child: complete
              ? Text(
                  _formatDuration(result!.elapsed),
                  key: ValueKey(result),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              : const SizedBox(height: 24),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'FILE SIZE',
                value: complete ? _formatBytes(result!.bytes.length) : '—',
              ),
            ),
            const Expanded(
              child: _Metric(
                label: 'DIMENSIONS',
                value: '$_targetWidth × $_targetHeight',
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: colors.error)),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
