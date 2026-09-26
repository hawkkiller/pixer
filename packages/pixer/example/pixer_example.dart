import 'dart:io';

import 'package:pixer/pixer.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run example/pixer_example.dart <input> <output>',
    );
    exitCode = 64;
    return;
  }

  final image = Pixer.fromFile(args[0]);
  Pixer? thumbnail;
  try {
    thumbnail = image.resize(800, 600);
    thumbnail.saveToFile(args[1]);

    final metadata = thumbnail.getMetadata();
    stdout.writeln(
      'Wrote ${metadata.width}x${metadata.height} image to ${args[1]}',
    );
  } finally {
    thumbnail?.dispose();
    image.dispose();
  }
}
