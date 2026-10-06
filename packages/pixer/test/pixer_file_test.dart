@TestOn('vm')
library;

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:pixer/pixer.dart';
import 'package:test/test.dart';

void main() {
  test('loads image from file throws IoException for missing files', () {
    // For missing files, we now get specific IoException instead of generic LoadException
    expect(
      () => Pixer.fromFile('nonexistent.jpg'),
      throwsA(isA<IoException>()),
    );
  });

  test('probes a file without loading it', () async {
    final directory = await Directory.systemTemp.createTemp('pixer_probe_');
    final rotated = img.Image(width: 4, height: 2)
      ..exif.imageIfd.orientation = 6;
    final file = File('${directory.path}/rotated.jpg')
      ..writeAsBytesSync(img.encodeJpg(rotated));
    try {
      expect(
        Pixer.probeFile(file.path),
        const PixerMetadata(
          width: 2,
          height: 4,
          colorType: ColorType.rgb,
          format: ImageFormatEnum.Jpeg,
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
    expect(() => Pixer.probeFile(''), throwsA(isA<InvalidPathException>()));
    expect(
      () => Pixer.probeFile('nonexistent.jpg'),
      throwsA(isA<IoException>()),
    );
  });

  test('saves the final image to a file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pixer_pipeline_test_',
    );
    final output = File('${directory.path}/output.png');
    final image = Pixer.fromMemory(
      img.encodePng(img.Image(width: 1, height: 1, numChannels: 4)),
    );
    try {
      image.resizeExact(3, 2).invert().saveToFile(output.path);

      final saved = Pixer.fromFile(output.path);
      expect((saved.width, saved.height), (3, 2));
      saved.dispose();
    } finally {
      image.dispose();
      await directory.delete(recursive: true);
    }
  });
}
