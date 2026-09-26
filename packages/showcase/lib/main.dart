import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixer/pixer.dart';

void main() => runApp(const PixerShowcase());

class PixerShowcase extends StatelessWidget {
  const PixerShowcase({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pixer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff51616f)),
      scaffoldBackgroundColor: const Color(0xfff4f5f6),
      useMaterial3: true,
    ),
    home: const _ShowcasePage(),
  );
}

typedef _Transform = Pixer Function(Pixer image);

final _operations = <_Operation>[
  _Operation(
    'Resize',
    'Fit within 480 × 320',
    (image) => image.resize(480, 320),
  ),
  _Operation(
    'Resize exact',
    'Force 400 × 400',
    (image) => image.resizeExact(400, 400),
  ),
  _Operation(
    'Crop',
    'Centered half',
    (image) => image.crop(
      image.width ~/ 4,
      image.height ~/ 4,
      image.width ~/ 2,
      image.height ~/ 2,
    ),
  ),
  _Operation('Rotate 90°', 'Clockwise', (image) => image.rotate90()),
  _Operation('Rotate 180°', 'Upside down', (image) => image.rotate180()),
  _Operation('Rotate 270°', 'Counter-clockwise', (image) => image.rotate270()),
  _Operation(
    'Flip horizontal',
    'Mirror left to right',
    (image) => image.flipHorizontal(),
  ),
  _Operation(
    'Flip vertical',
    'Mirror top to bottom',
    (image) => image.flipVertical(),
  ),
  _Operation('Blur', 'Sigma 8', (image) => image.blur(8)),
  _Operation('Brightness', '+45', (image) => image.brightness(45)),
  _Operation('Contrast', '+35', (image) => image.contrast(35)),
  _Operation('Grayscale', 'Remove color', (image) => image.grayscale()),
  _Operation('Invert', 'Invert every color', (image) => image.invert()),
  _Operation(
    'Batch',
    'Resize + grayscale',
    (image) => image.batch().resize(480, 320).grayscale().toImage(),
  ),
];

final class _Operation {
  const _Operation(this.name, this.description, this.transform);

  final String name;
  final String description;
  final _Transform transform;
}

final class _ProcessedImages {
  const _ProcessedImages({
    required this.original,
    required this.result,
    required this.originalSize,
    required this.resultSize,
  });

  final Uint8List original;
  final Uint8List result;
  final String originalSize;
  final String resultSize;
}

class _ShowcasePage extends StatefulWidget {
  const _ShowcasePage();

  @override
  State<_ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<_ShowcasePage> {
  var _selected = 0;
  late Future<_ProcessedImages> _images = _process(_operations.first);

  Future<_ProcessedImages> _process(_Operation operation) async {
    await Pixer.initialize();
    final original = (await rootBundle.load(
      'assets/example_img.jpg',
    )).buffer.asUint8List();
    final source = Pixer.fromMemory(original);
    Pixer? result;
    try {
      result = operation.transform(source);
      return _ProcessedImages(
        original: original,
        result: result.encode(const PixerPngEncoder()),
        originalSize: '${source.width} × ${source.height}',
        resultSize: '${result.width} × ${result.height}',
      );
    } finally {
      result?.dispose();
      source.dispose();
    }
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _images = _process(_operations[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final operation = _operations[_selected];
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pixer',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fast image processing with Dart and Rust.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0; index < _operations.length; index++)
                        ChoiceChip(
                          label: Text(_operations[index].name),
                          selected: index == _selected,
                          onSelected: (_) => _select(index),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${operation.name} · ${operation.description}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<_ProcessedImages>(
                    future: _images,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorCard(
                          message: snapshot.error.toString(),
                          retry: () => _select(_selected),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 360,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final images = snapshot.requireData;
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            _ImageCard(
                              title: 'Original',
                              size: images.originalSize,
                              bytes: images.original,
                            ),
                            _ImageCard(
                              title: 'Result',
                              size: images.resultSize,
                              bytes: images.result,
                            ),
                          ];
                          if (constraints.maxWidth < 700) {
                            return Column(spacing: 16, children: cards);
                          }
                          return Row(
                            spacing: 16,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final card in cards) Expanded(child: card),
                            ],
                          );
                        },
                      );
                    },
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
    required this.size,
    required this.bytes,
  });

  final String title;
  final String size;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(
            color: const Color(0xffe7e9eb),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              semanticLabel: '$title image',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(size, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not process the image',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(message),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
