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

  test('saves the final image to a file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pixer_batch_test_',
    );
    final output = File('${directory.path}/output.png');
    final image = Pixer.fromMemory(
      img.encodePng(img.Image(width: 1, height: 1, numChannels: 4)),
    );
    try {
      image.batch().resizeExact(3, 2).invert().saveToFile(output.path);

      final saved = Pixer.fromFile(output.path);
      expect((saved.width, saved.height), (3, 2));
      saved.dispose();
    } finally {
      image.dispose();
      await directory.delete(recursive: true);
    }
  });
}
